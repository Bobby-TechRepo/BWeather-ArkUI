import { Storage } from '../common/Storage';
import { Units } from '../common/Units';
import { AlertLog, AlertPrefs, AlertPrefsUtil } from '../model/Alerts';
import { City } from '../model/Models';
import { TripReminder } from '../model/TripReminders';

/**
 * What the background worker needs, written by the app whenever it changes
 * (lib/services/alert_store.dart). Kept in its own small files so the worker
 * never reads the app's larger state files.
 */
export interface AlertTarget {
  city: City;
  units: Units;
  /** "fr", or "" to follow the device. */
  language: string;
  prefs: AlertPrefs;
  /** Pre-trip notifications still to come. */
  reminders: TripReminder[];
  /** Whether a home-screen card is placed and should be refreshed too. */
  card: boolean;
}

interface SentReminders {
  sent: string[];
}

export class AlertStore {
  private static readonly TARGET: string = 'alert_target';
  private static readonly LOG: string = 'alert_log';
  private static readonly SENT: string = 'trip_reminders_sent';

  /** Whether the worker has anything to do for [target]. */
  static needsRefresh(target: AlertTarget): boolean {
    return AlertPrefsUtil.anyEnabled(target.prefs) || target.reminders.length > 0 || target.card;
  }

  static readTarget(): AlertTarget | undefined {
    const text = Storage.read(AlertStore.TARGET);
    if (text === undefined || text.length === 0) {
      return undefined;
    }
    try {
      const target = JSON.parse(text) as AlertTarget;
      if (target.city === undefined || typeof target.city.latitude !== 'number' || target.units === undefined) {
        return undefined;
      }
      target.prefs = AlertPrefsUtil.read(target.prefs);
      target.reminders = Array.isArray(target.reminders) ? target.reminders : [];
      target.language = typeof target.language === 'string' ? target.language : '';
      target.card = target.card === true;
      return target;
    } catch (error) {
      return undefined;
    }
  }

  /** Writes [target] ("" clears it). Returns the text written, so callers can skip identical writes. */
  static writeTarget(target: AlertTarget | undefined): string {
    const text = target === undefined ? '' : JSON.stringify(target);
    Storage.write(AlertStore.TARGET, text);
    return text;
  }

  static readLog(): AlertLog {
    const text = Storage.read(AlertStore.LOG);
    const empty: AlertLog = {};
    if (text === undefined || text.length === 0) {
      return empty;
    }
    try {
      const saved = JSON.parse(text) as AlertLog;
      const log: AlertLog = {
        lastBriefDay: typeof saved.lastBriefDay === 'string' ? saved.lastBriefDay : undefined,
        lastRainAlertAt: typeof saved.lastRainAlertAt === 'number' ? saved.lastRainAlertAt : undefined,
        lastSevereAlertAt: typeof saved.lastSevereAlertAt === 'number' ? saved.lastSevereAlertAt : undefined
      };
      return log;
    } catch (error) {
      return empty;
    }
  }

  static writeLog(log: AlertLog): void {
    Storage.write(AlertStore.LOG, JSON.stringify(log));
  }

  /** Ids of trip reminders already shown. */
  static readSentReminders(): string[] {
    const text = Storage.read(AlertStore.SENT);
    if (text === undefined || text.length === 0) {
      return [];
    }
    try {
      const saved = JSON.parse(text) as SentReminders;
      return Array.isArray(saved.sent) ? saved.sent.map((id: string) => `${id}`) : [];
    } catch (error) {
      return [];
    }
  }

  static writeSentReminders(ids: string[]): void {
    const saved: SentReminders = { sent: ids };
    Storage.write(AlertStore.SENT, ids.length === 0 ? '' : JSON.stringify(saved));
  }
}
