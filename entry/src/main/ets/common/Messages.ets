import { MoonPhase } from './Astronomy';
import { S } from './AppContext';
import { AqiLevel, UvLevel } from '../model/Models';
import { RainOutlook, RainTrend } from '../model/RainOutlook';
import { ForecastIssue, LocationIssue } from '../state/StateTypes';

/** User-facing text for state values (lib/l10n/messages.dart and friends). */
export class Messages {
  static locationIssue(issue: LocationIssue): string {
    switch (issue) {
      case LocationIssue.ServiceDisabled:
        return S.get($r('app.string.locationServiceDisabled'));
      case LocationIssue.PermissionDenied:
        return S.get($r('app.string.locationPermissionDenied'));
      case LocationIssue.PermissionBlocked:
        return S.get($r('app.string.locationPermissionBlocked'));
      case LocationIssue.Unavailable:
        return S.get($r('app.string.locationUnavailable'));
      default:
        return '';
    }
  }

  /** Message for a failed forecast; [city] is used when the reason is unknown. */
  static forecastIssue(issue: ForecastIssue, city: string): string {
    switch (issue) {
      case ForecastIssue.Network:
        return S.get($r('app.string.forecastErrorNetwork'));
      case ForecastIssue.Data:
        return S.get($r('app.string.forecastErrorData'));
      default:
        return S.get($r('app.string.forecastLoadFailed'), city);
    }
  }

  static moonPhase(phase: MoonPhase): Resource {
    switch (phase) {
      case MoonPhase.New:
        return $r('app.string.moonNew');
      case MoonPhase.WaxingCrescent:
        return $r('app.string.moonWaxingCrescent');
      case MoonPhase.FirstQuarter:
        return $r('app.string.moonFirstQuarter');
      case MoonPhase.WaxingGibbous:
        return $r('app.string.moonWaxingGibbous');
      case MoonPhase.Full:
        return $r('app.string.moonFull');
      case MoonPhase.WaningGibbous:
        return $r('app.string.moonWaningGibbous');
      case MoonPhase.LastQuarter:
        return $r('app.string.moonLastQuarter');
      default:
        return $r('app.string.moonWaningCrescent');
    }
  }

  static aqi(level: AqiLevel): Resource {
    switch (level) {
      case AqiLevel.Good:
        return $r('app.string.aqiGood');
      case AqiLevel.Moderate:
        return $r('app.string.aqiModerate');
      case AqiLevel.Sensitive:
        return $r('app.string.aqiSensitive');
      case AqiLevel.Unhealthy:
        return $r('app.string.aqiUnhealthy');
      case AqiLevel.VeryUnhealthy:
        return $r('app.string.aqiVeryUnhealthy');
      default:
        return $r('app.string.aqiHazardous');
    }
  }

  static uv(level: UvLevel): Resource {
    switch (level) {
      case UvLevel.Low:
        return $r('app.string.uvLow');
      case UvLevel.Moderate:
        return $r('app.string.uvModerate');
      case UvLevel.High:
        return $r('app.string.uvHigh');
      case UvLevel.VeryHigh:
        return $r('app.string.uvVeryHigh');
      default:
        return $r('app.string.uvExtreme');
    }
  }

  static pollen(key: string): string {
    switch (key) {
      case 'alder_pollen':
        return S.get($r('app.string.pollenAlder'));
      case 'birch_pollen':
        return S.get($r('app.string.pollenBirch'));
      case 'grass_pollen':
        return S.get($r('app.string.pollenGrass'));
      case 'mugwort_pollen':
        return S.get($r('app.string.pollenMugwort'));
      case 'olive_pollen':
        return S.get($r('app.string.pollenOlive'));
      case 'ragweed_pollen':
        return S.get($r('app.string.pollenRagweed'));
      default:
        return key;
    }
  }

  static rainOutlook(outlook: RainOutlook): string {
    switch (outlook.trend) {
      case RainTrend.Starting:
        return S.get($r('app.string.rainStartingIn'), `${outlook.minutes}`);
      case RainTrend.Stopping:
        return S.get($r('app.string.rainStoppingIn'), `${outlook.minutes}`);
      case RainTrend.Continuing:
        return S.get($r('app.string.rainContinuing'));
      default:
        return S.get($r('app.string.noRainSoon'));
    }
  }
}
