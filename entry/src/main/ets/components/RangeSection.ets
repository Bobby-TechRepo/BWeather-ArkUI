import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Palette } from '../common/Theme';
import { WeatherIcons } from '../common/Weather';
import { ForecastUtil } from '../model/ForecastUtil';
import { Daily, Forecast, Hourly } from '../model/Models';
import { HourlyChart } from './HourlyChart';
import { Segmented, SegmentOption } from './Segmented';

enum Range {
  Daily = 'daily',
  Hourly = 'hourly',
  Chart = 'chart'
}

/** The 16-day forecast, the next 24 hours, or a chart of them (lib/components/others.dart). */
@ComponentV2
export struct RangeSection {
  @Require @Param forecast: Forecast;
  @Require @Param palette: Palette;
  /** Phones line the switch up on the right, like the Flutter app. */
  @Param alignEnd: boolean = true;
  @Param sidePadding: number = 10;

  @Local range: string = Range.Daily;

  get options(): SegmentOption[] {
    const options: SegmentOption[] = [
      { value: Range.Daily, label: $r('app.string.daily') },
      { value: Range.Hourly, label: $r('app.string.hourly') },
      { value: Range.Chart, label: $r('app.string.chart') }
    ];
    return options;
  }

  get hours(): Hourly[] {
    return ForecastUtil.upcomingHours(this.forecast, 24);
  }

  get todayTime(): number {
    return ForecastUtil.today(this.forecast)?.time ?? -1;
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Segmented({
          options: this.options,
          selected: this.range,
          palette: this.palette,
          onSelect: (value: string) => {
            this.range = value;
          }
        })
      }
      .width('100%')
      .padding({ left: this.sidePadding, right: this.sidePadding })
      .justifyContent(this.alignEnd ? FlexAlign.End : FlexAlign.Start)

      if (this.range === Range.Chart) {
        HourlyChart({ hours: this.hours, palette: this.palette })
      } else if (this.range === Range.Hourly) {
        List() {
          ForEach(this.hours, (hour: Hourly, index: number) => {
            ListItem() {
              this.hourItem(hour, index === 0)
            }
          }, (hour: Hourly) => JSON.stringify(hour))
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .height(190)
        .width('100%')
        .contentStartOffset(this.sidePadding - 8)
      } else {
        List() {
          ForEach(this.forecast.daily, (day: Daily) => {
            ListItem() {
              this.dayItem(day)
            }
          }, (day: Daily) => `${this.todayTime}|${JSON.stringify(day)}`)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .height(190)
        .width('100%')
        .contentStartOffset(this.sidePadding - 8)
      }
    }
    .width('100%')
  }

  @Builder
  hourItem(hour: Hourly, isNow: boolean) {
    Column() {
      Text(isNow ? S.get($r('app.string.now')) : Format.hour(hour.time))
        .fontWeight(FontWeight.Bold)
        .fontSize(14)
        .fontColor(this.palette.onSurface)
      Image(WeatherIcons.icon(hour.weatherCode, ForecastUtil.isNight(this.forecast, hour)))
        .width(90)
        .height(80)
        .objectFit(ImageFit.Contain)
      Text(`${Format.temp(hour.temperature.value)}${hour.temperature.unit}`)
        .fontSize(19)
        .fontColor(this.palette.onSurfaceVariant)
      if (hour.precipitationProbability.value > 0) {
        Text(`💧 ${Math.round(hour.precipitationProbability.value)}${hour.precipitationProbability.unit}`)
          .fontSize(12)
          .fontColor(this.palette.primary)
      }
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .margin(8)
    .borderRadius(16)
    .backgroundColor(this.palette.surfaceLow)
    .accessibilityText(`${isNow ? S.get($r('app.string.now')) : Format.hour(hour.time)}: ` +
      `${S.get(WeatherIcons.describe(hour.weatherCode))}, ${Format.temp(hour.temperature.value)}${hour.temperature.unit}, ` +
      S.get($r('app.string.semanticsRainChance'), `${Math.round(hour.precipitationProbability.value)}`))
  }

  @Builder
  dayItem(day: Daily) {
    Column() {
      Text(day.time === this.todayTime ? S.get($r('app.string.today')) : Format.shortDay(day.time))
        .fontWeight(FontWeight.Bold)
        .fontSize(14)
        .fontColor(this.palette.onSurface)
      Image(WeatherIcons.icon(day.weatherCode, false))
        .width(90)
        .height(80)
        .objectFit(ImageFit.Contain)
      Text(`${Format.temp(day.temperatureMin.value)}° / ${Format.temp(day.temperatureMax.value)}${day.temperatureMax.unit}`)
        .fontSize(17)
        .fontColor(this.palette.onSurfaceVariant)
      if (day.precipitationProbabilityMax !== undefined && day.precipitationProbabilityMax.value > 0) {
        Text(`💧 ${Math.round(day.precipitationProbabilityMax.value)}${day.precipitationProbabilityMax.unit}`)
          .fontSize(12)
          .fontColor(this.palette.primary)
      }
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .margin(8)
    .borderRadius(16)
    .backgroundColor(this.palette.surfaceLow)
    .accessibilityText(S.get($r('app.string.semanticsDay'),
      day.time === this.todayTime ? S.get($r('app.string.today')) : Format.shortDay(day.time),
      S.get(WeatherIcons.describe(day.weatherCode)),
      `${Format.temp(day.temperatureMin.value)}${day.temperatureMin.unit}`,
      `${Format.temp(day.temperatureMax.value)}${day.temperatureMax.unit}`))
  }
}
