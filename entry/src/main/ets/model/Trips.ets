import { Units, UnitConverter } from '../common/Units';
import { WallTime } from '../common/WallTime';
import { CityUtil, NormalsUtil } from './ForecastUtil';
import { City, ClimateNormals, Daily } from './Models';

/**
 * Trips (lib/states/trips/*.dart). All dates are calendar dates stored as
 * wall-time midnights (Date.UTC(year, month, day)), like forecast days.
 */

/** One place on a trip, from the day you arrive to the day you leave (both inclusive). */
export interface TripStop {
  id: string;
  /** The place only, never with a cached forecast. */
  city: City;
  arrive: number;
  depart: number;
}

export interface Trip {
  id: string;
  name: string;
  /** In date order. */
  stops: TripStop[];
  /** Packing items the user ticked (PackingItem values). */
  packed: string[];
  /** Send a notification the evening before departure. */
  remind: boolean;
}

export enum TripTiming {
  Upcoming = 'upcoming',
  Ongoing = 'ongoing',
  Past = 'past'
}

/** Why a set of stops can't be saved as a trip. */
export enum TripProblem {
  None = 'none',
  NoStops = 'noStops',
  StopEndsBeforeItStarts = 'stopEndsBeforeItStarts',
  StopsOverlap = 'stopsOverlap',
  TooLong = 'tooLong'
}

/** Forecast days fetched for one stop, and the units they are in. */
export interface StopForecast {
  stopId: string;
  days: Daily[];
  /** Device clock, ms. */
  fetchedAt: number;
  /** TripUtil.unitsKey() of the units [days] are in. */
  units: string;
}

/** Climate normals for a place (shared by stops in the same city). */
export interface PlaceNormals {
  cityId: string;
  normals: ClimateNormals;
}

export enum DayKind {
  /** A real forecast (within about 16 days). */
  Forecast = 'forecast',
  /** Too far ahead: the average for the date over recent years. */
  Typical = 'typical',
  /** Nothing yet (loading, offline, or no data for that place). */
  Unknown = 'unknown'
}

export interface TripDay {
  date: number;
  stop: TripStop;
  /** Set on travel days: the stop you leave that morning. */
  leaving?: TripStop;
  kind: DayKind;
  /** For Forecast days. */
  daily?: Daily;
  /** For Typical days, in the user's unit ([unit] is "°C" or "°F"). */
  high?: number;
  low?: number;
  unit?: string;
}

/** A short overview of a trip's weather for cards and sharing. */
export interface TripOutlook {
  /** Lowest low and highest high, in the user's unit; undefined when nothing is known. */
  low?: number;
  high?: number;
  unit: string;
  /** The weather code seen most often in the forecast days. */
  commonCode?: number;
  /** Days with rain likely (≥ 40% or ≥ 1 mm). */
  rainyDays: number;
  forecastDays: number;
  typicalDays: number;
}

/** Things worth packing for the weather on a trip. */
export enum PackingItem {
  Umbrella = 'umbrella',
  RainJacket = 'rainJacket',
  Sunscreen = 'sunscreen',
  Sunglasses = 'sunglasses',
  Hat = 'hat',
  LightClothes = 'lightClothes',
  WaterBottle = 'waterBottle',
  WarmLayer = 'warmLayer',
  Coat = 'coat',
  Gloves = 'gloves',
  Windbreaker = 'windbreaker',
  InsectRepellent = 'insectRepellent'
}

export class TripUtil {
  /** Longest trip the planner accepts, to keep requests and lists sane. */
  static readonly MAX_DAYS: number = 90;
  /** How many days ahead the forecast reaches (today included). */
  static readonly FORECAST_DAYS: number = 16;
  /** Days before today that a trip still asks the forecast API for. */
  static readonly PAST_DAYS: number = 7;
  /** Trip forecasts change slowly; refresh at most every few hours. */
  static readonly FORECAST_MAX_AGE_MS: number = 3 * 60 * 60 * 1000;

  static unitsKey(units: Units): string {
    return `${units.temp}|${units.wind}|${units.precipitation}`;
  }

  /** A stop keeps the place only, not a cached forecast. */
  static placeOnly(city: City): City {
    const place: City = {
      name: city.name,
      country: city.country,
      region: city.region,
      timezone: city.timezone,
      elevation: city.elevation,
      latitude: city.latitude,
      longitude: city.longitude
    };
    return place;
  }

  static newStop(id: string, city: City, arrive: number, depart: number): TripStop {
    const stop: TripStop = {
      id: id,
      city: TripUtil.placeOnly(city),
      arrive: WallTime.startOfDay(arrive),
      depart: WallTime.startOfDay(depart)
    };
    return stop;
  }

  static nights(stop: TripStop): number {
    return Math.round((stop.depart - stop.arrive) / WallTime.DAY);
  }

  static contains(stop: TripStop, day: number): boolean {
    const date = WallTime.startOfDay(day);
    return date >= stop.arrive && date <= stop.depart;
  }

  static start(trip: Trip): number {
    return trip.stops.length === 0 ? 0 : trip.stops[0].arrive;
  }

