import { City, Current, Daily, Forecast, Hourly, MinutelyPrecipitation, Value } from '../model/Models';

export enum TempUnit {
  Celsius = 'celsius',
  Fahrenheit = 'fahrenheit'
}

export enum WindSpeedUnit {
  Kmh = 'kmh',
  Mph = 'mph',
  Ms = 'ms',
  Kn = 'kn'
}

export enum PrecipitationUnit {
  Mm = 'mm',
  Inch = 'inch'
}

export interface Units {
  temp: TempUnit;
  wind: WindSpeedUnit;
  precipitation: PrecipitationUnit;
}

/** Converted value and its new unit label. */
export interface Converted {
  value: number;
  unit: string;
}

/**
 * Converts temperatures, wind speeds and precipitation on the device, so
 * changing units needs no new request (same as the Flutter app).
 *
 * Values are recognised by their unit label, exactly as Open-Meteo writes them:
 * "°C"/"°F", "km/h"/"mp/h"/"m/s"/"kn", "mm"/"inch". Anything else (%, °, hPa)
 * is left alone.
 */
export class UnitConverter {
  /** What the app fetches in; the user's units are applied on the device. */
  static readonly METRIC: Units = { temp: TempUnit.Celsius, wind: WindSpeedUnit.Kmh, precipitation: PrecipitationUnit.Mm };

  static same(a: Units, b: Units): boolean {
    return a.temp === b.temp && a.wind === b.wind && a.precipitation === b.precipitation;
  }

  static temperatureLabel(unit: TempUnit): string {
    return unit === TempUnit.Fahrenheit ? '°F' : '°C';
  }

  static windLabel(unit: WindSpeedUnit): string {
    switch (unit) {
      case WindSpeedUnit.Mph:
        return 'mp/h';
      case WindSpeedUnit.Ms:
        return 'm/s';
      case WindSpeedUnit.Kn:
        return 'kn';
      default:
        return 'km/h';
    }
  }

  static precipitationLabel(unit: PrecipitationUnit): string {
    return unit === PrecipitationUnit.Inch ? 'inch' : 'mm';
  }

  /** [value] (in [unit]) expressed in [units]; unchanged when the unit isn't a temperature, speed or amount. */
  static convert(value: number, unit: string, units: Units): Converted {
    const key = unit.toLowerCase().replace(/ /g, '');

    if (key === '°c' || key === '°f') {
      const celsius = key === '°f' ? (value - 32) * 5 / 9 : value;
      const out = units.temp === TempUnit.Fahrenheit ? celsius * 9 / 5 + 32 : celsius;
      const result: Converted = { value: UnitConverter.round(out), unit: UnitConverter.temperatureLabel(units.temp) };
      return result;
    }

    const toKmh = UnitConverter.kmhFactor(key);
    if (toKmh > 0) {
      const kmh = value * toKmh;
      let out = kmh;
      if (units.wind === WindSpeedUnit.Mph) {
        out = kmh / 1.609344;
      } else if (units.wind === WindSpeedUnit.Ms) {
        out = kmh / 3.6;
      } else if (units.wind === WindSpeedUnit.Kn) {
        out = kmh / 1.852;
      }
      const result: Converted = { value: UnitConverter.round(out), unit: UnitConverter.windLabel(units.wind) };
      return result;
    }

    const toMm = UnitConverter.mmFactor(key);
    if (toMm > 0) {
      const mm = value * toMm;
      const out = units.precipitation === PrecipitationUnit.Inch ? mm / 25.4 : mm;
      const result: Converted = { value: UnitConverter.round(out), unit: UnitConverter.precipitationLabel(units.precipitation) };
      return result;
    }

    const same: Converted = { value: value, unit: unit };
    return same;
  }

  static value(input: Value, units: Units): Value {
    const converted = UnitConverter.convert(input.value, input.unit, units);
    if (converted.value === input.value && converted.unit === input.unit) {
      return input;
    }
    const result: Value = { value: converted.value, unit: converted.unit };
    return result;
  }

  static maybe(input: Value | undefined, units: Units): Value | undefined {
    return input === undefined ? undefined : UnitConverter.value(input, units);
  }

  /** °C from a value in "°C" or "°F". */
  static toCelsius(value: number, unit: string): number {
    return unit.toUpperCase().includes('F') ? (value - 32) * 5 / 9 : value;
  }

  /** km/h from any wind speed unit label. */
  static toKmh(value: number, unit: string): number {
    const factor = UnitConverter.kmhFactor(unit.toLowerCase().replace(/ /g, ''));
    return factor > 0 ? value * factor : value;
  }

