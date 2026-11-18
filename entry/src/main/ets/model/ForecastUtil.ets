import { WallTime } from '../common/WallTime';
import { UnitConverter } from '../common/Units';
import {
  AirQuality, Anomaly, AqiLevel, City, ClimateNormals, Daily, Forecast, Hourly, MinutelyPrecipitation, UvLevel
} from './Models';

/** Questions about a forecast, always answered for the time *at the place*. */
export class ForecastUtil {
  static localNow(forecast: Forecast, now?: number): number {
    return WallTime.localNow(forecast.utcOffsetSeconds, now);
  }

  /** The next [count] hours starting with the current hour at the place. */
  static upcomingHours(forecast: Forecast, count: number, now?: number): Hourly[] {
    const currentHour = WallTime.startOfHour(ForecastUtil.localNow(forecast, now));
    const start = forecast.hourly.findIndex((hour: Hourly) => hour.time >= currentHour);
    if (start === -1) {
      return [];
    }
    return forecast.hourly.slice(start, Math.min(start + count, forecast.hourly.length));
  }

  static currentHour(forecast: Forecast, now?: number): Hourly | undefined {
    const hours = ForecastUtil.upcomingHours(forecast, 1, now);
    return hours.length === 0 ? undefined : hours[0];
  }

  /** Today's entry at the place (or the first day if today isn't in the data). */
  static today(forecast: Forecast, now?: number): Daily | undefined {
    const local = ForecastUtil.localNow(forecast, now);
    const found = forecast.daily.find((day: Daily) => WallTime.sameDay(day.time, local));
    if (found !== undefined) {
      return found;
    }
    return forecast.daily.length === 0 ? undefined : forecast.daily[0];
  }

  /**
   * Whether [hour] is during the night: the API's per-hour is_day, then that
   * day's sunrise/sunset, and only as a last resort 06:00–18:00.
   */
  static isNight(forecast: Forecast, hour: Hourly): boolean {
    if (hour.isDay !== undefined) {
      return !hour.isDay;
    }
    const day = forecast.daily.find((d: Daily) => WallTime.sameDay(d.time, hour.time));
    if (day !== undefined && day.sunrise !== undefined && day.sunset !== undefined) {
      return hour.time < day.sunrise || hour.time >= day.sunset;
    }
    const h = WallTime.hour(hour.time);
    return h < 6 || h >= 18;
  }

  /** The 15-minute steps from the current one onwards. */
  static upcomingMinutely(forecast: Forecast, now?: number): MinutelyPrecipitation[] {
    const local = ForecastUtil.localNow(forecast, now);
    return forecast.minutely.filter((step: MinutelyPrecipitation) => step.time + 15 * WallTime.MINUTE > local);
  }
}

export class CityUtil {
  /** Stable identity for a saved place: its coordinate rounded to ~100 m. */
  static id(city: City): string {
    return `${city.latitude.toFixed(3)},${city.longitude.toFixed(3)}`;
  }

  /** "Lagos, Nigeria": region and country, skipping empty parts. */
  static subtitle(city: City): string {
    const parts: string[] = [];
    if (city.region !== undefined && city.region.length > 0) {
      parts.push(city.region);
    }
    if (city.country.length > 0) {
      parts.push(city.country);
    }
    return parts.join(', ');
  }

  /** Great-circle distance in km. */
  static distanceKm(latitude1: number, longitude1: number, latitude2: number, longitude2: number): number {
    const radians = (degrees: number): number => degrees * Math.PI / 180;
    const dLat = radians(latitude2 - latitude1);
    const dLon = radians(longitude2 - longitude1);
    const a = Math.pow(Math.sin(dLat / 2), 2) +
      Math.cos(radians(latitude1)) * Math.cos(radians(latitude2)) * Math.pow(Math.sin(dLon / 2), 2);
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}

export class AirQualityUtil {
  /** Dust above this (µg/m³) triggers the mask hint (Harmattan season). */
  static readonly DUST_WARNING: number = 150;

  static isEmpty(air: AirQuality): boolean {
    return air.usAqi === undefined && air.europeanAqi === undefined && air.pm25 === undefined &&
      air.pm10 === undefined && air.dust === undefined && air.uvIndex === undefined && air.pollen.length === 0;
  }

  /** US EPA bands. */
  static aqiLevel(air: AirQuality): AqiLevel | undefined {
    const aqi = air.usAqi;
    if (aqi === undefined) {
      return undefined;
    }
    if (aqi <= 50) {
      return AqiLevel.Good;
    }
    if (aqi <= 100) {
      return AqiLevel.Moderate;
    }
    if (aqi <= 150) {
      return AqiLevel.Sensitive;
    }
    if (aqi <= 200) {
      return AqiLevel.Unhealthy;
    }
    if (aqi <= 300) {
      return AqiLevel.VeryUnhealthy;
    }
    return AqiLevel.Hazardous;
  }

