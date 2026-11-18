/**
 * Helpers for "wall time": a place's local clock reading encoded as UTC
 * milliseconds (see model/Models.ets). Always use the getUTC* methods.
 */
export class WallTime {
  static readonly MINUTE: number = 60 * 1000;
  static readonly HOUR: number = 60 * WallTime.MINUTE;
  static readonly DAY: number = 24 * WallTime.HOUR;

  /** "2026-11-14T15:00" or "2026-11-14" (Open-Meteo, no zone) -> wall time; NaN if unreadable. */
  static parse(text: string): number {
    const match = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?/.exec(text);
    if (match === null) {
      return NaN;
    }
    const hour = match[4] === undefined ? 0 : Number(match[4]);
    const minute = match[5] === undefined ? 0 : Number(match[5]);
    const second = match[6] === undefined ? 0 : Number(match[6]);
    return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), hour, minute, second);
  }

  /** "YYYY-MM-DD" for a wall time (used in API requests). */
  static isoDate(time: number): string {
    const date = new Date(time);
    return `${WallTime.pad(date.getUTCFullYear(), 4)}-${WallTime.pad(date.getUTCMonth() + 1, 2)}-${WallTime.pad(date.getUTCDate(), 2)}`;
  }

  /** The current wall-clock time at a place [utcOffsetSeconds] from UTC, to the minute. */
  static localNow(utcOffsetSeconds: number, now?: number): number {
    const shifted = (now ?? Date.now()) + utcOffsetSeconds * 1000;
    return Math.floor(shifted / WallTime.MINUTE) * WallTime.MINUTE;
  }

  /** Today's date on this device, as a wall-time midnight. */
  static deviceToday(now?: number): number {
    const date = new Date(now ?? Date.now());
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  }

  /** The device's clock reading now, as a wall time (for "Updated 14:05"). */
  static deviceNow(now?: number): number {
    const date = new Date(now ?? Date.now());
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes());
  }

  static startOfDay(time: number): number {
    return Math.floor(time / WallTime.DAY) * WallTime.DAY;
  }

  static startOfHour(time: number): number {
    return Math.floor(time / WallTime.HOUR) * WallTime.HOUR;
  }

  static sameDay(a: number, b: number): boolean {
    return WallTime.startOfDay(a) === WallTime.startOfDay(b);
  }

  static hour(time: number): number {
    return new Date(time).getUTCHours();
  }

  static year(time: number): number {
    return new Date(time).getUTCFullYear();
  }

  /** 1 for 1 January. Leap-year aware, like the Flutter app. */
  static dayOfYear(time: number): number {
    const date = new Date(time);
    const start = Date.UTC(date.getUTCFullYear(), 0, 1);
    return Math.floor((WallTime.startOfDay(time) - start) / WallTime.DAY) + 1;
  }

  static pad(value: number, width: number): string {
    let text = `${value}`;
    while (text.length < width) {
      text = '0' + text;
    }
    return text;
  }
}
