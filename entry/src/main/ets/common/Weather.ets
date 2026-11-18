/** What the sky looks like for a WMO weather code: icons, descriptions and backgrounds. */
export enum SkyKind {
  Clear = 'clear',
  PartlyCloudy = 'partlyCloudy',
  Overcast = 'overcast',
  Fog = 'fog',
  Drizzle = 'drizzle',
  Rain = 'rain',
  HeavyRain = 'heavyRain',
  Snow = 'snow',
  Thunder = 'thunder'
}

export interface SkyScene {
  kind: SkyKind;
  night: boolean;
}

export class Sky {
  static scene(weatherCode: number, isDay: boolean): SkyScene {
    const scene: SkyScene = { kind: Sky.kind(weatherCode), night: !isDay };
    return scene;
  }

  static kind(code: number): SkyKind {
    switch (code) {
      case 0:
      case 1:
        return SkyKind.Clear;
      case 2:
        return SkyKind.PartlyCloudy;
      case 3:
        return SkyKind.Overcast;
      case 45:
      case 48:
        return SkyKind.Fog;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return SkyKind.Drizzle;
      case 61:
      case 63:
      case 66:
      case 80:
      case 81:
        return SkyKind.Rain;
      case 65:
      case 67:
      case 82:
        return SkyKind.HeavyRain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return SkyKind.Snow;
      case 95:
      case 96:
      case 99:
        return SkyKind.Thunder;
      default:
        return SkyKind.Overcast;
    }
  }

  /**
   * Card gradients (start, end) for a place's current sky. All are dark enough
   * for white text.
   */
  static gradient(scene: SkyScene): string[] {
    if (scene.night) {
      switch (scene.kind) {
        case SkyKind.Clear:
        case SkyKind.PartlyCloudy:
          return ['#0E1A3C', '#2A3D70'];
        case SkyKind.Thunder:
          return ['#1C1733', '#3B3463'];
        case SkyKind.Snow:
          return ['#23324A', '#475C7A'];
        default:
          return ['#1A222E', '#384456'];
      }
    }
    switch (scene.kind) {
      case SkyKind.Clear:
        return ['#1F6FBF', '#3482C8'];
      case SkyKind.PartlyCloudy:
        return ['#2E6BA6', '#4E80B2'];
      case SkyKind.Overcast:
        return ['#4F6275', '#64788B'];
      case SkyKind.Fog:
        return ['#5B6773', '#6E7B88'];
      case SkyKind.Drizzle:
      case SkyKind.Rain:
        return ['#34506D', '#587592'];
      case SkyKind.HeavyRain:
        return ['#253A52', '#44607E'];
      case SkyKind.Snow:
        return ['#4A6C93', '#5F80A6'];
      default:
        return ['#2B2648', '#4F4878'];
    }
  }
}

/** Meteocons artwork for a weather code, day or night (lib/utils/weather_codes.dart). */
export class WeatherIcons {
  static icon(code: number, night: boolean): Resource {
    return night ? WeatherIcons.nightIcon(code) : WeatherIcons.dayIcon(code);
  }

  static dayIcon(code: number): Resource {
    switch (code) {
      case 0:
      case 1:
        return $r('app.media.wx_clear_day_fill');
      case 2:
        return $r('app.media.wx_partly_cloudy_day_fill');
      case 3:
        return $r('app.media.wx_overcast_fill');
      case 45:
      case 48:
        return $r('app.media.wx_fog_day_fill');
      case 51:
        return $r('app.media.wx_partly_cloudy_day_drizzle_fill');
      case 53:
        return $r('app.media.wx_overcast_day_drizzle_fill');
      case 55:
        return $r('app.media.wx_extreme_day_drizzle_fill');
      case 56:
        return $r('app.media.wx_overcast_drizzle_fill');
      case 57:
        return $r('app.media.wx_extreme_drizzle_fill');
      case 61:
        return $r('app.media.wx_partly_cloudy_day_rain_fill');
      case 63:
        return $r('app.media.wx_overcast_day_rain_fill');
      case 65:
        return $r('app.media.wx_extreme_day_rain_fill');
      case 66:
      case 81:
        return $r('app.media.wx_overcast_rain_fill');
      case 67:
      case 82:
        return $r('app.media.wx_extreme_rain_fill');
      case 71:
      case 77:
        return $r('app.media.wx_snow_fill');
      case 73:
        return $r('app.media.wx_extreme_day_snow_fill');
      case 75:
      case 86:
        return $r('app.media.wx_extreme_snow_fill');
      case 80:
        return $r('app.media.wx_drizzle_fill');
      case 85:
        return $r('app.media.wx_partly_cloudy_day_snow_fill');
      case 95:
        return $r('app.media.wx_thunderstorms_day_fill');
      case 96:
        return $r('app.media.wx_thunderstorms_day_overcast_fill');
      case 99:
        return $r('app.media.wx_thunderstorms_day_extreme_fill');
      default:
        return $r('app.media.wx_overcast_fill');
    }
  }