  /** WHO bands. */
  static uvLevel(air: AirQuality): UvLevel | undefined {
    const uv = air.uvIndex;
    if (uv === undefined) {
      return undefined;
    }
    const rounded = Math.round(uv);
    if (rounded <= 2) {
      return UvLevel.Low;
    }
    if (rounded <= 5) {
      return UvLevel.Moderate;
    }
    if (rounded <= 7) {
      return UvLevel.High;
    }
    if (rounded <= 10) {
      return UvLevel.VeryHigh;
    }
    return UvLevel.Extreme;
  }
}

export class NormalsUtil {
  /** Days on each side of a date included in its average (smooths noise). */
  static readonly WINDOW_DAYS: number = 7;
  /** Differences smaller than this (°C) count as "about normal". */
  static readonly NORMAL_BAND_C: number = 1.5;
  static readonly LARGE_C: number = 5.0;

  static highFor(normals: ClimateNormals, time: number): number | undefined {
    return NormalsUtil.at(normals.highs, WallTime.dayOfYear(time));
  }

  static lowFor(normals: ClimateNormals, time: number): number | undefined {
    return NormalsUtil.at(normals.lows, WallTime.dayOfYear(time));
  }

  private static at(values: (number | null)[], day: number): number | undefined {
    if (day < 1 || day > values.length) {
      return undefined;
    }
    const value = values[day - 1];
    return value === null || value === undefined ? undefined : value;
  }

  /**
   * For every day of the year, the mean of all values within ±WINDOW_DAYS of
   * that calendar day across all years. [dates] are wall times.
   */
  static fromDaily(dates: number[], maxima: (number | null)[], minima: (number | null)[]): ClimateNormals {
    const count = Math.min(dates.length, maxima.length, minima.length);
    const highSums: number[] = new Array<number>(366).fill(0);
    const lowSums: number[] = new Array<number>(366).fill(0);
    const highCounts: number[] = new Array<number>(366).fill(0);
    const lowCounts: number[] = new Array<number>(366).fill(0);
    let fromYear = 9999;
    let toYear = 0;

    for (let i = 0; i < count; i++) {
      const high = maxima[i];
      const low = minima[i];
      if ((high === null || high === undefined) && (low === null || low === undefined)) {
        continue;
      }
      const day = WallTime.dayOfYear(dates[i]);
      const year = WallTime.year(dates[i]);
      fromYear = Math.min(fromYear, year);
      toYear = Math.max(toYear, year);
      for (let offset = -NormalsUtil.WINDOW_DAYS; offset <= NormalsUtil.WINDOW_DAYS; offset++) {
        const target = ((day - 1 + offset) % 366 + 366) % 366;
        if (high !== null && high !== undefined) {
          highSums[target] += high;
          highCounts[target]++;
        }
        if (low !== null && low !== undefined) {
          lowSums[target] += low;
          lowCounts[target]++;
        }
      }
    }

    const highs: (number | null)[] = [];
    const lows: (number | null)[] = [];
    for (let d = 0; d < 366; d++) {
      // Rounded to 0.1 °C to keep the saved state small.
      highs.push(highCounts[d] === 0 ? null : Math.round(highSums[d] / highCounts[d] * 10) / 10);
      lows.push(lowCounts[d] === 0 ? null : Math.round(lowSums[d] / lowCounts[d] * 10) / 10);
    }
    const normals: ClimateNormals = { highs: highs, lows: lows, fromYear: toYear === 0 ? 0 : fromYear, toYear: toYear };
    return normals;
  }

  /** Today's forecast high minus the normal high, in °C; undefined when either is unknown. */
  static differenceC(forecast: Forecast | undefined, normals: ClimateNormals | undefined): number | undefined {
    if (forecast === undefined || normals === undefined) {
      return undefined;
    }
    const today = ForecastUtil.today(forecast);
    if (today === undefined) {
      return undefined;
    }
    const normalHigh = NormalsUtil.highFor(normals, today.time);
    if (normalHigh === undefined) {
      return undefined;
    }
    return UnitConverter.toCelsius(today.temperatureMax.value, today.temperatureMax.unit) - normalHigh;
  }

  static anomaly(differenceC: number): Anomaly {
    if (differenceC <= -NormalsUtil.LARGE_C) {
      return Anomaly.MuchCooler;
    }
    if (differenceC <= -NormalsUtil.NORMAL_BAND_C) {
      return Anomaly.Cooler;
    }
    if (differenceC >= NormalsUtil.LARGE_C) {
      return Anomaly.MuchWarmer;
    }
    if (differenceC >= NormalsUtil.NORMAL_BAND_C) {
      return Anomaly.Warmer;
    }
    return Anomaly.Normal;
  }

  /** The difference in degrees of the user's unit ("°C" or "°F"), rounded and positive. */
  static degreesIn(differenceC: number, unit: string): number {
    const value = unit.toUpperCase().includes('F') ? differenceC * 9 / 5 : differenceC;
    return Math.round(Math.abs(value));
  }
}
