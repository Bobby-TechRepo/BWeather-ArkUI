import { PrecipitationUnit, TempUnit, Units, WindSpeedUnit } from '../common/Units';
import { AlertPrefs, AlertPrefsUtil } from '../model/Alerts';
import { City, ClimateNormals } from '../model/Models';

export enum Status {
  Initial = 'initial',
  Loading = 'loading',
  Success = 'success',
  Failure = 'failure'
}

/** Why the latest forecast request for a place failed. */
export enum ForecastIssue {
  None = 'none',
  Network = 'network',
  Data = 'data',
  Unknown = 'unknown'
}

/** Why the user's location couldn't be determined. */
export enum LocationIssue {
  None = 'none',
  ServiceDisabled = 'serviceDisabled',
  PermissionDenied = 'permissionDenied',
  PermissionBlocked = 'permissionBlocked',
  Unavailable = 'unavailable'
}

export enum AppTab {
  Forecast = 'forecast',
  Locations = 'locations',
  Trips = 'trips',
  Settings = 'settings'
}

export enum ThemeMode {
  Auto = 'auto',
  Light = 'light',
  Dark = 'dark'
}

/** Key used for the user's own location. */
export const CURRENT_LOCATION_KEY: string = 'current';

/** A place shown in the app (the user's location or a saved city) and its latest request. */
export interface CityState {
  /** Stable identity used by the store and UI; never a list position. */
  key: string;
  city: City;
  status: Status;
  /** Reason for the last failure (not meaningful after a restart). */
  issue: ForecastIssue;
  /** When the forecast was last fetched successfully (device clock, ms). */
  updatedAt?: number;
  /** True when the location came from the IP address rather than GPS. */
  approximate: boolean;
  /** Typical highs/lows here, for "warmer than usual". Fetched once per place. */
  normals?: ClimateNormals;
}

export interface WeatherState {
  location?: CityState;
  cities: CityState[];
  /** Status of finding the user's location (forecasts have their own). */
  status: Status;
  locationIssue: LocationIssue;
  /** Whether the welcome screen is done. */
  onboarded: boolean;
}

export interface SettingsState {
  temp: TempUnit;
  wind: WindSpeedUnit;
  precipitation: PrecipitationUnit;
  theme: ThemeMode;
  /** App language code ("fr"), or "" to follow the device. */
  language: string;
  /** 15-minute rain for the next 2 hours. Off by default (larger requests). */
  minuteRain: boolean;
  /** Animated sky behind the forecast. */
  animatedBackground: boolean;
  /** Morning briefing and weather alerts (all off by default). */
  alerts: AlertPrefs;
}

export class States {
  static defaultSettings(): SettingsState {
    const settings: SettingsState = {
      temp: TempUnit.Celsius,
      wind: WindSpeedUnit.Kmh,
      precipitation: PrecipitationUnit.Mm,
      theme: ThemeMode.Auto,
      language: '',
      minuteRain: false,
      animatedBackground: true,
      alerts: AlertPrefsUtil.defaults()
    };
    return settings;
  }

  static units(settings: SettingsState): Units {
    const units: Units = { temp: settings.temp, wind: settings.wind, precipitation: settings.precipitation };
    return units;
  }

  static emptyWeather(): WeatherState {
    const state: WeatherState = {
      cities: [],
      status: Status.Initial,
      locationIssue: LocationIssue.None,
      onboarded: false
    };
    return state;
  }

  /** Everything shown in the forecast pager, in order: location first. */
  static places(state: WeatherState): CityState[] {
    const location = state.location;
    return location === undefined ? state.cities : [location].concat(state.cities);
  }

  /** Whether the "approximate / no location" banner shows above the forecast. */
  static locationBannerShown(state: WeatherState): boolean {
    const approximate = state.location?.approximate ?? false;
    return approximate || (state.location === undefined && state.locationIssue !== LocationIssue.None);
  }

  static place(state: WeatherState, key: string): CityState | undefined {
    if (state.location !== undefined && state.location.key === key) {
      return state.location;
    }
    return state.cities.find((place: CityState) => place.key === key);
  }

  static isCurrentLocation(place: CityState): boolean {
    return place.key === CURRENT_LOCATION_KEY;
  }

  static isStale(place: CityState, maxAgeMs: number, now?: number): boolean {
    return place.updatedAt === undefined || (now ?? Date.now()) - place.updatedAt > maxAgeMs;
  }

  static newPlace(key: string, city: City, approximate: boolean): CityState {
    const place: CityState = {
      key: key,
      city: city,
      status: Status.Initial,
      issue: ForecastIssue.None,
      approximate: approximate
    };
    return place;
  }

  /** A copy of [place]. A new request clears the previous failure reason unless one is given. */
  static copyPlace(place: CityState, city?: City, status?: Status, issue?: ForecastIssue, updatedAt?: number,
    normals?: ClimateNormals): CityState {
    const copy: CityState = {
      key: place.key,
      city: city ?? place.city,
      status: status ?? place.status,
      issue: issue ?? ForecastIssue.None,
      updatedAt: updatedAt ?? place.updatedAt,
      approximate: place.approximate,
      normals: normals ?? place.normals
    };
    return copy;
  }

  static copyWeather(state: WeatherState, location: CityState | undefined, cities: CityState[], status?: Status,
    locationIssue?: LocationIssue, onboarded?: boolean): WeatherState {
    const copy: WeatherState = {
      location: location,
      cities: cities,
      status: status ?? state.status,
      locationIssue: locationIssue ?? state.locationIssue,
      onboarded: onboarded ?? state.onboarded
    };
    return copy;
  }
}
