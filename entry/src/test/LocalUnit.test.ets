import { describe, it, expect } from '@ohos/hypium';
import { MoonInfo, MoonPhase, SunProgress } from '../main/ets/common/Astronomy';
import { PrecipitationUnit, TempUnit, UnitConverter, Units, WindSpeedUnit } from '../main/ets/common/Units';
import { DayNight } from '../main/ets/common/DayNight';
import { WallTime } from '../main/ets/common/WallTime';
import { CardDataUtil } from '../main/ets/model/CardData';
import { MapMath, TileSpec, WorldPoint } from '../main/ets/model/MapMath';
import { AlertEvaluator, AlertKind, AlertLog, AlertPrefs, PendingAlert } from '../main/ets/model/Alerts';
import { TripReminder, TripReminders } from '../main/ets/model/TripReminders';
import { CityUtil, ForecastUtil, NormalsUtil } from '../main/ets/model/ForecastUtil';
import { Anomaly, City, Current, Daily, Forecast, Hourly, MinutelyPrecipitation, Value } from '../main/ets/model/Models';
import { RainOutlooks, RainTrend } from '../main/ets/model/RainOutlook';
import { DayKind, PackingItem, StopForecast, Trip, TripProblem, TripStop, TripTiming, TripUtil } from '../main/ets/model/Trips';

const FAHRENHEIT_MPH: Units = { temp: TempUnit.Fahrenheit, wind: WindSpeedUnit.Mph, precipitation: PrecipitationUnit.Inch };
const MS: Units = { temp: TempUnit.Celsius, wind: WindSpeedUnit.Ms, precipitation: PrecipitationUnit.Mm };
const KNOTS: Units = { temp: TempUnit.Celsius, wind: WindSpeedUnit.Kn, precipitation: PrecipitationUnit.Mm };

function v(value: number, unit: string): Value {
  const result: Value = { value: value, unit: unit };
  return result;
}

/** 14 Nov 2026 in wall time, plus [hours]. */
function at(hours: number): number {
  return Date.UTC(2026, 10, 14) + hours * WallTime.HOUR;
}

function hour(hours: number, temperature: number, rainChance: number): Hourly {
  const result: Hourly = {
    time: at(hours),
    weatherCode: 61,
    temperature: v(temperature, '°C'),
    apparentTemperature: v(temperature - 1, '°C'),
    dewPoint: v(5, '°C'),
    rain: v(1, 'mm'),
    relativeHumidity: v(80, '%'),
    precipitationProbability: v(rainChance, '%'),
    isDay: true
  };
  return result;
}

function sampleForecast(): Forecast {
  const current: Current = {
    time: at(10),
    weatherCode: 61,
    isDay: true,
    temperature: v(20, '°C'),
    apparentTemperature: v(21, '°C'),
    windSpeed: v(36, 'km/h'),
    windGusts: v(72, 'km/h'),
    windDirection: v(90, '°'),
    precipitation: v(2.54, 'mm'),
    rain: v(2.54, 'mm'),
    surfacePressure: v(1010, 'hPa'),
    cloudCover: v(90, '%'),
    relativeHumidity: v(70, '%')
  };
  const day: Daily = {
    time: at(0),
    weatherCode: 61,
    temperatureMax: v(25, '°C'),
    temperatureMin: v(15, '°C'),
    apparentTemperatureMax: v(26, '°C'),
    apparentTemperatureMin: v(14, '°C'),
    sunrise: at(6.5),
    sunset: at(18.25),
    precipitationSum: v(5.08, 'mm'),
    precipitationProbabilityMax: v(80, '%'),
    windSpeedMax: v(18, 'km/h')
  };
  const step: MinutelyPrecipitation = { time: at(10), precipitation: 0.254, unit: 'mm' };
  const forecast: Forecast = {
    utcOffsetSeconds: 0,
    current: current,
    hourly: [hour(9, 9, 10), hour(10, 10, 60), hour(11, 12, 30)],
    daily: [day],
    minutely: [step]
  };
  return forecast;
}

function sampleCity(): City {
  const city: City = { name: 'Paris', country: 'France', timezone: 'auto', latitude: 48.85, longitude: 2.35 };
  return city;
}

