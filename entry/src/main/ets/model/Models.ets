/**
 * Domain data, as plain interfaces so it can be saved with JSON.stringify and
 * read back with JSON.parse (ArkTS-friendly, no class instances to rebuild).
 *
 * Times *at a place* ("wall time") are stored as milliseconds where the
 * place's local wall clock is encoded as if it were UTC: 15:00 in Lagos and
 * 15:00 in Tokyo are both "15:00 UTC". Read them with getUTC*() or format them
 * with timeZone 'UTC' (see WallTime and Format). This keeps them independent of
 * the device's own time zone, exactly like the naive DateTimes of the Flutter app.
 */

/** A number with the unit label Open-Meteo gave it ("°C", "km/h", "mm", "%"). */
export interface Value {
  value: number;
  unit: string;
}

export interface Current {
  time: number;
  weatherCode: number;
  isDay: boolean;
  temperature: Value;
  apparentTemperature: Value;
  windSpeed: Value;
  windGusts: Value;
  windDirection: Value;
  precipitation: Value;
  rain: Value;
  surfacePressure: Value;
  cloudCover: Value;
  relativeHumidity: Value;
}

export interface Hourly {
  time: number;
  weatherCode: number;
  temperature: Value;
  apparentTemperature: Value;
  dewPoint: Value;
  rain: Value;
  relativeHumidity: Value;
  precipitationProbability: Value;
  /** Whether the sun is up during this hour. */
  isDay?: boolean;
}

export interface Daily {
  /** Midnight of the day (wall time). */
  time: number;
  weatherCode: number;
  temperatureMax: Value;
  temperatureMin: Value;
  apparentTemperatureMax: Value;
  apparentTemperatureMin: Value;
  sunrise?: number;
  sunset?: number;
  precipitationSum?: Value;
  precipitationProbabilityMax?: Value;
  windSpeedMax?: Value;
}

/** Precipitation over the 15 minutes starting at [time]. */
export interface MinutelyPrecipitation {
  time: number;
  precipitation: number;
  unit: string;
}

export interface Pollen {
  /** Open-Meteo key, e.g. "grass_pollen". */
  key: string;
  /** Grains/m³. */
  value: number;
}

/** Air quality, UV and (Europe only) pollen. Missing values are undefined. */
export interface AirQuality {
  usAqi?: number;
  europeanAqi?: number;
  pm25?: number;
  pm10?: number;
  dust?: number;
  uvIndex?: number;
  pollen: Pollen[];
}

export interface Forecast {
  utcOffsetSeconds: number;
  current: Current;
  hourly: Hourly[];
  daily: Daily[];
  airQuality?: AirQuality;
  /** Next 2 hours in 15-minute steps; empty unless minute-by-minute rain is on. */
  minutely: MinutelyPrecipitation[];
}

export interface City {
  name: string;
  country: string;
  /** State / province, e.g. "Lagos". Helps tell same-named places apart. */
  region?: string;
  timezone: string;
  elevation?: number;
  latitude: number;
  longitude: number;
  forecast?: Forecast;
}

/**
 * Typical daily high/low (°C) for each day of the year, averaged over recent
 * years. Index 0..365 = day of year 1..366. null where unknown.
 */
export interface ClimateNormals {
  highs: (number | null)[];
  lows: (number | null)[];
  fromYear: number;
  toYear: number;
}

export enum AqiLevel {
  Good = 'good',
  Moderate = 'moderate',
  Sensitive = 'sensitive',
  Unhealthy = 'unhealthy',
  VeryUnhealthy = 'veryUnhealthy',
  Hazardous = 'hazardous'
}

export enum UvLevel {
  Low = 0,
  Moderate = 1,
  High = 2,
  VeryHigh = 3,
  Extreme = 4
}

export enum Anomaly {
  MuchCooler = 'muchCooler',
  Cooler = 'cooler',
  Normal = 'normal',
  Warmer = 'warmer',
  MuchWarmer = 'muchWarmer'
}
