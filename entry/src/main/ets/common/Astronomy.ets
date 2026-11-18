/**
 * Small offline astronomy helpers: moon phase and the sun's progress through
 * the day. Accurate to a few hours, which is plenty for display.
 */
export enum MoonPhase {
  New = 0,
  WaxingCrescent = 1,
  FirstQuarter = 2,
  WaxingGibbous = 3,
  Full = 4,
  WaningGibbous = 5,
  LastQuarter = 6,
  WaningCrescent = 7
}

export class MoonInfo {
  /** Average length of a lunar cycle, in days. */
  static readonly SYNODIC_MONTH: number = 29.530588853;
  /** A known new moon: 6 January 2000, 18:14 UTC. */
  static readonly REFERENCE_NEW_MOON: number = Date.UTC(2000, 0, 6, 18, 14);

  /** Days since the last new moon (0 to 29.53). */
  readonly age: number;

  constructor(age: number) {
    this.age = age;
  }

  /** [time] is a real instant (device clock), not a wall time. */
  static at(time: number): MoonInfo {
    const days = (time - MoonInfo.REFERENCE_NEW_MOON) / 86400000;
    const age = ((days % MoonInfo.SYNODIC_MONTH) + MoonInfo.SYNODIC_MONTH) % MoonInfo.SYNODIC_MONTH;
    return new MoonInfo(age);
  }

  /** 0 = new, 0.5 = full, approaching 1 = new again. */
  get fraction(): number {
    return this.age / MoonInfo.SYNODIC_MONTH;
  }

  /** Share of the visible disc that is lit (0 to 1). */
  get illumination(): number {
    return (1 - Math.cos(2 * Math.PI * this.fraction)) / 2;
  }

  get phase(): MoonPhase {
    const phases: MoonPhase[] = [
      MoonPhase.New, MoonPhase.WaxingCrescent, MoonPhase.FirstQuarter, MoonPhase.WaxingGibbous,
      MoonPhase.Full, MoonPhase.WaningGibbous, MoonPhase.LastQuarter, MoonPhase.WaningCrescent
    ];
    return phases[Math.floor(this.fraction * 8 + 0.5) % 8];
  }
}

export class SunProgress {
  /**
   * 0 at sunrise, 1 at sunset; -1 before sunrise or after sunset. All three
   * times are wall times at the place.
   */
  static at(sunrise: number, sunset: number, localNow: number): number {
    const total = sunset - sunrise;
    if (total <= 0 || localNow < sunrise || localNow > sunset) {
      return -1;
    }
    return (localNow - sunrise) / total;
  }
}