export default function localUnitTest() {
  describe('unitConverter', () => {
    it('convertsTemperatures', 0, () => {
      const f = UnitConverter.convert(0, '°C', FAHRENHEIT_MPH);
      expect(f.value).assertEqual(32);
      expect(f.unit).assertEqual('°F');
      expect(UnitConverter.convert(212, '°F', UnitConverter.METRIC).value).assertEqual(100);
      expect(UnitConverter.convert(21.5, '°C', UnitConverter.METRIC).value).assertEqual(21.5);
    });

    it('convertsWindSpeedBetweenAllFourUnits', 0, () => {
      expect(UnitConverter.convert(36, 'km/h', MS).value).assertEqual(10);
      expect(UnitConverter.convert(36, 'km/h', MS).unit).assertEqual('m/s');
      expect(UnitConverter.convert(10, 'm/s', UnitConverter.METRIC).value).assertEqual(36);
      expect(UnitConverter.convert(1.852, 'km/h', KNOTS).value).assertEqual(1);
      const mph = UnitConverter.convert(100, 'km/h', FAHRENHEIT_MPH);
      expect(mph.value).assertClose(62.14, 0.01);
      expect(mph.unit).assertEqual('mp/h');
      expect(UnitConverter.convert(62.14, 'mp/h', UnitConverter.METRIC).value).assertClose(100, 0.01);
    });

    it('convertsPrecipitation', 0, () => {
      expect(UnitConverter.convert(25.4, 'mm', FAHRENHEIT_MPH).value).assertEqual(1);
      expect(UnitConverter.convert(25.4, 'mm', FAHRENHEIT_MPH).unit).assertEqual('inch');
      expect(UnitConverter.convert(0.5, 'inch', UnitConverter.METRIC).value).assertEqual(12.7);
    });

    it('leavesOtherUnitsAlone', 0, () => {
      expect(UnitConverter.convert(1013, 'hPa', FAHRENHEIT_MPH).unit).assertEqual('hPa');
      expect(UnitConverter.convert(80, '%', FAHRENHEIT_MPH).value).assertEqual(80);
    });

    it('doesNotDriftOverRoundTrips', 0, () => {
      let value = 27.4;
      for (let i = 0; i < 20; i++) {
        value = UnitConverter.convert(UnitConverter.convert(value, '°C', FAHRENHEIT_MPH).value, '°F', UnitConverter.METRIC).value;
      }
      expect(value).assertClose(27.4, 0.01);
    });

    it('convertsAWholeForecast', 0, () => {
      const forecast = sampleForecast();
      const converted = UnitConverter.forecast(forecast, FAHRENHEIT_MPH);
      expect(converted.current.temperature.value).assertEqual(68);
      expect(converted.current.temperature.unit).assertEqual('°F');
      expect(converted.current.windGusts.unit).assertEqual('mp/h');
      expect(converted.current.rain.value).assertEqual(0.1);
      expect(converted.current.windDirection.value).assertEqual(90);
      expect(converted.hourly[0].dewPoint.value).assertEqual(41);
      expect(converted.daily[0].temperatureMax.value).assertEqual(77);
      expect(converted.daily[0].precipitationSum?.value).assertEqual(0.2);
      expect(converted.daily[0].precipitationProbabilityMax?.value).assertEqual(80);
      expect(converted.minutely[0].unit).assertEqual('inch');
      expect(converted.minutely[0].precipitation).assertClose(0.01, 0.0005);

      const back = UnitConverter.forecast(converted, UnitConverter.METRIC);
      expect(back.current.temperature.value).assertClose(20, 0.001);
      expect(back.current.windSpeed.value).assertClose(36, 0.001);
      expect(back.daily[0].precipitationSum?.value ?? 0).assertClose(5.08, 0.001);
    });

    it('keepsValuesUntouchedInTheSameUnits', 0, () => {
      const forecast = sampleForecast();
      const same = UnitConverter.forecast(forecast, UnitConverter.METRIC);
      expect(same.current.temperature === forecast.current.temperature).assertTrue();
      expect(same.daily[0].temperatureMax === forecast.daily[0].temperatureMax).assertTrue();
    });
  });

  describe('wallTime', () => {
    it('parsesOpenMeteoTimesAsWallClockReadings', 0, () => {
      expect(WallTime.parse('2026-11-14T15:30')).assertEqual(Date.UTC(2026, 10, 14, 15, 30));
      expect(WallTime.parse('2026-11-14')).assertEqual(Date.UTC(2026, 10, 14));
      expect(isNaN(WallTime.parse('not a date'))).assertTrue();
      expect(WallTime.isoDate(Date.UTC(2026, 0, 5, 23))).assertEqual('2026-01-05');
    });

    it('computesTheTimeAtAPlace', 0, () => {
      const now = Date.UTC(2026, 10, 14, 12, 0, 30);
      expect(WallTime.localNow(3600, now)).assertEqual(Date.UTC(2026, 10, 14, 13, 0));
      expect(WallTime.localNow(-5 * 3600 - 1800, now)).assertEqual(Date.UTC(2026, 10, 14, 6, 30));
    });

    it('countsDaysOfTheYear', 0, () => {
      expect(WallTime.dayOfYear(Date.UTC(2026, 0, 1))).assertEqual(1);
      expect(WallTime.dayOfYear(Date.UTC(2024, 11, 31))).assertEqual(366);
    });
  });

  describe('forecastUtil', () => {
    it('findsTheUpcomingHoursAndTodayAtThePlace', 0, () => {
      const forecast = sampleForecast();
      const now = Date.UTC(2026, 10, 14, 10, 20);
      const hours = ForecastUtil.upcomingHours(forecast, 24, now);
      expect(hours.length).assertEqual(2);
      expect(hours[0].time).assertEqual(at(10));
      expect(ForecastUtil.currentHour(forecast, now)?.temperature.value).assertEqual(10);
      expect(ForecastUtil.today(forecast, now)?.time).assertEqual(at(0));
    });

    it('tellsDayFromNight', 0, () => {
      const forecast = sampleForecast();
      const night = hour(22, 8, 0);
      night.isDay = undefined;
      expect(ForecastUtil.isNight(forecast, night)).assertTrue();
      expect(ForecastUtil.isNight(forecast, hour(12, 20, 0))).assertFalse();
    });

    it('givesSavedPlacesAStableIdAndSubtitle', 0, () => {
      const city: City = { name: 'Ikeja', country: 'Nigeria', region: 'Lagos', timezone: 'auto', latitude: 6.60184, longitude: 3.35149 };
      expect(CityUtil.id(city)).assertEqual('6.602,3.351');
      expect(CityUtil.subtitle(city)).assertEqual('Lagos, Nigeria');
    });
  });

  describe('climateNormals', () => {
    it('averagesHistoryAroundEachDayOfTheYear', 0, () => {
      const dates: number[] = [];
      const highs: (number | null)[] = [];
      const lows: (number | null)[] = [];
      for (let year = 2020; year <= 2021; year++) {
        dates.push(Date.UTC(year, 5, 15));
        highs.push(year === 2020 ? 30 : 32);
        lows.push(null);
      }
      const normals = NormalsUtil.fromDaily(dates, highs, lows);
      expect(normals.fromYear).assertEqual(2020);
      expect(normals.toYear).assertEqual(2021);
      expect(NormalsUtil.highFor(normals, Date.UTC(2026, 5, 15))).assertClose(31, 0.6);
      expect(NormalsUtil.lowFor(normals, Date.UTC(2026, 5, 15)) === undefined).assertTrue();
      expect(NormalsUtil.highFor(normals, Date.UTC(2026, 0, 1)) === undefined).assertTrue();
    });

    it('classifiesDifferences', 0, () => {
      expect(NormalsUtil.anomaly(0.5)).assertEqual(Anomaly.Normal);
      expect(NormalsUtil.anomaly(2)).assertEqual(Anomaly.Warmer);
      expect(NormalsUtil.anomaly(-6)).assertEqual(Anomaly.MuchCooler);
      expect(NormalsUtil.degreesIn(-2.5, '°F')).assertEqual(5);
    });
  });

  describe('rainOutlook', () => {
    it('saysWhenRainStartsAndStops', 0, () => {
      const now = at(10);
      const step = (minutes: number, amount: number): MinutelyPrecipitation => {
        const result: MinutelyPrecipitation = { time: now + minutes * WallTime.MINUTE, precipitation: amount, unit: 'mm' };
        return result;
      };
      const starting = RainOutlooks.from([step(0, 0), step(15, 0), step(30, 0.4)], now);
      expect(starting.trend).assertEqual(RainTrend.Starting);
      expect(starting.minutes).assertEqual(30);
      expect(RainOutlooks.from([step(0, 0.5), step(15, 0)], now).trend).assertEqual(RainTrend.Stopping);
      expect(RainOutlooks.from([step(0, 0.5), step(15, 0.5)], now).trend).assertEqual(RainTrend.Continuing);
      expect(RainOutlooks.from([], now).trend).assertEqual(RainTrend.None);
    });
  });

  describe('astronomy', () => {
    it('knowsTheMoonPhase', 0, () => {
      // Full moon on 5 November 2025, 13:19 UTC.
      const full = MoonInfo.at(Date.UTC(2025, 10, 5, 13, 19));
      expect(full.phase).assertEqual(MoonPhase.Full);
      expect(full.illumination).assertLarger(0.97);
      expect(MoonInfo.at(Date.UTC(2000, 0, 6, 18, 14)).phase).assertEqual(MoonPhase.New);
    });

    it('tracksTheSunThroughTheDay', 0, () => {
      expect(SunProgress.at(at(6), at(18), at(12))).assertClose(0.5, 0.0001);
      expect(SunProgress.at(at(6), at(18), at(20))).assertEqual(-1);
    });
  });

  describe('trips', () => {
    const day = (d: number): number => Date.UTC(2026, 11, d);
    const city = (name: string, latitude: number): City => {
      const result: City = { name: name, country: 'Nigeria', timezone: 'auto', latitude: latitude, longitude: 7 };
      return result;
    };
    const abuja = TripUtil.newStop('a', city('Abuja', 9.07), day(20), day(23));
    const kano = TripUtil.newStop('k', city('Kano', 12), day(23), day(26));
    const trip: Trip = { id: 't', name: 'Christmas', stops: [abuja, kano], packed: [], remind: false };

    it('validatesStops', 0, () => {
      expect(TripUtil.validate([abuja, kano])).assertEqual(TripProblem.None);
      expect(TripUtil.validate([])).assertEqual(TripProblem.NoStops);
      const overlap: TripStop = TripUtil.newStop('k', city('Kano', 12), day(22), day(26));
      expect(TripUtil.validate([abuja, overlap])).assertEqual(TripProblem.StopsOverlap);
      const backwards: TripStop = TripUtil.newStop('b', city('Kano', 12), day(26), day(23));
      expect(TripUtil.validate([backwards])).assertEqual(TripProblem.StopEndsBeforeItStarts);
    });

    it('knowsTheDatesAndTravelDays', 0, () => {
      expect(TripUtil.dayCount(trip)).assertEqual(7);
      expect(TripUtil.stopOn(trip, day(23))?.id).assertEqual('k');
      expect(TripUtil.leavingOn(trip, day(23))?.id).assertEqual('a');
      expect(TripUtil.leavingOn(trip, day(21)) === undefined).assertTrue();
      expect(TripUtil.timing(trip, day(1))).assertEqual(TripTiming.Upcoming);
      expect(TripUtil.timing(trip, day(24))).assertEqual(TripTiming.Ongoing);
      expect(TripUtil.daysUntil(trip, day(18))).assertEqual(2);
    });

    it('clampsToTheForecastWindow', 0, () => {
      const range = TripUtil.forecastWindow(day(20), day(30), day(10));
      expect(range.length).assertEqual(2);
      expect(range[1]).assertEqual(day(25));
      expect(TripUtil.forecastWindow(day(28), day(30), day(1)).length).assertEqual(0);
    });

    it('buildsDaysOutlookAndPacking', 0, () => {
      const rainy: Daily = {
        time: day(20), weatherCode: 63,
        temperatureMax: v(33, '°C'), temperatureMin: v(24, '°C'),
        apparentTemperatureMax: v(36, '°C'), apparentTemperatureMin: v(25, '°C'),
        precipitationSum: v(5, 'mm'), precipitationProbabilityMax: v(70, '%'), windSpeedMax: v(20, 'km/h')
      };
      const forecast: StopForecast = { stopId: 'a', days: [rainy], fetchedAt: 0, units: 'celsius|kmh|mm' };
      const days = TripUtil.tripDays(trip, [forecast], [], false);
      expect(days.length).assertEqual(7);
      expect(days[0].kind).assertEqual(DayKind.Forecast);
      expect(days[1].kind).assertEqual(DayKind.Unknown);
      const outlook = TripUtil.outlook(days);
      expect(outlook.rainyDays).assertEqual(1);
      expect(outlook.commonCode).assertEqual(63);
      expect(outlook.high).assertEqual(33);
      const packing = TripUtil.packingFor(days);
      expect(packing.includes(PackingItem.Umbrella)).assertTrue();
      expect(packing.includes(PackingItem.WaterBottle)).assertTrue();
      expect(packing.includes(PackingItem.Coat)).assertFalse();
    });
  });

  describe('dayNight', () => {
    it('lightAtNoonAndDarkAtMidnightInLagos', 0, () => {
      expect(DayNight.isDay(Date.UTC(2026, 10, 14, 12), 6.45, 3.39)).assertTrue();
      expect(DayNight.isDay(Date.UTC(2026, 10, 14, 0), 6.45, 3.39)).assertFalse();
    });
    it('switchesAroundSunset', 0, () => {
      // London, 14 Nov: sunset is about 16:13 UTC.
      expect(DayNight.isDay(Date.UTC(2026, 10, 14, 16, 0), 51.5, -0.12)).assertTrue();
      expect(DayNight.isDay(Date.UTC(2026, 10, 14, 16, 30), 51.5, -0.12)).assertFalse();
    });
    it('fallsBackToDeviceClock', 0, () => {
      expect(DayNight.isDay(new Date(2026, 10, 14, 12).getTime())).assertTrue();
      expect(DayNight.isDay(new Date(2026, 10, 14, 22).getTime())).assertFalse();
    });
  });

  describe('alerts', () => {
    const prefs: AlertPrefs = { morningBrief: true, rain: true, severe: true, briefHour: 7 };
    const empty: AlertLog = {};

    it('rainSoonOnceThenCoolsDown', 0, () => {
      const forecast = sampleForecast();
      forecast.current.rain = v(0, 'mm');
      forecast.current.windGusts = v(20, 'km/h');
      forecast.hourly = [hour(10, 20, 10), hour(11, 20, 20), hour(12, 20, 70), hour(13, 20, 0)];
      const now = Date.UTC(2026, 10, 14, 10, 30);
      const first = AlertEvaluator.evaluate(forecast, prefs, empty, 'Lagos', now);
      expect(first.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Rain)).assertTrue();
      expect(first.log.lastRainAlertAt).assertEqual(now);
      const again = AlertEvaluator.evaluate(forecast, prefs, first.log, 'Lagos', now + WallTime.HOUR);
      expect(again.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Rain)).assertFalse();
    });

    it('noRainAlertWhenAlreadyRaining', 0, () => {
      const forecast = sampleForecast();
      forecast.hourly = [hour(10, 20, 80), hour(11, 20, 90), hour(12, 20, 90)];
      const result = AlertEvaluator.evaluate(forecast, prefs, empty, 'Lagos', Date.UTC(2026, 10, 14, 10, 30));
      expect(result.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Rain)).assertFalse();
    });

    it('morningBriefOncePerDay', 0, () => {
      const forecast = sampleForecast();
      forecast.hourly = [hour(8, 20, 0), hour(9, 20, 0), hour(10, 20, 0)];
      const now = Date.UTC(2026, 10, 14, 8, 15);
      const first = AlertEvaluator.evaluate(forecast, prefs, empty, 'Lagos', now);
      expect(first.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Brief)).assertTrue();
      expect(first.log.lastBriefDay).assertEqual('2026-11-14');
      const again = AlertEvaluator.evaluate(forecast, prefs, first.log, 'Lagos', now + WallTime.HOUR);
      expect(again.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Brief)).assertFalse();
    });

    it('strongGustsAreSevere', 0, () => {
      const forecast = sampleForecast();
      forecast.current.windGusts = v(80, 'km/h');
      const result = AlertEvaluator.evaluate(forecast, prefs, empty, 'Lagos', Date.UTC(2026, 10, 14, 10, 30));
      expect(result.alerts.some((alert: PendingAlert) => alert.kind === AlertKind.Severe)).assertTrue();
    });
  });

  describe('tripReminders', () => {
    const reminder: TripReminder = {
      id: 'trip@2026-11-20',
      tripName: 'Paris',
      city: sampleCity(),
      departure: Date.UTC(2026, 10, 20)
    };
    it('dueFromTheEveningBefore', 0, () => {
      expect(TripReminders.isDue(reminder, new Date(2026, 10, 19, 18).getTime())).assertTrue();
      expect(TripReminders.isDue(reminder, new Date(2026, 10, 20, 9).getTime())).assertTrue();
    });
    it('notDueOutsideTheWindow', 0, () => {
      expect(TripReminders.isDue(reminder, new Date(2026, 10, 19, 12).getTime())).assertFalse();
      expect(TripReminders.isDue(reminder, new Date(2026, 10, 20, 11).getTime())).assertFalse();
    });
  });

  describe('homeCard', () => {
    it('picksArtworkByCodeAndTime', 0, () => {
      expect(CardDataUtil.iconKey(0, false)).assertEqual('clear_day');
      expect(CardDataUtil.iconKey(1, true)).assertEqual('clear_night');
      expect(CardDataUtil.iconKey(63, false)).assertEqual('rain');
      expect(CardDataUtil.iconKey(81, true)).assertEqual('rain');
      expect(CardDataUtil.iconKey(75, false)).assertEqual('snow');
      expect(CardDataUtil.iconKey(96, true)).assertEqual('thunder_night');
    });
    it('buildsCardText', 0, () => {
      const data = CardDataUtil.from(sampleCity(), sampleForecast(), Date.UTC(2026, 10, 14, 10, 30));
      expect(data.ready).assertTrue();
      expect(data.place).assertEqual('Paris');
      expect(data.temperature).assertEqual('20°');
      expect(data.icon).assertEqual('rain');
    });
  });

  describe('radarMap', () => {
    it('projectsToTheWorld', 0, () => {
      const middle = MapMath.toWorld(0, 0);
      expect(middle.x).assertEqual(0.5);
      expect(Math.abs(middle.y - 0.5) < 1e-9).assertTrue();
      expect(MapMath.toWorld(60, 0).y < 0.5).assertTrue();
      expect(MapMath.worldSize(2)).assertEqual(1024);
    });
    it('coversTheViewAndWrapsSideways', 0, () => {
      const center: WorldPoint = { x: 0, y: 0.5 };
      const tiles = MapMath.visibleTiles('osm', 'https://t/{z}/{x}/{y}.png', center, 3, 3, 512, 256);
      // 512 px wide at 256 px tiles centred on a tile edge: 2 columns, plus 1 or 2 rows.
      expect(tiles.length >= 2).assertTrue();
      expect(tiles.some((tile: TileSpec) => tile.url === 'https://t/3/7/3.png')).assertTrue();
      expect(tiles.some((tile: TileSpec) => tile.url === 'https://t/3/0/3.png')).assertTrue();
    });
    it('stretchesLowerTileLevels', 0, () => {
      const center: WorldPoint = { x: 0.5, y: 0.5 };
      const tiles = MapMath.visibleTiles('radar', '{z}/{x}/{y}', center, 9, 7, 300, 300);
      expect(tiles[0].size).assertEqual(1024);
      expect(tiles[0].url.startsWith('7/')).assertTrue();
    });
  });
}
