import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Messages } from '../common/Messages';
import { Colors, Palette } from '../common/Theme';
import { AirQualityUtil, ForecastUtil } from '../model/ForecastUtil';
import { AirQuality, AqiLevel, Forecast, MinutelyPrecipitation, Pollen, UvLevel } from '../model/Models';
import { RainOutlook, RainOutlooks, RainTrend } from '../model/RainOutlook';
import { Tip, TipsEngine } from '../model/Tips';

interface DetailTile {
  title: Resource;
  value: string;
  icon: Resource;
}

/** Grid of secondary conditions for the current hour / today (lib/components/details_section.dart). */
@ComponentV2
export struct DetailsGrid {
  @Require @Param forecast: Forecast;
  @Require @Param palette: Palette;

  get tiles(): DetailTile[] {
    const current = this.forecast.current;
    const today = ForecastUtil.today(this.forecast);
    const hour = ForecastUtil.currentHour(this.forecast);
    const rainToday = today?.precipitationSum;
    const tiles: DetailTile[] = [
      {
        title: $r('app.string.windDirection'),
        value: `${Format.compassPoint(current.windDirection.value)} ${Math.round(current.windDirection.value)}${current.windDirection.unit}`,
        icon: $r('app.media.det_compass')
      },
      {
        title: $r('app.string.windGusts'),
        value: `${Math.round(current.windGusts.value)} ${current.windGusts.unit}`,
        icon: $r('app.media.det_wind')
      },
      {
        title: $r('app.string.rainToday'),
        value: rainToday === undefined ? `${current.rain.value} ${current.rain.unit}` :
          `${rainToday.value.toFixed(1)} ${rainToday.unit}`,
        icon: $r('app.media.det_umbrella')
      },
      {
        title: $r('app.string.pressure'),
        value: `${Math.round(current.surfacePressure.value)} ${current.surfacePressure.unit}`,
        icon: $r('app.media.det_pressure')
      },
      {
        title: $r('app.string.cloudCover'),
        value: `${Math.round(current.cloudCover.value)}${current.cloudCover.unit}`,
        icon: $r('app.media.det_cloud')
      },
      {
        title: $r('app.string.dewPoint'),
        value: hour === undefined ? '--' : `${Format.temp(hour.dewPoint.value)}${hour.dewPoint.unit}`,
        icon: $r('app.media.det_droplet')
      }
    ];
    return tiles;
  }

  build() {
    Column({ space: 10 }) {
      ForEach([0, 2, 4], (start: number) => {
        Row({ space: 10 }) {
          this.tile(this.tiles[start])
          this.tile(this.tiles[start + 1])
        }
        .width('100%')
      }, (start: number) => `${start}`)
    }
    .width('100%')
  }

  @Builder
  tile(tile: DetailTile) {
    Row({ space: 10 }) {
      Image(tile.icon).width(36).height(36).objectFit(ImageFit.Contain)
      Column() {
        Text(tile.value)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette.onSurface)
          .maxLines(1)
          .minFontSize(10)
          .maxFontSize(16)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(tile.title)
          .fontSize(12)
          .fontColor(this.palette.onSurfaceVariant)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding(12)
    .height(72)
    .borderRadius(16)
    .backgroundColor(this.palette.surfaceLow)
    .layoutWeight(1)
    .accessibilityText(`${S.get(tile.title)}: ${tile.value}`)
  }
}

/** Air quality (US AQI, PM2.5, PM10, dust), UV index and pollen (lib/components/air_quality_card.dart). */
@ComponentV2
export struct AirQualityCard {
  @Require @Param air: AirQuality;
  @Require @Param palette: Palette;

  get aqiLevel(): AqiLevel | undefined {
    return AirQualityUtil.aqiLevel(this.air);
  }

  get uvLevel(): UvLevel | undefined {
    return AirQualityUtil.uvLevel(this.air);
  }

  get pollen(): Pollen[] {
    return this.air.pollen.filter((entry: Pollen) => entry.value >= 1);
  }

  micrograms(value: number | undefined): string {
    return value === undefined ? '--' : `${Math.round(value)} µg/m³`;
  }

