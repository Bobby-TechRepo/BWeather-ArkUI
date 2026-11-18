import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { WallTime } from '../common/WallTime';
import { WeatherIcons } from '../common/Weather';
import { ForecastUtil } from './ForecastUtil';
import { City, Forecast } from './Models';

/**
 * Everything the home-screen card shows, as plain values
 * (WeatherWidgetData in lib/services/home_widget_service.dart). The keys are
 * the card's LocalStorage properties (widget/pages/WeatherCard.ets).
 */
export interface CardData {
  /** False until the app has saved a forecast; the card then asks to open the app. */
  ready: boolean;
  place: string;
  temperature: string;
  condition: string;
  /** One of the keys WeatherCard maps to artwork (see CardDataUtil.iconKey). */
  icon: string;
  range: string;
  updated: string;
}

export class CardDataUtil {
  static empty(): CardData {
    const data: CardData = { ready: false, place: '', temperature: '--°', condition: '', icon: 'partly_day', range: '', updated: '' };
    return data;
  }

  /** Card text for [city]'s forecast, fetched at [updatedAt] (device clock, ms). */
  static from(city: City, forecast: Forecast, updatedAt: number): CardData {
    const current = forecast.current;
    const today = ForecastUtil.today(forecast, updatedAt);
    const unit = current.temperature.unit;
    const data: CardData = {
      ready: true,
      place: city.name,
      temperature: `${Format.temp(current.temperature.value)}°`,
      condition: S.get(WeatherIcons.describe(current.weatherCode)),
      icon: CardDataUtil.iconKey(current.weatherCode, !current.isDay),
      range: today === undefined ? '' : S.get($r('app.string.widgetRange'),
        `${Format.temp(today.temperatureMax.value)}${unit}`, `${Format.temp(today.temperatureMin.value)}${unit}`),
      updated: S.get($r('app.string.widgetUpdated'), Format.clock(WallTime.deviceNow(updatedAt)))
    };
    return data;
  }

  static same(a: CardData, b: CardData): boolean {
    return a.ready === b.ready && a.place === b.place && a.temperature === b.temperature && a.condition === b.condition &&
      a.icon === b.icon && a.range === b.range && a.updated === b.updated;
  }

  /** A small set of artwork keys: cards can only use resources named in their own code. */
  static iconKey(code: number, night: boolean): string {
    if (code <= 1) {
      return night ? 'clear_night' : 'clear_day';
    }
    if (code === 2) {
      return night ? 'partly_night' : 'partly_day';
    }
    if (code === 3) {
      return 'overcast';
    }
    if (code === 45 || code === 48) {
      return night ? 'fog_night' : 'fog_day';
    }
    if (code >= 51 && code <= 57) {
      return 'drizzle';
    }
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'rain';
    }
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) {
      return 'snow';
    }
    if (code >= 95 && code <= 99) {
      return night ? 'thunder_night' : 'thunder_day';
    }
    return 'overcast';
  }
}
