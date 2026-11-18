import { WallTime } from '../common/WallTime';
import { MinutelyPrecipitation } from './Models';

export enum RainTrend {
  None = 'none',
  Starting = 'starting',
  Stopping = 'stopping',
  Continuing = 'continuing'
}

/** A one-line summary of the next 2 hours of 15-minute precipitation. */
export interface RainOutlook {
  trend: RainTrend;
  /** Minutes until rain starts/stops (rounded up to 5); 0 when not relevant. */
  minutes: number;
}

export class RainOutlooks {
  /** Amounts below this (per 15 minutes) count as dry. */
  static wetThreshold(unit: string): number {
    return unit.toLowerCase().includes('inch') ? 0.004 : 0.1;
  }

  static isWet(step: MinutelyPrecipitation): boolean {
    return step.precipitation >= RainOutlooks.wetThreshold(step.unit);
  }

  /** [steps] start with the current step; [now] is the wall time at the place. */
  static from(steps: MinutelyPrecipitation[], now: number): RainOutlook {
    const outlook = (trend: RainTrend, minutes: number): RainOutlook => {
      const result: RainOutlook = { trend: trend, minutes: minutes };
      return result;
    };
    if (steps.length === 0) {
      return outlook(RainTrend.None, 0);
    }
    const wetNow = RainOutlooks.isWet(steps[0]);
    for (let i = 1; i < steps.length; i++) {
      if (RainOutlooks.isWet(steps[i]) !== wetNow) {
        const minutes = Math.floor((steps[i].time - now) / WallTime.MINUTE);
        const rounded = Math.max(5, Math.floor((minutes + 4) / 5) * 5);
        return outlook(wetNow ? RainTrend.Stopping : RainTrend.Starting, rounded);
      }
    }
    return outlook(wetNow ? RainTrend.Continuing : RainTrend.None, 0);
  }
}
