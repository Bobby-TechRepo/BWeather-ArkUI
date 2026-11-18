/**
 * Decides light or dark for the "Auto" theme from the user's own clock:
 * light from sunrise to sunset at the user's location, dark otherwise.
 * Without a location it falls back to 07:00–19:00 on the device clock
 * (lib/utils/day_night.dart).
 */
export class DayNight {
  /** The sun's centre is this far below the horizon at sunrise and sunset (refraction plus the sun's radius). */
  private static readonly HORIZON: number = -0.833;

  static isDay(now: number, latitude?: number, longitude?: number): boolean {
    if (latitude === undefined || longitude === undefined) {
      const hour = new Date(now).getHours();
      return hour >= 7 && hour < 19;
    }
    return DayNight.sunElevation(now, latitude, longitude) > DayNight.HORIZON;
  }

  /** Height of the sun above the horizon in degrees (low-precision solar position, well under a degree). */
  static sunElevation(time: number, latitude: number, longitude: number): number {
    const rad = Math.PI / 180;
    const days = time / 86400000 + 2440587.5 - 2451545.0;
    const anomaly = (357.529 + 0.98560028 * days) * rad;
    const meanLongitude = 280.459 + 0.98564736 * days;
    const eclipticLongitude = (meanLongitude + 1.915 * Math.sin(anomaly) + 0.020 * Math.sin(2 * anomaly)) * rad;
    const obliquity = (23.439 - 0.00000036 * days) * rad;

    const rightAscension = Math.atan2(Math.cos(obliquity) * Math.sin(eclipticLongitude), Math.cos(eclipticLongitude));
    const declination = Math.asin(Math.sin(obliquity) * Math.sin(eclipticLongitude));
    const siderealDegrees = (18.697374558 + 24.06570982441908 * days) * 15 + longitude;
    const hourAngle = siderealDegrees * rad - rightAscension;

    const lat = latitude * rad;
    const sine = Math.sin(lat) * Math.sin(declination) + Math.cos(lat) * Math.cos(declination) * Math.cos(hourAngle);
    return Math.asin(Math.max(-1, Math.min(1, sine))) / rad;
  }
}
