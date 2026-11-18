import { workScheduler } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext } from '../common/AppContext';
import { AlertStore, AlertTarget } from '../data/AlertStore';
import { CardService } from '../data/CardService';
import { City } from '../model/Models';
import { TripReminders } from '../model/TripReminders';
import { SettingsState, States, WeatherState } from './StateTypes';
import { Trip } from '../model/Trips';

/**
 * Keeps the background worker in sync with the app (lib/services/alert_scheduler.dart):
 * writes what it needs (place, units, language, alert choices, trip reminders)
 * and registers the periodic check while there is something to do.
 */
export class AlertScheduler {
  static readonly WORK_ID: number = 1;
  /** HarmonyOS runs periodic work at most every 2 hours (less often for rarely used apps). */
  static readonly CYCLE_MS: number = 2 * 60 * 60 * 1000;
  static readonly WORKER: string = 'AlertWorker';

  private lastWritten: string | undefined = undefined;
  private registered: boolean | undefined = undefined;

  sync(settings: SettingsState, weather: WeatherState, trips: Trip[]): void {
    const places = States.places(weather);
    // Alerts and the card follow the user's location, or the first saved city.
    const place = places.length === 0 ? undefined : places[0].city;
    // Written whenever there is a place, so the card can refresh itself even with alerts off.
    let target: AlertTarget | undefined = undefined;
    if (place !== undefined) {
      const value: AlertTarget = {
        city: AlertScheduler.withoutForecast(place),
        units: States.units(settings),
        language: settings.language,
        prefs: settings.alerts,
        reminders: TripReminders.fromTrips(trips),
        card: CardService.hasCards()
      };
      target = value;
    }

    const text = target === undefined ? '' : JSON.stringify(target);
    if (text !== this.lastWritten) {
      this.lastWritten = AlertStore.writeTarget(target);
    }
    this.schedule(target !== undefined && AlertStore.needsRefresh(target));
  }

  private schedule(enabled: boolean): void {
    if (enabled === this.registered) {
      return;
    }
    this.registered = enabled;
    if (!enabled) {
      try {
        workScheduler.stopWork(AlertScheduler.workInfo(false), true);
      } catch (error) {
        // Nothing was scheduled.
      }
      return;
    }
    AlertScheduler.ensureScheduled();
  }

  /**
   * Registers the periodic check unless it already exists, so opening the app
   * doesn't restart the 2-hour wait. Also used when a card is placed.
   */
  static ensureScheduled(): void {
    workScheduler.obtainAllWorks().then((works: workScheduler.WorkInfo[]) => {
      if (!works.some((work: workScheduler.WorkInfo) => work.workId === AlertScheduler.WORK_ID)) {
        AlertScheduler.start();
      }
    }).catch((error: BusinessError) => {
      AlertScheduler.start();
    });
  }

  private static start(): void {
    try {
      workScheduler.startWork(AlertScheduler.workInfo(true));
    } catch (error) {
      // Some devices refuse tasks that survive a restart; the app re-registers on launch anyway.
      try {
        workScheduler.startWork(AlertScheduler.workInfo(false));
      } catch (second) {
        hilog.warn(0x0000, 'Alerts', 'Background work not scheduled: %{public}s', JSON.stringify(second));
      }
    }
  }

  private static workInfo(persisted: boolean): workScheduler.WorkInfo {
    const info: workScheduler.WorkInfo = {
      workId: AlertScheduler.WORK_ID,
      bundleName: AppContext.base?.applicationInfo.name ?? '',
      abilityName: AlertScheduler.WORKER,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      isRepeat: true,
      repeatCycleTime: AlertScheduler.CYCLE_MS,
      isPersisted: persisted
    };
    return info;
  }

  private static withoutForecast(city: City): City {
    const copy: City = {
      name: city.name,
      country: city.country,
      region: city.region,
      timezone: city.timezone,
      elevation: city.elevation,
      latitude: city.latitude,
      longitude: city.longitude
    };
    return copy;
  }
}
