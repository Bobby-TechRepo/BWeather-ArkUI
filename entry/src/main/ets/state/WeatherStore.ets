import { hilog } from '@kit.PerformanceAnalysisKit';
import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Debouncer, Storage } from '../common/Storage';
import { Units, UnitConverter } from '../common/Units';
import { FailureKind, RequestFailure } from '../data/Http';
import { Coordinates, LocationError, LocationFailure, LocationService } from '../data/LocationService';
import { ForecastRepository } from '../data/WeatherClient';
import { CityUtil } from '../model/ForecastUtil';
import { City, ClimateNormals, Forecast } from '../model/Models';
import {
  CityState, CURRENT_LOCATION_KEY, ForecastIssue, LocationIssue, SettingsState, States, Status, WeatherState
} from './StateTypes';

/** What may be in the saved file. Each place is checked before use. */
interface SavedWeather {
  version?: number;
  onboarded?: boolean;
  location?: CityState;
  cities?: CityState[];
}

/** The persisted shape (no in-flight status). */
interface SavedWeatherOut {
  version: number;
  onboarded: boolean;
  location?: CityState;
  cities: CityState[];
}

type PlaceChange = (current: CityState) => CityState;

/**
 * Owns the user's location, their saved cities and every forecast
 * (lib/states/weather_cubit.dart). Places are always addressed by key, never
 * by list position, so adding/removing cities while requests run is safe.
 */
@ObservedV2
export class WeatherStore {
  static readonly FILE: string = 'weather';
  static readonly SCHEMA_VERSION: number = 1;
  /** Forecasts older than this are refreshed on launch, resume and reconnect. */
  static readonly STALE_AFTER_MS: number = 15 * 60 * 1000;
  /** GPS moves smaller than this keep the current place and its name. */
  static readonly SAME_LOCATION_KM: number = 3;

  @Trace state: WeatherState = States.emptyWeather();

  private readonly repository: ForecastRepository = new ForecastRepository();
  private readonly locationService: LocationService = new LocationService();
  private readonly saver: Debouncer = new Debouncer(400);
  private units: Units = UnitConverter.METRIC;
  private minuteRain: boolean = false;
  /** Keys with a forecast request running (prevents duplicate requests). */
  private readonly inFlight: Set<string> = new Set<string>();
  private readonly normalsInFlight: Set<string> = new Set<string>();

  // ---------------------------------------------------------------- lifecycle

  load(settings: SettingsState): void {
    this.units = States.units(settings);
    this.minuteRain = settings.minuteRain;
    const text = Storage.read(WeatherStore.FILE);
    if (text !== undefined) {
      try {
        this.state = WeatherStore.restore(JSON.parse(text) as SavedWeather);
      } catch (error) {
        hilog.warn(0x0000, 'Weather', 'Saved places unreadable; starting fresh');
      }
    }
    // Saved forecasts are normally in these units already; this is a no-op then.
    this.convertAll();
  }

  /** Called once on launch. */
  async start(): Promise<void> {
    if (!this.state.onboarded) {
      // The welcome screen is showing: look up an approximate location in the
      // background so the user can just tap "Continue".
      await this.useApproximateLocation();
      return;
    }
    // Don't pop a permission dialog on every launch; only update silently.
    await Promise.all([this.refreshAll(false), this.locate(false)]);
  }

  /** The app came back to the foreground. */
  async onResume(): Promise<void> {
    await this.refreshAll(false);
  }

  /** A network became available. */
  onConnected(): void {
    if (!this.state.onboarded) {
      return;
    }
    if (this.state.location === undefined && this.state.status !== Status.Loading) {
      this.locate(false);
    }
    this.refreshAll(false);
  }

  onSettingsChanged(settings: SettingsState, previous: SettingsState): void {
    const units = States.units(settings);
    if (!UnitConverter.same(units, this.units)) {
      // Convert what we have: instant, offline, and no new requests.
      this.units = units;
      this.convertAll();
    }
    if (settings.minuteRain !== previous.minuteRain) {
      this.minuteRain = settings.minuteRain;
      this.refreshAll(true);
    }
  }

