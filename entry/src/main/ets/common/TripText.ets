import { S } from './AppContext';
import { Format } from './Format';
import { WeatherIcons } from './Weather';
import { WallTime } from './WallTime';
import { DayKind, PackingItem, Trip, TripDay, TripTiming, TripUtil } from '../model/Trips';

/** User-facing text for trips (lib/states/trips/trip_text.dart). */
export class TripText {
  static packingItem(item: PackingItem): string {
    switch (item) {
      case PackingItem.Umbrella:
        return S.get($r('app.string.packUmbrella'));
      case PackingItem.RainJacket:
        return S.get($r('app.string.packRainJacket'));
      case PackingItem.Sunscreen:
        return S.get($r('app.string.packSunscreen'));
      case PackingItem.Sunglasses:
        return S.get($r('app.string.packSunglasses'));
      case PackingItem.Hat:
        return S.get($r('app.string.packHat'));
      case PackingItem.LightClothes:
        return S.get($r('app.string.packLightClothes'));
      case PackingItem.WaterBottle:
        return S.get($r('app.string.packWaterBottle'));
      case PackingItem.WarmLayer:
        return S.get($r('app.string.packWarmLayer'));
      case PackingItem.Coat:
        return S.get($r('app.string.packCoat'));
      case PackingItem.Gloves:
        return S.get($r('app.string.packGloves'));
      case PackingItem.Windbreaker:
        return S.get($r('app.string.packWindbreaker'));
      default:
        return S.get($r('app.string.packInsectRepellent'));
    }
  }

  /** "Starts in 12 days" / "Happening now" / "Ended". */
  static timing(trip: Trip): string {
    switch (TripUtil.timing(trip)) {
      case TripTiming.Upcoming:
        return S.count(TripUtil.daysUntil(trip), $r('app.string.tripStartsIn_zero'), $r('app.string.tripStartsIn_one'),
          $r('app.string.tripStartsIn_other'));
      case TripTiming.Ongoing:
        return S.get($r('app.string.tripOngoing'));
      default:
        return S.get($r('app.string.tripEnded'));
    }
  }

  static dayCount(days: number): string {
    return S.count(days, $r('app.string.tripDayCount_zero'), $r('app.string.tripDayCount_one'),
      $r('app.string.tripDayCount_other'));
  }

  static rainyDays(days: number): string {
    return S.count(days, $r('app.string.tripRainyDays_zero'), $r('app.string.tripRainyDays_one'),
      $r('app.string.tripRainyDays_other'));
  }

  /** "Dec 3 – 8" style range. */
  static dateRange(start: number, end: number): string {
    if (WallTime.sameDay(start, end)) {
      return Format.shortDate(start);
    }
    return `${Format.shortDate(start)} – ${Format.shortDate(end)}`;
  }

  /** "Mar 3 – 12 · 10 days" */
  static datesAndLength(trip: Trip): string {
    return `${TripText.dateRange(TripUtil.start(trip), TripUtil.end(trip))} · ${TripText.dayCount(TripUtil.dayCount(trip))}`;
  }

  /** Plain-text summary of a trip's weather, for the share sheet. */
  static share(trip: Trip, days: TripDay[]): string {
    const lines: string[] = [`${trip.name} (${TripText.dateRange(TripUtil.start(trip), TripUtil.end(trip))})`, ''];
    for (const day of days) {
      const date = Format.dayDate(day.date);
      const place = day.stop.city.name;
      const daily = day.daily;
      if (day.kind === DayKind.Forecast && daily !== undefined) {
        lines.push(S.get($r('app.string.shareForecastDay'), date, place, S.get(WeatherIcons.describe(daily.weatherCode)),
          `${Format.temp(daily.temperatureMin.value)}°`, `${Format.temp(daily.temperatureMax.value)}°`,
          `${Math.round(daily.precipitationProbabilityMax?.value ?? 0)}`));
      } else if (day.kind === DayKind.Typical && day.high !== undefined && day.low !== undefined) {
        lines.push(S.get($r('app.string.shareTypicalDay'), date, place, `${Format.temp(day.low)}°`, `${Format.temp(day.high)}°`));
      } else {
        lines.push(`${date} · ${place}`);
      }
    }
    const packing = TripUtil.packingFor(days);
    if (packing.length > 0) {
      lines.push('');
      lines.push(`${S.get($r('app.string.packingList'))}: ${packing.map((item: PackingItem) => TripText.packingItem(item)).join(', ')}`);
    }
    lines.push('');
    lines.push(S.get($r('app.string.sharedFromApp')));
    return lines.join('\n');
  }
}