  /** mm from "mm" or "inch". */
  static toMm(value: number, unit: string): number {
    return unit.toLowerCase().includes('inch') ? value * 25.4 : value;
  }

  private static kmhFactor(key: string): number {
    switch (key) {
      case 'km/h':
      case 'kmh':
        return 1.0;
      case 'mp/h':
      case 'mph':
        return 1.609344;
      case 'm/s':
      case 'ms':
        return 3.6;
      case 'kn':
      case 'kt':
      case 'knots':
        return 1.852;
      default:
        return 0;
    }
  }

  private static mmFactor(key: string): number {
    switch (key) {
      case 'mm':
        return 1.0;
      case 'inch':
      case 'in':
      case 'inches':
        return 25.4;
      default:
        return 0;
    }
  }

  /** Keeps repeated conversions from drifting, yet precise enough to convert back. */
  static round(value: number): number {
    return Math.round(value * 10000) / 10000;
  }

  // ------------------------------------------------------------ whole forecasts

  static current(current: Current, units: Units): Current {
    const result: Current = {
      time: current.time,
      weatherCode: current.weatherCode,
      isDay: current.isDay,
      temperature: UnitConverter.value(current.temperature, units),
      apparentTemperature: UnitConverter.value(current.apparentTemperature, units),
      windSpeed: UnitConverter.value(current.windSpeed, units),
      windGusts: UnitConverter.value(current.windGusts, units),
      windDirection: current.windDirection,
      precipitation: UnitConverter.value(current.precipitation, units),
      rain: UnitConverter.value(current.rain, units),
      surfacePressure: current.surfacePressure,
      cloudCover: current.cloudCover,
      relativeHumidity: current.relativeHumidity
    };
    return result;
  }

  static hourly(hour: Hourly, units: Units): Hourly {
    const result: Hourly = {
      time: hour.time,
      weatherCode: hour.weatherCode,
      temperature: UnitConverter.value(hour.temperature, units),
      apparentTemperature: UnitConverter.value(hour.apparentTemperature, units),
      dewPoint: UnitConverter.value(hour.dewPoint, units),
      rain: UnitConverter.value(hour.rain, units),
      relativeHumidity: hour.relativeHumidity,
      precipitationProbability: hour.precipitationProbability,
      isDay: hour.isDay
    };
    return result;
  }

  static daily(day: Daily, units: Units): Daily {
    const result: Daily = {
      time: day.time,
      weatherCode: day.weatherCode,
      temperatureMax: UnitConverter.value(day.temperatureMax, units),
      temperatureMin: UnitConverter.value(day.temperatureMin, units),
      apparentTemperatureMax: UnitConverter.value(day.apparentTemperatureMax, units),
      apparentTemperatureMin: UnitConverter.value(day.apparentTemperatureMin, units),
      sunrise: day.sunrise,
      sunset: day.sunset,
      precipitationSum: UnitConverter.maybe(day.precipitationSum, units),
      precipitationProbabilityMax: day.precipitationProbabilityMax,
      windSpeedMax: UnitConverter.maybe(day.windSpeedMax, units)
    };
    return result;
  }

  static minutely(step: MinutelyPrecipitation, units: Units): MinutelyPrecipitation {
    const converted = UnitConverter.convert(step.precipitation, step.unit, units);
    const result: MinutelyPrecipitation = { time: step.time, precipitation: converted.value, unit: converted.unit };
    return result;
  }

  /** The same forecast with every temperature, speed and amount in [units]. */
  static forecast(forecast: Forecast, units: Units): Forecast {
    const result: Forecast = {
      utcOffsetSeconds: forecast.utcOffsetSeconds,
      current: UnitConverter.current(forecast.current, units),
      hourly: forecast.hourly.map((hour: Hourly) => UnitConverter.hourly(hour, units)),
      daily: forecast.daily.map((day: Daily) => UnitConverter.daily(day, units)),
      airQuality: forecast.airQuality,
      minutely: forecast.minutely.map((step: MinutelyPrecipitation) => UnitConverter.minutely(step, units))
    };
    return result;
  }

  static city(city: City, units: Units): City {
    const forecast = city.forecast;
    if (forecast === undefined) {
      return city;
    }
    const result: City = {
      name: city.name,
      country: city.country,
      region: city.region,
      timezone: city.timezone,
      elevation: city.elevation,
      latitude: city.latitude,
      longitude: city.longitude,
      forecast: UnitConverter.forecast(forecast, units)
    };
    return result;
  }
}
