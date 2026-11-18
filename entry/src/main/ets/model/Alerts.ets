import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { UnitConverter } from '../common/Units';
import { WallTime } from '../common/WallTime';
import { WeatherIcons } from '../common/Weather';
import { ForecastUtil } from './ForecastUtil';
import { Forecast, Hourly } from './Models';

/** Which notifications the user opted into. Saved with the settings (lib/services/alerts.dart). */
export interface AlertPrefs {
  morningBrief: boolean;
  rain: boolean;
  severe: boolean;
  /** Local hour (0–23) from which the morning briefing is sent. */
  briefHour: number;
}

/** What has already been sent, so the background checks don't repeat themselves. */
export interface AlertLog {
  /** "YYYY-MM-DD" (place-local) of the last morning briefing. */
  lastBriefDay?: string;
  /** Device clock, ms. */
  lastRainAlertAt?: number;
  lastSevereAlertAt?: number;
}

export enum AlertKind {
  Brief = 0,
  Rain = 1,
  Severe = 2
}

export interface PendingAlert {
  kind: AlertKind;
  title: string;
  body: string;
}

export interface AlertResult {
  alerts: PendingAlert[];
  log: AlertLog;
}

export class AlertPrefsUtil {
  static defaults(): AlertPrefs {
    const prefs: AlertPrefs = { morningBrief: false, rain: false, severe: false, briefHour: 7 };
    return prefs;
  }

  static anyEnabled(prefs: AlertPrefs): boolean {
    return prefs.morningBrief || prefs.rain || prefs.severe;
  }

  /** Checks a saved value field by field. */
  static read(value: Object | undefined): AlertPrefs {
    const prefs = AlertPrefsUtil.defaults();
    if (value === undefined || typeof value !== 'object') {
      return prefs;
    }
    const saved = value as AlertPrefs;
    const hour = Number(saved.briefHour);
    prefs.morningBrief = saved.morningBrief === true;
    prefs.rain = saved.rain === true;
    prefs.severe = saved.severe === true;
    prefs.briefHour = Number.isFinite(hour) ? Math.max(0, Math.min(23, Math.round(hour))) : 7;
    return prefs;
  }

  static same(a: AlertPrefs, b: AlertPrefs): boolean {
    return a.morningBrief === b.morningBrief && a.rain === b.rain && a.severe === b.severe && a.briefHour === b.briefHour;
  }
}

/** Decides which notifications to send. No side effects, so it can be unit tested. */
export class AlertEvaluator {
  /** Probability (%) from which an upcoming hour counts as "rain likely". */
  static readonly RAIN_THRESHOLD: number = 60;
  /** If the current hour is already this likely to rain, don't announce it. */
  static readonly ALREADY_RAINING_THRESHOLD: number = 50;
  static readonly RAIN_COOLDOWN: number = 3 * WallTime.HOUR;
  static readonly SEVERE_COOLDOWN: number = 6 * WallTime.HOUR;
  /** Gusts (km/h) and feels-like temperature (°C) that count as severe. */
  static readonly SEVERE_GUST_KMH: number = 75;
  static readonly EXTREME_HEAT_C: number = 41;
  /**
   * The briefing can go out up to this many hours after [AlertPrefs.briefHour].
   * HarmonyOS runs background work at most every 2 hours (later for apps used
   * less often), so the window is wider than the Android app's 3 hours.
   */
  static readonly BRIEF_WINDOW_HOURS: number = 4;
  static readonly THUNDER_CODES: number[] = [95, 96, 99];