  static end(trip: Trip): number {
    return trip.stops.length === 0 ? 0 : trip.stops[trip.stops.length - 1].depart;
  }

  static dayCount(trip: Trip): number {
    return Math.round((TripUtil.end(trip) - TripUtil.start(trip)) / WallTime.DAY) + 1;
  }

  static timing(trip: Trip, today?: number): TripTiming {
    const date = today ?? WallTime.deviceToday();
    if (date < TripUtil.start(trip)) {
      return TripTiming.Upcoming;
    }
    return date > TripUtil.end(trip) ? TripTiming.Past : TripTiming.Ongoing;
  }

  /** Days until the trip starts (0 on the first day, negative once it has started). */
  static daysUntil(trip: Trip, today?: number): number {
    return Math.round((TripUtil.start(trip) - (today ?? WallTime.deviceToday())) / WallTime.DAY);
  }

  /** Every date of the trip, in order. */
  static dates(trip: Trip): number[] {
    const dates: number[] = [];
    const start = TripUtil.start(trip);
    for (let i = 0; i < TripUtil.dayCount(trip); i++) {
      dates.push(start + i * WallTime.DAY);
    }
    return dates;
  }

  /** Where you are on [day]. On a travel day this is the stop you arrive at. */
  static stopOn(trip: Trip, day: number): TripStop | undefined {
    let found: TripStop | undefined = undefined;
    for (const stop of trip.stops) {
      if (TripUtil.contains(stop, day)) {
        found = stop;
      }
    }
    return found;
  }

  /** The stop you leave on [day] when it is a travel day. */
  static leavingOn(trip: Trip, day: number): TripStop | undefined {
    const date = WallTime.startOfDay(day);
    const arriving = TripUtil.stopOn(trip, date);
    return trip.stops.find((stop: TripStop) => stop !== arriving && stop.depart === date);
  }

  /** Checks stops are in order and the trip isn't too long. */
  static validate(stops: TripStop[]): TripProblem {
    if (stops.length === 0) {
      return TripProblem.NoStops;
    }
    for (let i = 0; i < stops.length; i++) {
      if (stops[i].depart < stops[i].arrive) {
        return TripProblem.StopEndsBeforeItStarts;
      }
      // You may leave one place and arrive at the next on the same day.
      if (i > 0 && stops[i].arrive < stops[i - 1].depart) {
        return TripProblem.StopsOverlap;
      }
    }
    const days = Math.round((stops[stops.length - 1].depart - stops[0].arrive) / WallTime.DAY) + 1;
    return days > TripUtil.MAX_DAYS ? TripProblem.TooLong : TripProblem.None;
  }

  /** The part of [start]..[end] the forecast API can answer, as [start, end]; empty when none. */
  static forecastWindow(start: number, end: number, today?: number): number[] {
    const now = today ?? WallTime.deviceToday();
    const first = now - TripUtil.PAST_DAYS * WallTime.DAY;
    const last = now + (TripUtil.FORECAST_DAYS - 1) * WallTime.DAY;
    const from = Math.max(WallTime.startOfDay(start), first);
    const to = Math.min(WallTime.startOfDay(end), last);
    return to < from ? [] : [from, to];
  }

  /** Whether part of the stop is beyond the forecast (so climate normals are needed). */
  static beyondForecast(stop: TripStop, today?: number): boolean {
    const now = today ?? WallTime.deviceToday();
    return stop.depart > now + (TripUtil.FORECAST_DAYS - 1) * WallTime.DAY;
  }

  /** The same forecast days in [target] units (no request needed). */
  static convert(forecast: StopForecast, target: Units): StopForecast {
    const key = TripUtil.unitsKey(target);
    if (key === forecast.units) {
      return forecast;
    }
    const converted: StopForecast = {
      stopId: forecast.stopId,
      days: forecast.days.map((day: Daily) => UnitConverter.daily(day, target)),
      fetchedAt: forecast.fetchedAt,
      units: key
    };
    return converted;
  }

  /**
   * Day-by-day weather for [trip]: the forecast where there is one, otherwise
   * typical weather from climate normals (°C, converted to [fahrenheit] if needed).
   */
  static tripDays(trip: Trip, forecasts: StopForecast[], normals: PlaceNormals[], fahrenheit: boolean): TripDay[] {
    const days: TripDay[] = [];
    for (const date of TripUtil.dates(trip)) {
      const stop = TripUtil.stopOn(trip, date);
      if (stop === undefined) {
        continue;
      }
      const leaving = TripUtil.leavingOn(trip, date);
      const forecast = forecasts.find((entry: StopForecast) => entry.stopId === stop.id);
      const daily = forecast?.days.find((day: Daily) => WallTime.sameDay(day.time, date));
      if (daily !== undefined) {
        const day: TripDay = { date: date, stop: stop, leaving: leaving, kind: DayKind.Forecast, daily: daily };
        days.push(day);
        continue;
      }
      const cityId = CityUtil.id(stop.city);
      const place = normals.find((entry: PlaceNormals) => entry.cityId === cityId);
      const high = place === undefined ? undefined : NormalsUtil.highFor(place.normals, date);
      const low = place === undefined ? undefined : NormalsUtil.lowFor(place.normals, date);
      if (high !== undefined && low !== undefined) {
        const day: TripDay = {
          date: date,
          stop: stop,
          leaving: leaving,
          kind: DayKind.Typical,
          high: fahrenheit ? high * 9 / 5 + 32 : high,
          low: fahrenheit ? low * 9 / 5 + 32 : low,
          unit: fahrenheit ? '°F' : '°C'
        };
        days.push(day);
      } else {
        const day: TripDay = { date: date, stop: stop, leaving: leaving, kind: DayKind.Unknown };
        days.push(day);
      }
    }
    return days;
  }

