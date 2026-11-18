import { hilog } from '@kit.PerformanceAnalysisKit';
import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { UnitConverter, Units } from '../common/Units';
import { WallTime } from '../common/WallTime';
import { WeatherIcons } from '../common/Weather';
import { AlertEvaluator, AlertPrefsUtil } from '../model/Alerts';
import { CardDataUtil } from '../model/CardData';
import { Forecast } from '../model/Models';
import { TripReminder, TripReminders } from '../model/TripReminders';
import { AlertStore, AlertTarget } from './AlertStore';
import { CardService } from './CardService';
import { Notifier } from './Notifier';
import { ForecastRepository } from './WeatherClient';

/**
 * One background check (lib/services/background.dart): posts trip reminders
 * that are due, then fetches a fresh forecast for the saved place, redraws the
 * home-screen card and posts any weather alerts. Failures are logged and
 * simply wait for the next run.
 */
export async function runBackgroundRefresh(now?: number): Promise<void> {
  const time = now ?? Date.now();
  try {
    const target = AlertStore.readTarget();
    if (target === undefined || !AlertStore.needsRefresh(target)) {
      return;
    }
    Format.appLanguage = target.language;
    const repository = new ForecastRepository();
    const notify = await Notifier.isEnabled();

    if (notify) {
      await sendTripReminders(target, repository, time);
    }
    const alerts = notify && AlertPrefsUtil.anyEnabled(target.prefs);
    if (!alerts && !target.card) {
      return;
    }

    const forecast = await fetchForecast(target, repository);
    if (forecast === undefined) {
      return;
    }
    if (target.card) {
      await CardService.push(CardDataUtil.from(target.city, forecast, time));
    }
    if (alerts) {
      const result = AlertEvaluator.evaluate(forecast, target.prefs, AlertStore.readLog(), target.city.name, time);
      for (const alert of result.alerts) {
        await Notifier.showAlert(alert);
      }
      AlertStore.writeLog(result.log);
    }
  } catch (error) {
    hilog.warn(0x0000, 'Background', 'Background refresh failed: %{public}s', JSON.stringify(error));
  }
}

/**
 * Fetches a fresh forecast for the card (the card's own periodic update).
 * Without a saved place it redraws what was saved last.
 */
export async function refreshCard(now?: number): Promise<void> {
  try {
    const target = AlertStore.readTarget();
    if (target === undefined) {
      await CardService.push(CardService.saved(), true);
      return;
    }
    Format.appLanguage = target.language;
    const forecast = await fetchForecast(target, new ForecastRepository());
    if (forecast !== undefined) {
      await CardService.push(CardDataUtil.from(target.city, forecast, now ?? Date.now()));
    }
  } catch (error) {
    hilog.warn(0x0000, 'Background', 'Card refresh failed: %{public}s', JSON.stringify(error));
  }
}

/** The saved place's forecast in the user's units (fetched in metric, like the app). */
async function fetchForecast(target: AlertTarget, repository: ForecastRepository): Promise<Forecast | undefined> {
  const fetched = await repository.getWeather(target.city, UnitConverter.METRIC, false);
  return UnitConverter.city(fetched, target.units).forecast;
}

/** Posts the pre-trip reminders that are due and not sent yet; a failed forecast still sends one. */
async function sendTripReminders(target: AlertTarget, repository: ForecastRepository, now: number): Promise<void> {
  if (target.reminders.length === 0) {
    AlertStore.writeSentReminders([]);
    return;
  }
  const sent = AlertStore.readSentReminders();
  for (const reminder of target.reminders) {
    if (sent.includes(reminder.id) || !TripReminders.isDue(reminder, now)) {
      continue;
    }
    const body = await reminderBody(reminder, repository, target.units);
    await Notifier.showTripReminder(reminder.id, S.get($r('app.string.tripReminderTitle'), reminder.city.name), body);
    sent.push(reminder.id);
  }
  // Forget reminders for trips that were deleted, moved or turned off.
  const current = target.reminders.map((reminder: TripReminder) => reminder.id);
  AlertStore.writeSentReminders(sent.filter((id: string) => current.includes(id)));
}

async function reminderBody(reminder: TripReminder, repository: ForecastRepository, units: Units): Promise<string> {
  try {
    const date = WallTime.isoDate(reminder.departure);
    const days = await repository.dailyForecast(reminder.city, date, date);
    if (days.length > 0) {
      const day = UnitConverter.daily(days[0], units);
      return S.get($r('app.string.briefBody'),
        S.get(WeatherIcons.describe(day.weatherCode)),
        `${Format.temp(day.temperatureMin.value)}${day.temperatureMin.unit}`,
        `${Format.temp(day.temperatureMax.value)}${day.temperatureMax.unit}`,
        `${Math.round(day.precipitationProbabilityMax?.value ?? 0)}`);
    }
  } catch (error) {
    hilog.warn(0x0000, 'Background', 'Trip reminder forecast failed: %{public}s', JSON.stringify(error));
  }
  return S.get($r('app.string.tripReminderBodyFallback'));
}