  private convertAll(): void {
    const location = this.state.location;
    const converted = location === undefined ? undefined :
      States.copyPlace(location, UnitConverter.city(location.city, this.units), location.status, location.issue);
    const cities = this.state.cities.map((place: CityState) =>
      States.copyPlace(place, UnitConverter.city(place.city, this.units), place.status, place.issue));
    this.emit(States.copyWeather(this.state, converted, cities));
  }

  // ---------------------------------------------------------------- onboarding

  /** "Use my location" on the welcome screen or the location banner. */
  async useMyLocation(): Promise<void> {
    await this.locate(true);
    // Only leave the welcome screen with a precise location; if GPS failed the
    // screen stays up with the error and the other options.
    const location = this.state.location;
    if (location !== undefined && !location.approximate && !this.state.onboarded) {
      this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, undefined, undefined, true));
    }
  }

  /** "Continue with <approximate place>" on the welcome screen. */
  completeOnboarding(): void {
    if (!this.state.onboarded) {
      this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, undefined, undefined, true));
    }
  }

  openLocationSettings(): void {
    LocationService.openSettings();
  }

  // ---------------------------------------------------------------- location

  /**
   * Finds the user via GPS. Falls back to an approximate (IP) location when
   * GPS isn't available and there is no location yet.
   */
  async locate(request: boolean): Promise<void> {
    if (this.state.status === Status.Loading) {
      return;
    }
    this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, Status.Loading, LocationIssue.None));

    try {
      const position: Coordinates = await this.locationService.currentPosition(request);
      const existing = this.state.location;
      if (existing !== undefined && !existing.approximate &&
        CityUtil.distanceKm(existing.city.latitude, existing.city.longitude, position.latitude, position.longitude) <
        WeatherStore.SAME_LOCATION_KM) {
        this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, Status.Success));
        if (existing.status === Status.Failure || States.isStale(existing, WeatherStore.STALE_AFTER_MS)) {
          await this.refreshPlace(existing.key);
        }
        return;
      }

      const city = await this.repository.locate(position.latitude, position.longitude, Format.language(),
        S.get($r('app.string.yourLocation')));
      this.emit(States.copyWeather(this.state, States.newPlace(CURRENT_LOCATION_KEY, city, false), this.state.cities,
        Status.Success));
      await this.refreshPlace(CURRENT_LOCATION_KEY);
    } catch (error) {
      let issue = LocationIssue.Unavailable;
      if (error instanceof LocationError) {
        issue = WeatherStore.locationIssue(error.reason);
      } else {
        hilog.warn(0x0000, 'Weather', 'Location error: %{public}s', JSON.stringify(error));
      }
      this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, Status.Failure, issue));
      if (this.state.location === undefined) {
        await this.useApproximateLocation();
      }
    }
  }

  private async useApproximateLocation(): Promise<void> {
    try {
      const city = await this.repository.approximateLocation();
      // GPS may have succeeded meanwhile; never replace a precise location.
      const location = this.state.location;
      if (location !== undefined && !location.approximate) {
        return;
      }
      this.emit(States.copyWeather(this.state, States.newPlace(CURRENT_LOCATION_KEY, city, true), this.state.cities));
      await this.refreshPlace(CURRENT_LOCATION_KEY);
    } catch (error) {
      hilog.info(0x0000, 'Weather', 'Approximate location unavailable');
    }
  }

  private static locationIssue(reason: LocationFailure): LocationIssue {
    switch (reason) {
      case LocationFailure.ServiceDisabled:
        return LocationIssue.ServiceDisabled;
      case LocationFailure.PermissionDenied:
        return LocationIssue.PermissionDenied;
      case LocationFailure.PermissionBlocked:
        return LocationIssue.PermissionBlocked;
      default:
        return LocationIssue.Unavailable;
    }
  }

  // ---------------------------------------------------------------- cities

  /** Adds [city] (unless it is saved already) and returns its key so the UI can show it. */
  addCity(city: City): string {
    const key = CityUtil.id(city);
    if (States.place(this.state, key) === undefined) {
      const place = States.newPlace(key, city, false);
      this.emit(States.copyWeather(this.state, this.state.location, this.state.cities.concat([place]), undefined, undefined, true));
      this.refreshPlace(key);
    } else if (!this.state.onboarded) {
      this.emit(States.copyWeather(this.state, this.state.location, this.state.cities, undefined, undefined, true));
    }
    return key;
  }

  /** Moves the saved city at [from] to [to] (positions in state.cities). */
  reorderCity(from: number, to: number): void {
    const count = this.state.cities.length;
    if (from < 0 || from >= count) {
      return;
    }
    const target = Math.max(0, Math.min(to, count - 1));
    if (target === from) {
      return;
    }
    const cities = this.state.cities.slice();
    const moved = cities.splice(from, 1);
    cities.splice(target, 0, moved[0]);
    this.emit(States.copyWeather(this.state, this.state.location, cities));
  }

  removeCity(key: string): void {
    if (key === CURRENT_LOCATION_KEY) {
      return;
    }
    this.emit(States.copyWeather(this.state, this.state.location,
      this.state.cities.filter((place: CityState) => place.key !== key)));
  }

  /** Puts back a city removed by mistake ("Undo") at its old position, forecast included. */
  restoreCity(place: CityState, index: number): void {
    if (States.isCurrentLocation(place) || States.place(this.state, place.key) !== undefined) {
      return;
    }
    const cities = this.state.cities.slice();
    cities.splice(Math.max(0, Math.min(index, cities.length)), 0, place);
    this.emit(States.copyWeather(this.state, this.state.location, cities));
    if (States.isStale(place, WeatherStore.STALE_AFTER_MS)) {
      this.refreshPlace(place.key);
    }
  }

  // ---------------------------------------------------------------- forecasts

  /** Refreshes places that failed, have no forecast or are stale (or all of them when [force]). */
  async refreshAll(force: boolean): Promise<void> {
    const work: Promise<void>[] = [];
    for (const place of States.places(this.state)) {
      if (force || place.status === Status.Failure || place.city.forecast === undefined ||
        States.isStale(place, WeatherStore.STALE_AFTER_MS)) {
        work.push(this.refreshPlace(place.key));
      }
    }
    await Promise.all(work);
  }

  /** Fetches a fresh forecast for the place with [key]. */
  async refreshPlace(key: string): Promise<void> {
    const place = States.place(this.state, key);
    if (place === undefined || this.inFlight.has(key)) {
      return;
    }
    this.inFlight.add(key);
    const requestedId = CityUtil.id(place.city);
    const minuteRain = this.minuteRain;
    try {
      this.update(key, requestedId, (current: CityState) => States.copyPlace(current, undefined, Status.Loading));
      // Always fetched in metric and converted on arrival, so a unit change
      // while the request runs is picked up too.
      const fetched = await this.repository.getWeather(place.city, UnitConverter.METRIC, minuteRain);
      const city = UnitConverter.city(fetched, this.units);
      this.update(key, requestedId,
        (current: CityState) => States.copyPlace(current, city, Status.Success, undefined, Date.now()));
      if (place.normals === undefined) {
        this.loadNormals(key, requestedId, place.city);
      }
    } catch (error) {
      const issue = WeatherStore.forecastIssue(error);
      this.update(key, requestedId, (current: CityState) => States.copyPlace(current, undefined, Status.Failure, issue));
    } finally {
      this.inFlight.delete(key);
    }

    // Minute-by-minute rain was toggled while this request ran: fetch again.
    if (minuteRain !== this.minuteRain) {
      await this.refreshPlace(key);
    }
  }

  /** Climate normals are optional: on failure the comparison is hidden and retried next time. */
  private async loadNormals(key: string, cityId: string, city: City): Promise<void> {
    if (this.normalsInFlight.has(key)) {
      return;
    }
    this.normalsInFlight.add(key);
    try {
      const normals: ClimateNormals = await this.repository.climateNormals(city.latitude, city.longitude);
      this.update(key, cityId,
        (current: CityState) => States.copyPlace(current, undefined, undefined, current.issue, undefined, normals));
    } catch (error) {
      hilog.info(0x0000, 'Weather', 'Climate normals unavailable');
    } finally {
      this.normalsInFlight.delete(key);
    }
  }

  private static forecastIssue(error: Object): ForecastIssue {
    if (error instanceof RequestFailure) {
      return error.kind === FailureKind.Network ? ForecastIssue.Network : ForecastIssue.Data;
    }
    return ForecastIssue.Unknown;
  }

  /** Applies [change] to the place with [key], but only if it is still the place ([cityId]) asked for. */
  private update(key: string, cityId: string, change: PlaceChange): void {
    const location = this.state.location;
    if (location !== undefined && location.key === key) {
      if (CityUtil.id(location.city) === cityId) {
        this.emit(States.copyWeather(this.state, change(location), this.state.cities));
      }
      return;
    }
    const index = this.state.cities.findIndex((place: CityState) => place.key === key);
    if (index === -1 || CityUtil.id(this.state.cities[index].city) !== cityId) {
      return;
    }
    const cities = this.state.cities.slice();
    cities[index] = change(cities[index]);
    this.emit(States.copyWeather(this.state, this.state.location, cities));
  }

  // ---------------------------------------------------------------- persistence

  /** Called after each (debounced) save; AppModel redraws the home-screen card. */
  onSaved: (() => void) | undefined = undefined;

  private emit(next: WeatherState): void {
    this.state = next;
    this.saver.run(() => this.save());
  }

  private save(): void {
    const out: SavedWeatherOut = {
      version: WeatherStore.SCHEMA_VERSION,
      onboarded: this.state.onboarded,
      location: this.state.location,
      cities: this.state.cities
    };
    Storage.write(WeatherStore.FILE, JSON.stringify(out));
    this.onSaved?.();
  }

  /** Reads saved places one by one, so one bad entry doesn't lose the rest. */
  private static restore(saved: SavedWeather): WeatherState {
    const location = saved.location === undefined ? undefined : WeatherStore.restorePlace(saved.location, CURRENT_LOCATION_KEY);
    const cities: CityState[] = [];
    for (const entry of saved.cities ?? []) {
      const place = WeatherStore.restorePlace(entry, '');
      if (place !== undefined && place.key.length > 0 && cities.every((existing: CityState) => existing.key !== place.key)) {
        cities.push(place);
      }
    }
    const state: WeatherState = {
      location: location,
      cities: cities,
      status: Status.Initial,
      locationIssue: LocationIssue.None,
      onboarded: saved.onboarded ?? (location !== undefined || cities.length > 0)
    };
    return state;
  }

  private static restorePlace(place: CityState, fallbackKey: string): CityState | undefined {
    const city = place.city;
    if (city === undefined || typeof city.name !== 'string' || typeof city.latitude !== 'number' ||
      typeof city.longitude !== 'number') {
      return undefined;
    }
    const restored: City = {
      name: city.name,
      country: typeof city.country === 'string' ? city.country : '',
      region: city.region,
      timezone: typeof city.timezone === 'string' ? city.timezone : 'auto',
      elevation: city.elevation,
      latitude: city.latitude,
      longitude: city.longitude,
      // A forecast saved by another version may not be readable: drop just the forecast.
      forecast: WeatherStore.validForecast(city.forecast) ? city.forecast : undefined
    };
    const normals = place.normals !== undefined && Array.isArray(place.normals.highs) && place.normals.highs.length === 366 ?
      place.normals : undefined;
    const result: CityState = {
      key: typeof place.key === 'string' && place.key.length > 0 ? place.key : (fallbackKey.length > 0 ? fallbackKey : CityUtil.id(restored)),
      city: restored,
      // A request can't still be running after a restart.
      status: place.status === Status.Success || place.status === Status.Failure ? place.status : Status.Initial,
      issue: ForecastIssue.None,
      updatedAt: typeof place.updatedAt === 'number' ? place.updatedAt : undefined,
      approximate: place.approximate === true,
      normals: normals
    };
    return result;
  }

  private static validForecast(forecast: Forecast | undefined): boolean {
    return forecast !== undefined && forecast.current !== undefined && forecast.current.temperature !== undefined &&
      Array.isArray(forecast.hourly) && Array.isArray(forecast.daily) && Array.isArray(forecast.minutely);
  }
}
