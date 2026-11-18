import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { UnitConverter } from '../common/Units';
import { WallTime } from '../common/WallTime';
import { AirQualityUtil, ForecastUtil } from './ForecastUtil';
import { Forecast, Hourly, UvLevel, Value } from './Models';

export enum TipKind {
  Umbrella = 'umbrella',
  Clothes = 'clothes',
  Sunscreen = 'sunscreen',
  Hydrate = 'hydrate',
  Laundry = 'laundry',
  Outdoor = 'outdoor',
  AirQuality = 'airQuality',
  Mosquitoes = 'mosquitoes',
  Driving = 'driving'
}

export interface Tip {
  kind: TipKind;
  text: string;
}

/**
 * Practical advice for today from the forecast: what to wear, umbrella,
 * laundry, best time outdoors... (lib/services/tips.dart).
 */
export class TipsEngine {
  static readonly MAX_TIPS: number = 5;
  private static readonly FOG_CODES: number[] = [45, 48];
  private static readonly HEAVY_RAIN_CODES: number[] = [65, 67, 82, 95, 96, 99];

  static tips(forecast: Forecast, now?: number): Tip[] {
    const tips: Tip[] = [];
    const add = (kind: TipKind, text: string): void => {
      const tip: Tip = { kind: kind, text: text };
      tips.push(tip);
    };
    const celsius = (value: Value): number => UnitConverter.toCelsius(value.value, value.unit);
    const today = ForecastUtil.today(forecast, now);
    const next12 = ForecastUtil.upcomingHours(forecast, 12, now);
    const localNow = ForecastUtil.localNow(forecast, now);
    const air = forecast.airQuality;

    // Driving hazards first: they matter most.
    for (const hour of next12.slice(0, 6)) {
      if (TipsEngine.FOG_CODES.includes(hour.weatherCode)) {
        add(TipKind.Driving, S.get($r('app.string.tipDriveFog'), Format.clock(hour.time)));
        break;
      }
      if (TipsEngine.HEAVY_RAIN_CODES.includes(hour.weatherCode)) {
        add(TipKind.Driving, S.get($r('app.string.tipDriveRain'), Format.clock(hour.time)));
        break;
      }
    }

    // Umbrella: rain likely today; say when.
    const rainChance = today?.precipitationProbabilityMax?.value ?? 0;
    if (rainChance >= 50 && next12.length > 0) {
      let wettest = next12[0];
      for (const hour of next12) {
        if (hour.precipitationProbability.value > wettest.precipitationProbability.value) {
          wettest = hour;
        }
      }
      if (wettest.precipitationProbability.value >= 40) {
        add(TipKind.Umbrella, S.get($r('app.string.tipUmbrella'), `${wettest.precipitationProbability.value}`,
          Format.clock(wettest.time)));
      }
    }

    // What to wear, from today's highest feels-like temperature.
    const feelsLike = today?.apparentTemperatureMax;
    if (feelsLike !== undefined) {
      const c = celsius(feelsLike);
      let text: Resource = $r('app.string.tipClothesCold');
      if (c >= 32) {
        text = $r('app.string.tipClothesHot');
      } else if (c >= 24) {
        text = $r('app.string.tipClothesWarm');
      } else if (c >= 15) {
        text = $r('app.string.tipClothesMild');
      } else if (c >= 5) {
        text = $r('app.string.tipClothesCool');
      }
      add(TipKind.Clothes, S.get(text));
      if (c >= 35) {
        add(TipKind.Hydrate, S.get($r('app.string.tipHydrate'), `${Format.temp(feelsLike.value)}${feelsLike.unit}`));
      }
    }

    // Sun protection.
    const uvLevel = air === undefined ? undefined : AirQualityUtil.uvLevel(air);
    if (uvLevel !== undefined && uvLevel >= UvLevel.High) {
      let label: Resource = $r('app.string.uvExtreme');
      if (uvLevel === UvLevel.High) {
        label = $r('app.string.uvHigh');
      } else if (uvLevel === UvLevel.VeryHigh) {
        label = $r('app.string.uvVeryHigh');
      }
      add(TipKind.Sunscreen, S.get($r('app.string.tipSunscreen'), S.get(label).toLowerCase()));
    }

    // Air quality.
    if (air?.usAqi !== undefined && air.usAqi > 100) {
      add(TipKind.AirQuality, S.get($r('app.string.tipAirQuality')));
    }

    // Best time outdoors: dry, daylight, closest to a comfortable 22 °C.
    const daylight = next12.filter((hour: Hourly) => {
      const h = WallTime.hour(hour.time);
      return hour.isDay ?? (h >= 7 && h < 19);
    });
    const dryDaylight = daylight.filter((hour: Hourly) => hour.precipitationProbability.value < 30);
    if (dryDaylight.length > 0) {
      const discomfort = (hour: Hourly): number => Math.abs(celsius(hour.apparentTemperature) - 22);
      let best = dryDaylight[0];
      for (const hour of dryDaylight) {
        if (discomfort(hour) < discomfort(best)) {
          best = hour;
        }
      }
      if (WallTime.hour(best.time) !== WallTime.hour(localNow)) {
        add(TipKind.Outdoor, S.get($r('app.string.tipBestOutdoorTime'), Format.clock(best.time)));
      }
    }

    // Laundry: the next daylight hours must be dry and not too humid.
    if (daylight.length >= 4) {
      const nextHours = daylight.slice(0, 6);
      const dry = nextHours.every((hour: Hourly) => hour.precipitationProbability.value < 20);
      let humidity = 0;
      for (const hour of nextHours) {
        humidity += hour.relativeHumidity.value;
      }
      humidity /= nextHours.length;
      if (dry && humidity < 75) {
        add(TipKind.Laundry, S.get($r('app.string.tipLaundryGood')));
      } else if (nextHours.some((hour: Hourly) => hour.precipitationProbability.value >= 50)) {
        add(TipKind.Laundry, S.get($r('app.string.tipLaundryBad')));
      }
    }

    // Mosquitoes: a warm, humid evening ahead.
    const evening = next12.filter((hour: Hourly) => WallTime.hour(hour.time) >= 18 && WallTime.hour(hour.time) <= 22);
    if (evening.length > 0 &&
      evening.every((hour: Hourly) => celsius(hour.temperature) >= 24 && hour.relativeHumidity.value >= 70)) {
      add(TipKind.Mosquitoes, S.get($r('app.string.tipMosquitoes')));
    }

    return tips.slice(0, TipsEngine.MAX_TIPS);
  }

  static icon(kind: TipKind): Resource {
    switch (kind) {
      case TipKind.Umbrella:
        return $r('app.media.ic_umbrella');
      case TipKind.Clothes:
        return $r('app.media.ic_clothes');
      case TipKind.Sunscreen:
        return $r('app.media.ic_sunny');
      case TipKind.Hydrate:
        return $r('app.media.ic_drink');
      case TipKind.Laundry:
        return $r('app.media.ic_laundry');
      case TipKind.Outdoor:
        return $r('app.media.ic_walk');
      case TipKind.AirQuality:
        return $r('app.media.ic_mask');
      case TipKind.Mosquitoes:
        return $r('app.media.ic_bug');
      default:
        return $r('app.media.ic_car');
    }
  }
}