  static evaluate(forecast: Forecast, prefs: AlertPrefs, log: AlertLog, place: string, now: number): AlertResult {
    const alerts: PendingAlert[] = [];
    const updated: AlertLog = {
      lastBriefDay: log.lastBriefDay,
      lastRainAlertAt: log.lastRainAlertAt,
      lastSevereAlertAt: log.lastSevereAlertAt
    };
    const localNow = ForecastUtil.localNow(forecast, now);
    const today = WallTime.isoDate(localNow);
    const hourNow = WallTime.hour(localNow);

    // Morning briefing.
    if (prefs.morningBrief && log.lastBriefDay !== today && hourNow >= prefs.briefHour &&
      hourNow < prefs.briefHour + AlertEvaluator.BRIEF_WINDOW_HOURS) {
      const day = ForecastUtil.today(forecast, now);
      if (day !== undefined) {
        const unit = day.temperatureMax.unit;
        alerts.push(AlertEvaluator.alert(AlertKind.Brief,
          S.get($r('app.string.briefTitle'), place),
          S.get($r('app.string.briefBody'),
            S.get(WeatherIcons.describe(day.weatherCode)),
            `${Format.temp(day.temperatureMin.value)}${unit}`,
            `${Format.temp(day.temperatureMax.value)}${unit}`,
            `${Math.round(day.precipitationProbabilityMax?.value ?? 0)}`)));
        updated.lastBriefDay = today;
      }
    }

    const upcoming = ForecastUtil.upcomingHours(forecast, 4, now);

    // Rain soon: likely within the next 2 hours, and not already raining.
    if (prefs.rain && upcoming.length >= 2 &&
      AlertEvaluator.cooledDown(log.lastRainAlertAt, AlertEvaluator.RAIN_COOLDOWN, now)) {
      const rainingNow = upcoming[0].precipitationProbability.value >= AlertEvaluator.ALREADY_RAINING_THRESHOLD ||
        forecast.current.rain.value > 0;
      if (!rainingNow) {
        const soon = upcoming.slice(1, 3).find((hour: Hourly) =>
          hour.precipitationProbability.value >= AlertEvaluator.RAIN_THRESHOLD);
        if (soon !== undefined) {
          alerts.push(AlertEvaluator.alert(AlertKind.Rain,
            S.get($r('app.string.rainAlertTitle'), place),
            S.get($r('app.string.rainAlertBody'), `${Math.round(soon.precipitationProbability.value)}`,
              Format.clock(soon.time))));
          updated.lastRainAlertAt = now;
        }
      }
    }

    // Severe weather: thunderstorms soon, very strong gusts, extreme heat.
    if (prefs.severe && AlertEvaluator.cooledDown(log.lastSevereAlertAt, AlertEvaluator.SEVERE_COOLDOWN, now)) {
      let severe: PendingAlert | undefined = undefined;
      const storm = upcoming.slice(0, 3).find((hour: Hourly) => AlertEvaluator.THUNDER_CODES.includes(hour.weatherCode));
      if (storm !== undefined) {
        severe = AlertEvaluator.alert(AlertKind.Severe,
          S.get($r('app.string.severeThunderTitle'), place),
          S.get($r('app.string.severeThunderBody'), Format.clock(storm.time)));
      }

      const gusts = forecast.current.windGusts;
      if (severe === undefined && UnitConverter.toKmh(gusts.value, gusts.unit) >= AlertEvaluator.SEVERE_GUST_KMH) {
        severe = AlertEvaluator.alert(AlertKind.Severe,
          S.get($r('app.string.severeWindTitle'), place),
          S.get($r('app.string.severeWindBody'), `${Math.round(gusts.value)} ${gusts.unit}`));
      }

      const feelsLike = ForecastUtil.today(forecast, now)?.apparentTemperatureMax;
      if (severe === undefined && feelsLike !== undefined &&
        UnitConverter.toCelsius(feelsLike.value, feelsLike.unit) >= AlertEvaluator.EXTREME_HEAT_C) {
        severe = AlertEvaluator.alert(AlertKind.Severe,
          S.get($r('app.string.severeHeatTitle'), place),
          S.get($r('app.string.severeHeatBody'), `${Format.temp(feelsLike.value)}${feelsLike.unit}`));
      }

      if (severe !== undefined) {
        alerts.push(severe);
        updated.lastSevereAlertAt = now;
      }
    }

    const result: AlertResult = { alerts: alerts, log: updated };
    return result;
  }

  static alert(kind: AlertKind, title: string, body: string): PendingAlert {
    const alert: PendingAlert = { kind: kind, title: title, body: body };
    return alert;
  }

  static cooledDown(last: number | undefined, cooldown: number, now: number): boolean {
    return last === undefined || now - last >= cooldown;
  }
}
