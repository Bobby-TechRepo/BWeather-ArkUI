import { i18n } from '@kit.LocalizationKit';
import { S } from './AppContext';
import { WallTime } from './WallTime';

/** Languages with translations (keep in sync with resources/<lang>/element/string.json). */
export const SUPPORTED_LANGUAGES: string[] = ['en', 'fr', 'es', 'zh', 'ja', 'ha', 'yo', 'ig'];

/** Language names are shown in their own language on purpose. */
export const LANGUAGE_NAMES: Map<string, string> = new Map<string, string>();
LANGUAGE_NAMES.set('en', 'English');
LANGUAGE_NAMES.set('fr', 'Français');
LANGUAGE_NAMES.set('es', 'Español');
LANGUAGE_NAMES.set('zh', '中文（简体）');
LANGUAGE_NAMES.set('ja', '日本語');
LANGUAGE_NAMES.set('ha', 'Hausa');
LANGUAGE_NAMES.set('yo', 'Yorùbá');
LANGUAGE_NAMES.set('ig', 'Igbo');

/**
 * Languages the app is translated into but the date formatter may have no
 * names for. Their dates use English names (common in Nigeria), as in the Flutter app.
 */
const WITHOUT_DATE_NAMES: string[] = ['ha', 'yo', 'ig'];

/** Date, time and number formatting in the app's language. All times are wall times. */
export class Format {
  /** The app language code ("fr"), or "" to follow the device. Set by the settings store. */
  static appLanguage: string = '';

  private static cache: Map<string, Intl.DateTimeFormat> = new Map<string, Intl.DateTimeFormat>();

  /** The language actually in use: the app's choice, else the device's. */
  static language(): string {
    if (Format.appLanguage.length > 0) {
      return Format.appLanguage;
    }
    try {
      const system = i18n.System.getSystemLanguage();
      const code = system.split('-')[0];
      return SUPPORTED_LANGUAGES.includes(code) ? code : 'en';
    } catch (error) {
      return 'en';
    }
  }

  static dateLocale(): string {
    const language = Format.language();
    if (WITHOUT_DATE_NAMES.includes(language)) {
      return 'en';
    }
    return language === 'zh' ? 'zh-Hans' : language;
  }

  private static formatter(key: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
    const locale = Format.dateLocale();
    const cacheKey = `${locale}|${key}`;
    let formatter = Format.cache.get(cacheKey);
    if (formatter === undefined) {
      formatter = new Intl.DateTimeFormat(locale, options);
      Format.cache.set(cacheKey, formatter);
    }
    return formatter;
  }

  /** "Thursday, November 12" / "jeudi 12 novembre" */
  static date(time: number): string {
    const options: Intl.DateTimeFormatOptions = { weekday: 'long', month: 'long', day: 'numeric', timeZone: 'UTC' };
    return Format.formatter('date', options).format(new Date(time));
  }

  /** "Thu" / "jeu." */
  static shortDay(time: number): string {
    const options: Intl.DateTimeFormatOptions = { weekday: 'short', timeZone: 'UTC' };
    return Format.formatter('shortDay', options).format(new Date(time));
  }

  /** "Dec 3" / "3 déc." */
  static shortDate(time: number): string {
    const options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', timeZone: 'UTC' };
    return Format.formatter('shortDate', options).format(new Date(time));
  }

  /** "Thu, Dec 3" / "jeu. 3 déc." */
  static dayDate(time: number): string {
    const options: Intl.DateTimeFormatOptions = { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' };
    return Format.formatter('dayDate', options).format(new Date(time));
  }

  /** "Dec 3, 2026" for documents. */
  static mediumDate(time: number): string {
    const options: Intl.DateTimeFormatOptions = { year: 'numeric', month: 'short', day: 'numeric', timeZone: 'UTC' };
    return Format.formatter('mediumDate', options).format(new Date(time));
  }

  /** "3:05 PM" / "15:05" */
  static clock(time: number): string {
    const options: Intl.DateTimeFormatOptions = { hour: 'numeric', minute: '2-digit', timeZone: 'UTC' };
    return Format.formatter('clock', options).format(new Date(time));
  }

  /** "3 PM" / "15 h" */
  static hour(time: number): string {
    const options: Intl.DateTimeFormatOptions = { hour: 'numeric', timeZone: 'UTC' };
    return Format.formatter('hour', options).format(new Date(time));
  }

  /** "UTC+1", "UTC+5:30", "UTC−3:30" */
  static utcOffset(seconds: number): string {
    const sign = seconds < 0 ? '−' : '+';
    const minutes = Math.abs(Math.round(seconds / 60));
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return `UTC${sign}${hours}${rest === 0 ? '' : ':' + WallTime.pad(rest, 2)}`;
  }

  /** "just now", "5 min ago", "2 h ago", "3 days ago" for a device time in ms. */
  static age(time: number, now?: number): string {
    const minutes = Math.floor(((now ?? Date.now()) - time) / WallTime.MINUTE);
    if (minutes < 1) {
      return S.get($r('app.string.ageJustNow'));
    }
    if (minutes < 60) {
      return S.get($r('app.string.ageMinutes'), `${minutes}`);
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
      return S.get($r('app.string.ageHours'), `${hours}`);
    }
    return S.count(Math.floor(hours / 24), $r('app.string.ageDays_zero'), $r('app.string.ageDays_one'), $r('app.string.ageDays_other'));
  }

  /** Temperatures are shown as whole degrees, rounded (20.1° is 20°). */
  static temp(value: number): string {
    return `${Math.round(value)}`;
  }

  /** Index 0..15 of the 16-point compass for a wind direction in degrees. */
  static compassIndex(degrees: number): number {
    const normalized = ((degrees % 360) + 360) % 360;
    return Math.round(normalized / 22.5) % 16;
  }

  /** Localized 16-point compass name ("SW", "SO", ...). */
  static compassPoint(degrees: number): string {
    const points = S.get($r('app.string.compassPoints')).split(',');
    const index = Format.compassIndex(degrees);
    return index < points.length ? points[index] : '';
  }
}