  build() {
    Column() {
      Text($r('app.string.airQuality')).fontSize(16).fontColor(this.palette.primary).margin({ bottom: 10 })

      if (this.air.usAqi !== undefined && this.aqiLevel !== undefined) {
        Row({ space: 12 }) {
          Text(`${this.air.usAqi}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor(Colors.aqi(this.aqiLevel!))
          Column() {
            Text(Messages.aqi(this.aqiLevel!)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
            Text($r('app.string.airQualityIndex', `${this.air.usAqi}`)).fontSize(12).fontColor(this.palette.onSurfaceVariant)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .margin({ bottom: 12 })
      }

      Flex({ wrap: FlexWrap.Wrap }) {
        this.metric(S.get($r('app.string.pm25')), this.micrograms(this.air.pm25), this.palette.onSurface)
        this.metric(S.get($r('app.string.pm10')), this.micrograms(this.air.pm10), this.palette.onSurface)
        this.metric(S.get($r('app.string.dust')), this.micrograms(this.air.dust), this.palette.onSurface)
        if (this.air.uvIndex !== undefined && this.uvLevel !== undefined) {
          this.metric(S.get($r('app.string.uvIndex')),
            `${Math.round(this.air.uvIndex!)} · ${S.get(Messages.uv(this.uvLevel!))}`, Colors.uv(this.uvLevel!))
        }
      }

      if (this.air.dust !== undefined && this.air.dust >= AirQualityUtil.DUST_WARNING) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_mask')).width(18).height(18).fillColor(this.palette.error)
          Text($r('app.string.harmattanDustHint')).fontSize(12).fontColor(this.palette.error).layoutWeight(1)
        }
        .margin({ top: 10 })
      }

      if (this.pollen.length > 0) {
        Text($r('app.string.pollen'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette.onSurface)
          .margin({ top: 12, bottom: 4 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.pollen, (entry: Pollen) => {
            this.metric(Messages.pollen(entry.key), `${Math.round(entry.value)}`, this.palette.onSurface)
          }, (entry: Pollen) => `${entry.key}|${entry.value}`)
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(20)
    .backgroundColor(this.palette.surfaceLow)
    .width('100%')
  }

  @Builder
  metric(label: string, value: string, color: string) {
    Column() {
      Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(color)
      Text(label).fontSize(12).fontColor(this.palette.onSurfaceVariant)
    }
    .alignItems(HorizontalAlign.Start)
    .margin({ right: 16, bottom: 8 })
  }
}

/** "Today's tips": what to wear, umbrella, laundry, best time outdoors... */
@ComponentV2
export struct TipsCard {
  @Require @Param forecast: Forecast;
  @Require @Param palette: Palette;

  get tips(): Tip[] {
    return TipsEngine.tips(this.forecast);
  }

  build() {
    Column() {
      if (this.tips.length > 0) {
        Text($r('app.string.tipsTitle')).fontSize(16).fontColor(this.palette.primary).margin({ bottom: 8 })
        ForEach(this.tips, (tip: Tip) => {
          Row({ space: 10 }) {
            Image(TipsEngine.icon(tip.kind)).width(20).height(20).fillColor(this.palette.secondary)
            Text(tip.text).fontSize(14).fontColor(this.palette.onSurface).layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .padding({ top: 5, bottom: 5 })
        }, (tip: Tip) => `${tip.kind}|${tip.text}`)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(this.tips.length > 0 ? 14 : 0)
    .borderRadius(20)
    .backgroundColor(this.palette.surfaceLow)
    .width('100%')
  }
}

/** "Rain starting in about 20 min" with bars for the next 2 hours (lib/components/minutely_rain.dart). */
@ComponentV2
export struct MinutelyRainCard {
  @Require @Param forecast: Forecast;
  @Require @Param palette: Palette;

  get steps(): MinutelyPrecipitation[] {
    return ForecastUtil.upcomingMinutely(this.forecast);
  }

  get shown(): MinutelyPrecipitation[] {
    return this.steps.slice(0, 8);
  }

  get outlook(): RainOutlook {
    return RainOutlooks.from(this.steps, ForecastUtil.localNow(this.forecast));
  }

  /** Bars scale to the wettest step, but never below "moderate", so drizzle looks small. */
  get peak(): number {
    const steps = this.steps;
    let peak = steps.length > 0 && steps[0].unit.toLowerCase().includes('inch') ? 0.04 : 1.0;
    for (const step of this.shown) {
      peak = Math.max(peak, step.precipitation);
    }
    return peak;
  }

  barHeight(step: MinutelyPrecipitation): number {
    if (!RainOutlooks.isWet(step)) {
      return 2;
    }
    return Math.max(4, 44 * Math.min(1, step.precipitation / this.peak));
  }

  get endLabel(): string {
    const shown = this.shown;
    return shown.length === 0 ? '' : Format.clock(shown[shown.length - 1].time + 15 * 60000);
  }

  build() {
    Column() {
      if (this.steps.length > 0) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_umbrella')).width(20).height(20)
            .fillColor(this.outlook.trend === RainTrend.None ? this.palette.onSurfaceVariant : this.palette.primary)
          Text(Messages.rainOutlook(this.outlook)).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(this.palette.onSurface).layoutWeight(1)
        }
        Row() {
          ForEach(this.shown, (step: MinutelyPrecipitation) => {
            Column()
              .height(this.barHeight(step))
              .layoutWeight(1)
              .margin({ left: 2, right: 2 })
              .borderRadius(3)
              .backgroundColor(RainOutlooks.isWet(step) ? this.palette.primary : this.palette.outlineVariant)
              .accessibilityText(`${Format.clock(step.time)}: ${step.precipitation} ${step.unit}`)
          }, (step: MinutelyPrecipitation) => JSON.stringify(step))
        }
        .height(44)
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 10 })
        Row() {
          Text($r('app.string.now')).fontSize(12).fontColor(this.palette.onSurfaceVariant)
          Blank()
          Text($r('app.string.nextTwoHours')).fontSize(12).fontColor(this.palette.onSurfaceVariant)
          Blank()
          Text(this.endLabel).fontSize(12).fontColor(this.palette.onSurfaceVariant)
        }
        .width('100%')
        .margin({ top: 6 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(this.steps.length > 0 ? 14 : 0)
    .borderRadius(20)
    .backgroundColor(Colors.alpha(this.palette.surfaceLow, 0.92))
    .width('100%')
  }
}
