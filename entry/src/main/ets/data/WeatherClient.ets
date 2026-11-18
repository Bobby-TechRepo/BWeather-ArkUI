import { WallTime } from '../common/WallTime';
import { Units, UnitConverter } from '../common/Units';
import {
  AirQuality, City, ClimateNormals, Current, Daily, Forecast, Hourly, MinutelyPrecipitation, Pollen, Value
} from '../model/Models';
import { AirQualityUtil, NormalsUtil } from '../model/ForecastUtil';
import { FailureKind, Http, RequestFailure } from './Http';

// ------------------------------------------------------------------ responses

interface OmCurrentUnits {
  temperature_2m?: string;
  relative_humidity_2m?: string;
  apparent_temperature?: string;
  rain?: string;
  surface_pressure?: string;
  wind_speed_10m?: string;
  wind_direction_10m?: string;
  wind_gusts_10m?: string;
  precipitation?: string;
  cloud_cover?: string;
}

interface OmCurrent {
  time?: string;
  temperature_2m?: number | null;
  relative_humidity_2m?: number | null;
  apparent_temperature?: number | null;
  is_day?: number | null;
  rain?: number | null;
  weather_code?: number | null;
  surface_pressure?: number | null;
  wind_speed_10m?: number | null;
  wind_direction_10m?: number | null;
  wind_gusts_10m?: number | null;
  precipitation?: number | null;
  cloud_cover?: number | null;
}

interface OmHourlyUnits {
  temperature_2m?: string;
  relative_humidity_2m?: string;
  dew_point_2m?: string;
  apparent_temperature?: string;
  precipitation_probability?: string;
  rain?: string;
}

interface OmHourly {
  time?: string[];
  temperature_2m?: (number | null)[];
  relative_humidity_2m?: (number | null)[];
  dew_point_2m?: (number | null)[];
  apparent_temperature?: (number | null)[];
  precipitation_probability?: (number | null)[];
  rain?: (number | null)[];
  weather_code?: (number | null)[];
  is_day?: (number | null)[];
}

interface OmDailyUnits {
  temperature_2m_max?: string;
  temperature_2m_min?: string;
  apparent_temperature_max?: string;
  apparent_temperature_min?: string;
  precipitation_sum?: string;
  precipitation_probability_max?: string;
  wind_speed_10m_max?: string;
}

interface OmDaily {
  time?: string[];
  weather_code?: (number | null)[];
  temperature_2m_max?: (number | null)[];
  temperature_2m_min?: (number | null)[];
  apparent_temperature_max?: (number | null)[];
  apparent_temperature_min?: (number | null)[];
  sunrise?: string[];
  sunset?: string[];
  precipitation_sum?: (number | null)[];
  precipitation_probability_max?: (number | null)[];
  wind_speed_10m_max?: (number | null)[];
}

interface OmMinutelyUnits {
  precipitation?: string;
}

interface OmMinutely {
  time?: string[];
  precipitation?: (number | null)[];
}

interface OmForecastResponse {
  elevation?: number;
  timezone?: string;
  utc_offset_seconds?: number;
  current_units?: OmCurrentUnits;
  current?: OmCurrent;
  hourly_units?: OmHourlyUnits;
  hourly?: OmHourly;
  daily_units?: OmDailyUnits;
  daily?: OmDaily;
  minutely_15_units?: OmMinutelyUnits;
  minutely_15?: OmMinutely;
}

interface OmDailyResponse {
  daily_units?: OmDailyUnits;
  daily?: OmDaily;
}

interface OmAirCurrent {
  european_aqi?: number | null;
  us_aqi?: number | null;
  pm10?: number | null;
  pm2_5?: number | null;
  dust?: number | null;
  uv_index?: number | null;
  alder_pollen?: number | null;
  birch_pollen?: number | null;
  grass_pollen?: number | null;
  mugwort_pollen?: number | null;
  olive_pollen?: number | null;
  ragweed_pollen?: number | null;
}

interface OmAirResponse {
  current?: OmAirCurrent;
}

interface OmArchiveDaily {
  time?: string[];
  temperature_2m_max?: (number | null)[];
  temperature_2m_min?: (number | null)[];
}

interface OmArchiveResponse {
  daily?: OmArchiveDaily;
}

interface OmGeoResult {
  name?: string;
  country?: string;
  admin1?: string;
  timezone?: string;
  latitude?: number;
  longitude?: number;
  elevation?: number;
}