  static isRainy(daily: Daily): boolean {
    const probability = daily.precipitationProbabilityMax?.value ?? 0;
    const sum = daily.precipitationSum;
    const sumMm = sum === undefined ? 0 : UnitConverter.toMm(sum.value, sum.unit);
    return probability >= 40 || sumMm >= 1;
  }

  static outlook(days: TripDay[]): TripOutlook {
    let low: number | undefined = undefined;
    let high: number | undefined = undefined;
    let unit = '';
    const codes = new Map<number, number>();
    let rainy = 0;
    let forecastCount = 0;
    let typicalCount = 0;
    const include = (dayLow: number, dayHigh: number): void => {
      low = low === undefined || dayLow < low ? dayLow : low;
      high = high === undefined || dayHigh > high ? dayHigh : high;
    };

    for (const day of days) {
      const daily = day.daily;
      if (day.kind === DayKind.Forecast && daily !== undefined) {
        forecastCount++;
        unit = daily.temperatureMax.unit;
        include(daily.temperatureMin.value, daily.temperatureMax.value);
        codes.set(daily.weatherCode, (codes.get(daily.weatherCode) ?? 0) + 1);
        if (TripUtil.isRainy(daily)) {
          rainy++;
        }
      } else if (day.kind === DayKind.Typical && day.high !== undefined && day.low !== undefined) {
        typicalCount++;
        unit = unit.length === 0 ? (day.unit ?? '') : unit;
        include(day.low, day.high);
      }
    }

    let common: number | undefined = undefined;
    let best = 0;
    codes.forEach((count: number, code: number) => {
      if (count > best) {
        best = count;
        common = code;
      }
    });

    const outlook: TripOutlook = {
      low: low,
      high: high,
      unit: unit,
      commonCode: common,
      rainyDays: rainy,
      forecastDays: forecastCount,
      typicalDays: typicalCount
    };
    return outlook;
  }

  /** Packing suggestions from the trip's days. Temperatures are compared in °C. */
  static packingFor(days: TripDay[]): PackingItem[] {
    let maxHigh: number | undefined = undefined;
    let minLow: number | undefined = undefined;
    let maxWind: number | undefined = undefined;
    let rainy = 0;
    const temps = (lowC: number, highC: number): void => {
      maxHigh = maxHigh === undefined || highC > maxHigh ? highC : maxHigh;
      minLow = minLow === undefined || lowC < minLow ? lowC : minLow;
    };

    for (const day of days) {
      const daily = day.daily;
      if (day.kind === DayKind.Forecast && daily !== undefined) {
        temps(UnitConverter.toCelsius(daily.temperatureMin.value, daily.temperatureMin.unit),
          UnitConverter.toCelsius(daily.temperatureMax.value, daily.temperatureMax.unit));
        if (TripUtil.isRainy(daily)) {
          rainy++;
        }
        const wind = daily.windSpeedMax;
        if (wind !== undefined) {
          const kmh = UnitConverter.toKmh(wind.value, wind.unit);
          maxWind = maxWind === undefined || kmh > maxWind ? kmh : maxWind;
        }
      } else if (day.kind === DayKind.Typical && day.high !== undefined && day.low !== undefined) {
        const unit = day.unit ?? '°C';
        temps(UnitConverter.toCelsius(day.low, unit), UnitConverter.toCelsius(day.high, unit));
      }
    }

    const items: PackingItem[] = [];
    const high: number = maxHigh ?? NaN;
    const low: number = minLow ?? NaN;
    const wind: number = maxWind ?? NaN;
    if (rainy > 0) {
      items.push(PackingItem.Umbrella);
    }
    if (rainy >= 3) {
      items.push(PackingItem.RainJacket);
    }
    if (high >= 27) {
      items.push(PackingItem.LightClothes);
    }
    if (high >= 28) {
      items.push(PackingItem.Sunscreen, PackingItem.Sunglasses, PackingItem.Hat);
    }
    if (high >= 32) {
      items.push(PackingItem.WaterBottle);
    }
    if (high >= 26 && rainy > 0) {
      items.push(PackingItem.InsectRepellent);
    }
    if (low <= 12) {
      items.push(PackingItem.WarmLayer);
    }
    if (low <= 3) {
      items.push(PackingItem.Coat, PackingItem.Gloves);
    }
    if (wind >= 40) {
      items.push(PackingItem.Windbreaker);
    }
    return items;
  }
}
