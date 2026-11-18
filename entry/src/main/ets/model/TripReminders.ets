import { WallTime } from '../common/WallTime';
import { City } from './Models';
import { Trip, TripTiming, TripUtil } from './Trips';

/**
 * A pre-trip notification for the background worker: the evening before
 * [departure], with the forecast for the first stop (lib/services/trip_reminders.dart).
 */
export interface TripReminder {
  /** Trip id plus departure date, so moving the trip re-arms the reminder. */
  id: string;
  tripName: string;
  city: City;
  /** Departure date as a wall-time midnight. */
  departure: number;
}

export class TripReminders {
  /**
   * Reminders go out from 17:00 the day before until 10:00 on the day
   * (device time); background runs are hours apart, so the window is wide.
   */
  static readonly FROM_HOUR: number = 17;
  static readonly UNTIL_HOUR: number = 10;

  static isDue(reminder: TripReminder, now?: number): boolean {
    const date = new Date(now ?? Date.now());
    // The device's clock as a wall time, to compare with the departure date.
    const wallNow = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes());
    const opens = reminder.departure - WallTime.DAY + TripReminders.FROM_HOUR * WallTime.HOUR;
    const closes = reminder.departure + TripReminders.UNTIL_HOUR * WallTime.HOUR;
    return wallNow >= opens && wallNow < closes;
  }

  /** Reminders for upcoming trips that have them turned on. */
  static fromTrips(trips: Trip[], today?: number): TripReminder[] {
    const reminders: TripReminder[] = [];
    for (const trip of trips) {
      if (!trip.remind || trip.stops.length === 0 || TripUtil.timing(trip, today) !== TripTiming.Upcoming) {
        continue;
      }
      const start = TripUtil.start(trip);
      const first = trip.stops[0].city;
      // Only what the worker needs: no forecast.
      const city: City = {
        name: first.name,
        country: first.country,
        region: first.region,
        timezone: first.timezone,
        latitude: first.latitude,
        longitude: first.longitude
      };
      const reminder: TripReminder = {
        id: `${trip.id}@${WallTime.isoDate(start)}`,
        tripName: trip.name,
        city: city,
        departure: start
      };
      reminders.push(reminder);
    }
    return reminders;
  }
}