interface OmGeoResponse {
  results?: OmGeoResult[];
}

interface NominatimAddress {
  city?: string;
  town?: string;
  village?: string;
  hamlet?: string;
  suburb?: string;
  municipality?: string;
  county?: string;
  state?: string;
  country?: string;
}

interface NominatimResponse {
  name?: string;
  address?: NominatimAddress;
}

interface IpApiResponse {
  error?: boolean;
  city?: string;
  region?: string;
  country_name?: string;
  latitude?: number;
  longitude?: number;
  timezone?: string;
}

/** A forecast and the place details the API resolved for the request. */
export interface ForecastResult {
  forecast: Forecast;
  timezone: string;
  elevation?: number;
}

/** Name and country for a coordinate, from reverse geocoding. */
export interface PlaceName {
  name: string;
  country: string;
  region?: string;
}

/** Daily highs/lows (°C) from the historical archive; null where missing. */
export interface DailyHistory {
  time: number[];
  maxima: (number | null)[];
  minima: (number | null)[];
}

/** Client for Open-Meteo (forecast, archive, air quality, geocoding), Nominatim and ipapi.co. */
export class WeatherClient {
  static readonly FORECAST_URL: string = 'https://api.open-meteo.com/v1/forecast';
  static readonly ARCHIVE_URL: string = 'https://archive-api.open-meteo.com/v1/archive';
  static readonly AIR_URL: string = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static readonly GEOCODING_URL: string = 'https://geocoding-api.open-meteo.com/v1/search';
  static readonly REVERSE_URL: string = 'https://nominatim.openstreetmap.org/reverse';
  static readonly IP_URL: string = 'https://ipapi.co/json/';

  /** Nominatim's usage policy requires an identifying User-Agent. */
  static readonly USER_AGENT: string = 'BWeather/1.0 (Bsoft Limited; HarmonyOS)';

  /** Hours of hourly data to request, starting at the current hour. */
  static readonly FORECAST_HOURS: number = 48;
  /** How many days ahead the forecast reaches (today included). */
  static readonly MAX_FORECAST_DAYS: number = 16;

  static readonly DAILY_VARIABLES: string =
    'weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,' +
      'sunrise,sunset,precipitation_sum,rain_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max';

  static readonly POLLEN_KEYS: string[] =
    ['alder_pollen', 'birch_pollen', 'grass_pollen', 'mugwort_pollen', 'olive_pollen', 'ragweed_pollen'];

