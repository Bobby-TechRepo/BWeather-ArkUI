import { hilog } from '@kit.PerformanceAnalysisKit';
import { Debouncer, Storage } from '../common/Storage';
import { TempUnit, Units, UnitConverter } from '../common/Units';
import { WallTime } from '../common/WallTime';
import { ForecastRepository } from '../data/WeatherClient';
import { CityUtil } from '../model/ForecastUtil';
import { Daily } from '../model/Models';
import { PackingItem, PlaceNormals, StopForecast, Trip, TripDay, TripStop, TripTiming, TripUtil } from '../model/Trips';
import { SettingsState, States } from './StateTypes';

export interface TripsState {
  /** Soonest first. */
  trips: Trip[];
  forecasts: StopForecast[];
  /** Shared between stops in the same place. */
  normals: PlaceNormals[];
}

interface SavedTrips {
  trips?: Trip[];
  forecasts?: StopForecast[];
  normals?: PlaceNormals[];
}

/** Saved trips and the weather for their stops (lib/states/trips/trips_cubit.dart). */
@ObservedV2
export class TripsStore {
  static readonly FILE: string = 'trips';

  @Trace state: TripsState = TripsStore.empty();
  /** Stop ids with a request running (not saved). */
  @Trace loading: string[] = [];
  /** Stop ids whose last forecast request failed (not saved). */
  @Trace failed: string[] = [];

  private readonly repository: ForecastRepository = new ForecastRepository();
  private readonly saver: Debouncer = new Debouncer(400);
  private units: Units = UnitConverter.METRIC;
  private idCounter: number = 0;

  static empty(): TripsState {
    const state: TripsState = { trips: [], forecasts: [], normals: [] };
    return state;
  }

  load(settings: SettingsState): void {
    this.units = States.units(settings);
    const text = Storage.read(TripsStore.FILE);
    if (text !== undefined) {
      try {
        const saved = JSON.parse(text) as SavedTrips;
        const trips = (saved.trips ?? []).filter((trip: Trip) =>
          typeof trip.id === 'string' && Array.isArray(trip.stops) && trip.stops.length > 0 &&
          trip.stops.every((stop: TripStop) => typeof stop.arrive === 'number' && stop.city !== undefined));
        const state: TripsState = {
          trips: trips.map((trip: Trip) => TripsStore.restoreTrip(trip)),
          forecasts: (saved.forecasts ?? []).filter((entry: StopForecast) => Array.isArray(entry.days)),
          normals: (saved.normals ?? []).filter((entry: PlaceNormals) => entry.normals !== undefined &&
            Array.isArray(entry.normals.highs))
        };
        this.state = state;
      } catch (error) {
        hilog.warn(0x0000, 'Trips', 'Saved trips unreadable');
      }
    }
    this.cleanUp();
    this.convertAll();
  }

  private static restoreTrip(trip: Trip): Trip {
    const restored: Trip = {
      id: trip.id,
      name: typeof trip.name === 'string' ? trip.name : '',
      stops: trip.stops,
      packed: Array.isArray(trip.packed) ? trip.packed : [],
      remind: trip.remind === true
    };
    return restored;
  }

  /** Unit changes are applied to the cached forecasts on the device. */
  onSettingsChanged(settings: SettingsState): void {
    const units = States.units(settings);
    if (!UnitConverter.same(units, this.units)) {
      this.units = units;
      this.convertAll();
    }
  }

  private convertAll(): void {
    const converted = this.state.forecasts.map((entry: StopForecast) => TripUtil.convert(entry, this.units));
    if (converted.some((entry: StopForecast, index: number) => entry !== this.state.forecasts[index])) {
      this.emit(this.state.trips, converted, this.state.normals);
    }
  }

  trip(id: string): Trip | undefined {
    return this.state.trips.find((trip: Trip) => trip.id === id);
  }

  /** A new unique id for a trip or stop. */
  newId(): string {
    this.idCounter++;
    return `${Date.now().toString(36)}${this.idCounter.toString(36)}`;
  }

  // ---------------------------------------------------------------- editing

  /** Adds or replaces [trip]. */
  save(trip: Trip): void {
    const trips = this.state.trips.filter((existing: Trip) => existing.id !== trip.id).concat([trip]);
    trips.sort((a: Trip, b: Trip) => TripUtil.start(a) - TripUtil.start(b));
    this.emit(trips, this.state.forecasts, this.state.normals);
    this.cleanUp();
    this.refresh(trip.id, false);
  }

  delete(id: string): void {
    this.emit(this.state.trips.filter((trip: Trip) => trip.id !== id), this.state.forecasts, this.state.normals);
    this.cleanUp();
  }

  /** Puts back a trip deleted by mistake. */
  restore(trip: Trip): void {
    if (this.trip(trip.id) === undefined) {
      this.save(trip);
    }
  }

  togglePacked(tripId: string, item: PackingItem): void {
    const trip = this.trip(tripId);
    if (trip === undefined) {
      return;
    }
    const packed = trip.packed.includes(item) ? trip.packed.filter((name: string) => name !== item) :
      trip.packed.concat([item]);
    this.replace(TripsStore.copy(trip, trip.name, trip.stops, packed, trip.remind));
  }