  static nightIcon(code: number): Resource {
    switch (code) {
      case 0:
      case 1:
        return $r('app.media.wx_clear_night_fill');
      case 2:
        return $r('app.media.wx_partly_cloudy_night_fill');
      case 3:
        return $r('app.media.wx_overcast_night_fill');
      case 45:
      case 48:
        return $r('app.media.wx_fog_night_fill');
      case 51:
      case 80:
        return $r('app.media.wx_drizzle_fill');
      case 53:
        return $r('app.media.wx_partly_cloudy_night_drizzle_fill');
      case 55:
        return $r('app.media.wx_extreme_night_drizzle_fill');
      case 61:
        return $r('app.media.wx_partly_cloudy_night_rain_fill');
      case 63:
        return $r('app.media.wx_overcast_night_rain_fill');
      case 65:
        return $r('app.media.wx_extreme_night_rain_fill');
      case 73:
        return $r('app.media.wx_extreme_night_snow_fill');
      case 85:
        return $r('app.media.wx_partly_cloudy_night_snow_fill');
      case 95:
        return $r('app.media.wx_thunderstorms_night_fill');
      case 96:
        return $r('app.media.wx_thunderstorms_night_overcast_fill');
      case 99:
        return $r('app.media.wx_thunderstorms_night_extreme_fill');
      default:
        return WeatherIcons.dayIcon(code);
    }
  }

  /** Localized WMO description, e.g. "Light rain" / "Pluie faible". */
  static describe(code: number): Resource {
    switch (code) {
      case 0:
        return $r('app.string.wmo0');
      case 1:
        return $r('app.string.wmo1');
      case 2:
        return $r('app.string.wmo2');
      case 3:
        return $r('app.string.wmo3');
      case 45:
        return $r('app.string.wmo45');
      case 48:
        return $r('app.string.wmo48');
      case 51:
        return $r('app.string.wmo51');
      case 53:
        return $r('app.string.wmo53');
      case 55:
        return $r('app.string.wmo55');
      case 56:
        return $r('app.string.wmo56');
      case 57:
        return $r('app.string.wmo57');
      case 61:
        return $r('app.string.wmo61');
      case 63:
        return $r('app.string.wmo63');
      case 65:
        return $r('app.string.wmo65');
      case 66:
        return $r('app.string.wmo66');
      case 67:
        return $r('app.string.wmo67');
      case 71:
        return $r('app.string.wmo71');
      case 73:
        return $r('app.string.wmo73');
      case 75:
        return $r('app.string.wmo75');
      case 77:
        return $r('app.string.wmo77');
      case 80:
        return $r('app.string.wmo80');
      case 81:
        return $r('app.string.wmo81');
      case 82:
        return $r('app.string.wmo82');
      case 85:
        return $r('app.string.wmo85');
      case 86:
        return $r('app.string.wmo86');
      case 95:
        return $r('app.string.wmo95');
      case 96:
        return $r('app.string.wmo96');
      case 99:
        return $r('app.string.wmo99');
      default:
        return $r('app.string.wmoUnknown');
    }
  }
}