  /** The forecast for a coordinate in [units]. [includeMinutely] adds 2 hours of 15-minute precipitation. */
  async forecast(latitude: number, longitude: number, elevation: number | undefined, units: Units,
    includeMinutely: boolean): Promise<ForecastResult> {
    const params = new Map<string, string>();
    params.set('latitude', `${latitude}`);
    params.set('longitude', `${longitude}`);
    params.set('temperature_unit', units.temp);
    params.set('wind_speed_unit', units.wind);
    params.set('precipitation_unit', units.precipitation);
    params.set('current', 'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,rain,weather_code,pressure_msl,' + 'surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,cloud_cover');
    params.set('hourly', 'temperature_2m,relative_humidity_2m,dew_point_2m,apparent_temperature,precipitation_probability,' + 'rain,weather_code,is_day');
    params.set('daily', WeatherClient.DAILY_VARIABLES);
    params.set('forecast_hours', `${WeatherClient.FORECAST_HOURS}`);
    params.set('timezone', 'auto');
    if (elevation !== undefined) {
      params.set('elevation', `${elevation}`);
    }
    if (includeMinutely) {
      params.set('minutely_15', 'precipitation');
      params.set('forecast_minutely_15', '8');
    }

    const text = await Http.get(Http.url(WeatherClient.FORECAST_URL, params));
    try {
      const json = JSON.parse(text) as OmForecastResponse;
      const result: ForecastResult = {
        forecast: WeatherClient.mapForecast(json),
        timezone: json.timezone ?? 'auto',
        elevation: json.elevation
      };
      return result;
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
  }

  /** Daily forecast between two dates (place-local "YYYY-MM-DD"), for trips. */
  async dailyForecast(latitude: number, longitude: number, start: string, end: string, units: Units): Promise<Daily[]> {
    const params = new Map<string, string>();
    params.set('latitude', `${latitude}`);
    params.set('longitude', `${longitude}`);
    params.set('temperature_unit', units.temp);
    params.set('wind_speed_unit', units.wind);
    params.set('precipitation_unit', units.precipitation);
    params.set('daily', WeatherClient.DAILY_VARIABLES);
    params.set('start_date', start);
    params.set('end_date', end);
    params.set('timezone', 'auto');
    const text = await Http.get(Http.url(WeatherClient.FORECAST_URL, params));
    try {
      const json = JSON.parse(text) as OmDailyResponse;
      return WeatherClient.mapDaily(json.daily, json.daily_units);
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
  }

  /** Daily max/min temperature (°C) between two dates from the historical archive. */
  async dailyHistory(latitude: number, longitude: number, start: string, end: string): Promise<DailyHistory> {
    const params = new Map<string, string>();
    params.set('latitude', `${latitude}`);
    params.set('longitude', `${longitude}`);
    params.set('start_date', start);
    params.set('end_date', end);
    params.set('daily', 'temperature_2m_max,temperature_2m_min');
    params.set('timezone', 'auto');
    const text = await Http.get(Http.url(WeatherClient.ARCHIVE_URL, params), undefined, 30000);
    try {
      const daily = (JSON.parse(text) as OmArchiveResponse).daily;
      const times = daily?.time ?? [];
      const history: DailyHistory = {
        time: times.map((time: string) => WallTime.parse(time)),
        maxima: daily?.temperature_2m_max ?? [],
        minima: daily?.temperature_2m_min ?? []
      };
      return history;
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
  }

  /** Current air quality, UV index and (Europe only) pollen. */
  async airQuality(latitude: number, longitude: number): Promise<AirQuality> {
    const params = new Map<string, string>();
    params.set('latitude', `${latitude}`);
    params.set('longitude', `${longitude}`);
    params.set('current', ['european_aqi', 'us_aqi', 'pm10', 'pm2_5', 'dust', 'uv_index'].concat(WeatherClient.POLLEN_KEYS).join(','));
    params.set('timezone', 'auto');
    const text = await Http.get(Http.url(WeatherClient.AIR_URL, params));
    try {
      const current = (JSON.parse(text) as OmAirResponse).current;
      const pollen: Pollen[] = [];
      WeatherClient.addPollen(pollen, 'alder_pollen', current?.alder_pollen);
      WeatherClient.addPollen(pollen, 'birch_pollen', current?.birch_pollen);
      WeatherClient.addPollen(pollen, 'grass_pollen', current?.grass_pollen);
      WeatherClient.addPollen(pollen, 'mugwort_pollen', current?.mugwort_pollen);
      WeatherClient.addPollen(pollen, 'olive_pollen', current?.olive_pollen);
      WeatherClient.addPollen(pollen, 'ragweed_pollen', current?.ragweed_pollen);
      const air: AirQuality = {
        usAqi: WeatherClient.optional(current?.us_aqi),
        europeanAqi: WeatherClient.optional(current?.european_aqi),
        pm25: WeatherClient.optional(current?.pm2_5),
        pm10: WeatherClient.optional(current?.pm10),
        dust: WeatherClient.optional(current?.dust),
        uvIndex: WeatherClient.optional(current?.uv_index),
        pollen: pollen
      };
      return air;
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
  }

  /** Cities matching [query]. Throws NotFound when nothing matches. */
  async search(query: string, language: string): Promise<City[]> {
    const params = new Map<string, string>();
    params.set('name', query);
    params.set('count', '10');
    params.set('language', language);
    const text = await Http.get(Http.url(WeatherClient.GEOCODING_URL, params));
    let results: OmGeoResult[] = [];
    try {
      results = (JSON.parse(text) as OmGeoResponse).results ?? [];
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
    const cities: City[] = [];
    for (const result of results) {
      if (result.name === undefined || result.latitude === undefined || result.longitude === undefined) {
        continue;
      }
      const city: City = {
        name: result.name,
        country: result.country ?? '',
        region: result.admin1,
        timezone: result.timezone ?? 'auto',
        elevation: result.elevation,
        latitude: result.latitude,
        longitude: result.longitude
      };
      cities.push(city);
    }
    if (cities.length === 0) {
      throw new RequestFailure(FailureKind.NotFound, 'No places found');
    }
    return cities;
  }

  /**
   * A readable place name for a coordinate (OpenStreetMap Nominatim). Only the
   * name comes from here; the coordinate itself is never replaced.
   */
  async reverseGeocode(latitude: number, longitude: number, language: string): Promise<PlaceName> {
    const params = new Map<string, string>();
    params.set('format', 'jsonv2');
    params.set('lat', `${latitude}`);
    params.set('lon', `${longitude}`);
    params.set('zoom', '10');
    params.set('addressdetails', '1');
    params.set('accept-language', language);
    const headers: Record<string, string> = { 'User-Agent': WeatherClient.USER_AGENT };
    const text = await Http.get(Http.url(WeatherClient.REVERSE_URL, params), headers);
    let json: NominatimResponse;
    try {
      json = JSON.parse(text) as NominatimResponse;
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
    const address = json.address;
    const name = address?.city ?? address?.town ?? address?.village ?? address?.hamlet ?? address?.suburb ??
      address?.municipality ?? address?.county ?? json.name;
    if (name === undefined || name.length === 0) {
      throw new RequestFailure(FailureKind.NotFound, 'No name for this place');
    }
    const place: PlaceName = { name: name, country: address?.country ?? '', region: address?.state };
    return place;
  }

  /** Approximate location from the IP address; only used when GPS isn't available. */
  async approximateLocation(): Promise<City> {
    const text = await Http.get(WeatherClient.IP_URL);
    let json: IpApiResponse;
    try {
      json = JSON.parse(text) as IpApiResponse;
    } catch (error) {
      throw WeatherClient.dataFailure(error);
    }
    if (json.error === true || json.city === undefined || json.latitude === undefined || json.longitude === undefined) {
      throw new RequestFailure(FailureKind.NotFound, 'No approximate location');
    }
    const city: City = {
      name: json.city,
      country: json.country_name ?? '',
      region: json.region,
      timezone: json.timezone ?? 'auto',
      latitude: json.latitude,
      longitude: json.longitude
    };
    return city;
  }

  // ------------------------------------------------------------------ mapping

  private static mapForecast(json: OmForecastResponse): Forecast {
    const c = json.current;
    const cu = json.current_units;
    if (c === undefined || c.time === undefined) {
      throw new RequestFailure(FailureKind.Data, 'No current conditions');
    }
    const current: Current = {
      time: WallTime.parse(c.time),
      weatherCode: WeatherClient.num(c.weather_code, 0),
      isDay: WeatherClient.num(c.is_day, 1) === 1,
      temperature: WeatherClient.value(c.temperature_2m, cu?.temperature_2m, '°C'),
      apparentTemperature: WeatherClient.value(c.apparent_temperature, cu?.apparent_temperature, '°C'),
      windSpeed: WeatherClient.value(c.wind_speed_10m, cu?.wind_speed_10m, 'km/h'),
      windGusts: WeatherClient.value(c.wind_gusts_10m, cu?.wind_gusts_10m, 'km/h'),
      windDirection: WeatherClient.value(c.wind_direction_10m, cu?.wind_direction_10m, '°'),
      precipitation: WeatherClient.value(c.precipitation, cu?.precipitation, 'mm'),
      rain: WeatherClient.value(c.rain, cu?.rain, 'mm'),
      surfacePressure: WeatherClient.value(c.surface_pressure, cu?.surface_pressure, 'hPa'),
      cloudCover: WeatherClient.value(c.cloud_cover, cu?.cloud_cover, '%'),
      relativeHumidity: WeatherClient.value(c.relative_humidity_2m, cu?.relative_humidity_2m, '%')
    };

    const h = json.hourly;
    const hu = json.hourly_units;
    const hourly: Hourly[] = [];
    const hourTimes = h?.time ?? [];
    const hourCount = Math.min(hourTimes.length, h?.weather_code?.length ?? 0, h?.temperature_2m?.length ?? 0);
    for (let i = 0; i < hourCount; i++) {
      const temperature = WeatherClient.at(h?.temperature_2m, i, 0);
      const isDay = WeatherClient.atOptional(h?.is_day, i);
      const hour: Hourly = {
        time: WallTime.parse(hourTimes[i]),
        weatherCode: WeatherClient.at(h?.weather_code, i, 0),
        temperature: WeatherClient.unitValue(temperature, hu?.temperature_2m, '°C'),
        apparentTemperature: WeatherClient.unitValue(WeatherClient.at(h?.apparent_temperature, i, temperature), hu?.apparent_temperature, '°C'),
        dewPoint: WeatherClient.unitValue(WeatherClient.at(h?.dew_point_2m, i, 0), hu?.dew_point_2m, '°C'),
        rain: WeatherClient.unitValue(WeatherClient.at(h?.rain, i, 0), hu?.rain, 'mm'),
        relativeHumidity: WeatherClient.unitValue(WeatherClient.at(h?.relative_humidity_2m, i, 0), hu?.relative_humidity_2m, '%'),
        precipitationProbability: WeatherClient.unitValue(WeatherClient.at(h?.precipitation_probability, i, 0), hu?.precipitation_probability, '%'),
        isDay: isDay === undefined ? undefined : isDay === 1
      };
      hourly.push(hour);
    }

    const m = json.minutely_15;
    const minutely: MinutelyPrecipitation[] = [];
    const stepTimes = m?.time ?? [];
    const stepCount = Math.min(stepTimes.length, m?.precipitation?.length ?? 0);
    for (let i = 0; i < stepCount; i++) {
      const step: MinutelyPrecipitation = {
        time: WallTime.parse(stepTimes[i]),
        precipitation: WeatherClient.at(m?.precipitation, i, 0),
        unit: json.minutely_15_units?.precipitation ?? 'mm'
      };
      minutely.push(step);
    }

    const forecast: Forecast = {
      utcOffsetSeconds: json.utc_offset_seconds ?? 0,
      current: current,
      hourly: hourly,
      daily: WeatherClient.mapDaily(json.daily, json.daily_units),
      minutely: minutely
    };
    return forecast;
  }

  static mapDaily(d: OmDaily | undefined, du: OmDailyUnits | undefined): Daily[] {
    const days: Daily[] = [];
    const times = d?.time ?? [];
    const count = Math.min(times.length, d?.weather_code?.length ?? 0, d?.temperature_2m_max?.length ?? 0,
      d?.temperature_2m_min?.length ?? 0);
    for (let i = 0; i < count; i++) {
      const max = WeatherClient.at(d?.temperature_2m_max, i, 0);
      const min = WeatherClient.at(d?.temperature_2m_min, i, 0);
      const sunrise = d?.sunrise !== undefined && i < d.sunrise.length ? WallTime.parse(d.sunrise[i]) : NaN;
      const sunset = d?.sunset !== undefined && i < d.sunset.length ? WallTime.parse(d.sunset[i]) : NaN;
      const precipitation = WeatherClient.atOptional(d?.precipitation_sum, i);
      const probability = WeatherClient.atOptional(d?.precipitation_probability_max, i);
      const wind = WeatherClient.atOptional(d?.wind_speed_10m_max, i);
      const day: Daily = {
        time: WallTime.parse(times[i]),
        weatherCode: WeatherClient.at(d?.weather_code, i, 0),
        temperatureMax: WeatherClient.unitValue(max, du?.temperature_2m_max, '°C'),
        temperatureMin: WeatherClient.unitValue(min, du?.temperature_2m_min, '°C'),
        apparentTemperatureMax: WeatherClient.unitValue(WeatherClient.at(d?.apparent_temperature_max, i, max), du?.apparent_temperature_max, '°C'),
        apparentTemperatureMin: WeatherClient.unitValue(WeatherClient.at(d?.apparent_temperature_min, i, min), du?.apparent_temperature_min, '°C'),
        sunrise: isNaN(sunrise) ? undefined : sunrise,
        sunset: isNaN(sunset) ? undefined : sunset,
        precipitationSum: precipitation === undefined ? undefined : WeatherClient.unitValue(precipitation, du?.precipitation_sum, 'mm'),
        precipitationProbabilityMax: probability === undefined ? undefined :
          WeatherClient.unitValue(probability, du?.precipitation_probability_max, '%'),
        windSpeedMax: wind === undefined ? undefined : WeatherClient.unitValue(wind, du?.wind_speed_10m_max, 'km/h')
      };
      days.push(day);
    }
    return days;
  }

  /** Only pollen that is actually reported is kept. */
  private static addPollen(list: Pollen[], key: string, value: number | null | undefined): void {
    if (value !== null && value !== undefined) {
      const pollen: Pollen = { key: key, value: value };
      list.push(pollen);
    }
  }

  private static num(value: number | null | undefined, fallback: number): number {
    return value === null || value === undefined ? fallback : value;
  }

  private static optional(value: number | null | undefined): number | undefined {
    return value === null || value === undefined ? undefined : value;
  }

  private static value(value: number | null | undefined, unit: string | undefined, fallbackUnit: string): Value {
    return WeatherClient.unitValue(WeatherClient.num(value, 0), unit, fallbackUnit);
  }

  private static unitValue(value: number, unit: string | undefined, fallbackUnit: string): Value {
    const result: Value = { value: value, unit: unit ?? fallbackUnit };
    return result;
  }

  /** Open-Meteo returns null inside arrays for hours a model doesn't cover; those become [fallback]. */
  private static at(list: (number | null)[] | undefined, index: number, fallback: number): number {
    if (list === undefined || index >= list.length) {
      return fallback;
    }
    const value = list[index];
    return value === null || value === undefined ? fallback : value;
  }

  private static atOptional(list: (number | null)[] | undefined, index: number): number | undefined {
    if (list === undefined || index >= list.length) {
      return undefined;
    }
    const value = list[index];
    return value === null || value === undefined ? undefined : value;
  }

  private static dataFailure(error: Object): RequestFailure {
    if (error instanceof RequestFailure) {
      return error;
    }
    return new RequestFailure(FailureKind.Data, 'Response could not be read');
  }
}

/** Places and forecasts, mapped from the clients into app models (lib/.../forecast_repository.dart). */
export class ForecastRepository {
  /** Years of history averaged into climate normals. */
  static readonly NORMALS_YEARS: number = 20;
  /** Days before today that a trip view still asks the forecast API for. */
  static readonly PAST_DAYS: number = 7;

  private readonly client: WeatherClient = new WeatherClient();

  /**
   * [city] with a fresh forecast attached. Name, country and region are kept;
   * timezone and elevation come from the API. The requested coordinates are
   * kept too, so the place's id stays stable across refreshes.
   */
  async getWeather(city: City, units: Units, includeMinutely: boolean): Promise<City> {
    // Air quality is optional: if it fails, the forecast still loads.
    const airPromise: Promise<AirQuality | undefined> = this.client.airQuality(city.latitude, city.longitude)
      .then((air: AirQuality) => AirQualityUtil.isEmpty(air) ? undefined : air)
      .catch((): AirQuality | undefined => undefined);
    const result = await this.client.forecast(city.latitude, city.longitude, city.elevation, units, includeMinutely);
    const air = await airPromise;
    const forecast: Forecast = {
      utcOffsetSeconds: result.forecast.utcOffsetSeconds,
      current: result.forecast.current,
      hourly: result.forecast.hourly,
      daily: result.forecast.daily,
      airQuality: air,
      minutely: result.forecast.minutely
    };
    const updated: City = {
      name: city.name,
      country: city.country,
      region: city.region,
      timezone: result.timezone,
      elevation: result.elevation,
      latitude: city.latitude,
      longitude: city.longitude,
      forecast: forecast
    };
    return updated;
  }

  /** Typical daily highs/lows (°C) over the last 20 complete years. One request; cache per place. */
  async climateNormals(latitude: number, longitude: number): Promise<ClimateNormals> {
    const year = new Date().getFullYear();
    const history = await this.client.dailyHistory(latitude, longitude,
      `${year - ForecastRepository.NORMALS_YEARS}-01-01`, `${year - 1}-12-31`);
    const normals = NormalsUtil.fromDaily(history.time, history.maxima, history.minima);
    if (normals.toYear === 0) {
      throw new RequestFailure(FailureKind.Data, 'No history');
    }
    return normals;
  }

  async search(query: string, language: string): Promise<City[]> {
    return this.client.search(query.trim(), language);
  }

  /**
   * A city for an exact GPS coordinate. Reverse geocoding only supplies a
   * display name; if naming fails the place is still usable as "My location".
   */
  async locate(latitude: number, longitude: number, language: string, fallbackName: string): Promise<City> {
    let name = fallbackName;
    let country = '';
    let region: string | undefined = undefined;
    try {
      const place = await this.client.reverseGeocode(latitude, longitude, language);
      name = place.name;
      country = place.country;
      region = place.region;
    } catch (error) {
      // Keep the generic name.
    }
    const city: City = { name: name, country: country, region: region, timezone: 'auto', latitude: latitude, longitude: longitude };
    return city;
  }

  async approximateLocation(): Promise<City> {
    return this.client.approximateLocation();
  }

  /** Daily forecast for trips (metric; converted on the device). Dates are "YYYY-MM-DD" at the place. */
  async dailyForecast(city: City, start: string, end: string): Promise<Daily[]> {
    return this.client.dailyForecast(city.latitude, city.longitude, start, end, UnitConverter.METRIC);
  }
}