  setReminder(tripId: string, remind: boolean): void {
    const trip = this.trip(tripId);
    if (trip !== undefined) {
      this.replace(TripsStore.copy(trip, trip.name, trip.stops, trip.packed, remind));
    }
  }

  static copy(trip: Trip, name: string, stops: TripStop[], packed: string[], remind: boolean): Trip {
    const copy: Trip = { id: trip.id, name: name, stops: stops, packed: packed, remind: remind };
    return copy;
  }

  private replace(trip: Trip): void {
    this.emit(this.state.trips.map((existing: Trip) => existing.id === trip.id ? trip : existing),
      this.state.forecasts, this.state.normals);
  }

  /** Forgets weather for stops and places no trip uses any more. */
  private cleanUp(): void {
    const stopIds = new Set<string>();
    const cityIds = new Set<string>();
    for (const trip of this.state.trips) {
      for (const stop of trip.stops) {
        stopIds.add(stop.id);
        cityIds.add(CityUtil.id(stop.city));
      }
    }
    const forecasts = this.state.forecasts.filter((entry: StopForecast) => stopIds.has(entry.stopId));
    const normals = this.state.normals.filter((entry: PlaceNormals) => cityIds.has(entry.cityId));
    if (forecasts.length !== this.state.forecasts.length || normals.length !== this.state.normals.length) {
      this.emit(this.state.trips, forecasts, normals);
    }
  }

  // ---------------------------------------------------------------- weather

  /** Day-by-day weather for a trip in the current temperature unit. */
  days(trip: Trip): TripDay[] {
    return TripUtil.tripDays(trip, this.state.forecasts, this.state.normals, this.units.temp === TempUnit.Fahrenheit);
  }

  /** Fetches what's missing or stale for the trip's stops. Past trips are left alone. */
  async refresh(tripId: string, force: boolean): Promise<void> {
    const trip = this.trip(tripId);
    if (trip === undefined || TripUtil.timing(trip) === TripTiming.Past) {
      return;
    }
    await Promise.all(trip.stops.map((stop: TripStop) => this.refreshStop(stop, force)));
  }

  /** Refreshes every trip that hasn't ended (e.g. when the Trips tab opens). */
  async refreshAll(force: boolean = false): Promise<void> {
    await Promise.all(this.state.trips.map((trip: Trip) => this.refresh(trip.id, force)));
  }

  private async refreshStop(stop: TripStop, force: boolean): Promise<void> {
    if (this.loading.includes(stop.id)) {
      return;
    }
    const cached = this.state.forecasts.find((entry: StopForecast) => entry.stopId === stop.id);
    const range = TripUtil.forecastWindow(stop.arrive, stop.depart);
    const inWindow = range.length === 2;
    const needsForecast = inWindow && (force || cached === undefined ||
      Date.now() - cached.fetchedAt > TripUtil.FORECAST_MAX_AGE_MS);
    const cityId = CityUtil.id(stop.city);
    // Normals are only needed for days beyond the forecast.
    const needsNormals = TripUtil.beyondForecast(stop) &&
      this.state.normals.find((entry: PlaceNormals) => entry.cityId === cityId) === undefined;
    if (!needsForecast && !needsNormals) {
      return;
    }

    this.loading = this.loading.concat([stop.id]);
    this.failed = this.failed.filter((id: string) => id !== stop.id);
    let failed = false;
    if (needsForecast) {
      try {
        const days: Daily[] = await this.repository.dailyForecast(stop.city, WallTime.isoDate(range[0]), WallTime.isoDate(range[1]));
        const fetched: StopForecast = {
          stopId: stop.id,
          days: days,
          fetchedAt: Date.now(),
          units: TripUtil.unitsKey(UnitConverter.METRIC)
        };
        const forecast = TripUtil.convert(fetched, this.units);
        const forecasts = this.state.forecasts.filter((entry: StopForecast) => entry.stopId !== stop.id).concat([forecast]);
        this.emit(this.state.trips, forecasts, this.state.normals);
      } catch (error) {
        hilog.info(0x0000, 'Trips', 'Trip forecast failed');
        failed = true;
      }
    }
    if (needsNormals) {
      try {
        const normals = await this.repository.climateNormals(stop.city.latitude, stop.city.longitude);
        const entry: PlaceNormals = { cityId: cityId, normals: normals };
        this.emit(this.state.trips, this.state.forecasts,
          this.state.normals.filter((existing: PlaceNormals) => existing.cityId !== cityId).concat([entry]));
      } catch (error) {
        hilog.info(0x0000, 'Trips', 'Trip normals failed');
        failed = failed || !inWindow;
      }
    }
    this.loading = this.loading.filter((id: string) => id !== stop.id);
    if (failed) {
      this.failed = this.failed.concat([stop.id]);
    }
  }

  // ---------------------------------------------------------------- persistence

  private emit(trips: Trip[], forecasts: StopForecast[], normals: PlaceNormals[]): void {
    const state: TripsState = { trips: trips, forecasts: forecasts, normals: normals };
    this.state = state;
    this.saver.run(() => {
      Storage.write(TripsStore.FILE, JSON.stringify(this.state));
    });
  }
}
