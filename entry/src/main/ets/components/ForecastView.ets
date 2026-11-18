import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Messages } from '../common/Messages';
import { Colors, Palette } from '../common/Theme';
import { Sky, SkyScene, WeatherIcons } from '../common/Weather';
import { ForecastUtil, NormalsUtil, CityUtil } from '../model/ForecastUtil';
import { Anomaly, Daily, Forecast, Hourly } from '../model/Models';
import { AppModel, RadarTarget } from '../state/AppModel';
import { CityState, States, Status } from '../state/StateTypes';
import { ErrorView, ForecastShimmer } from './Placeholders';
import { AirQualityCard, DetailsGrid, MinutelyRainCard, TipsCard } from './ForecastCards';
import { RangeSection } from './RangeSection';
import { SkyBackground } from './SkyBackground';
import { SunMoonCard } from './SunMoonCard';

/** Room for the details column beside the main reading. */
const WIDE_WIDTH: number = 760;

/** Full forecast for one place, looked up by its stable key (lib/components/forecast_view.dart). */
@ComponentV2
export struct ForecastView {
  @Param placeKey: string = '';
  /** Room for the status bar when the app is drawn edge to edge. */
  @Param topPadding: number = 0;
  @Local model: AppModel = AppModel.shared();
  @Local areaWidth: number = 360;

  get place(): CityState | undefined {
    return States.place(this.model.weather.state, this.placeKey);
  }

  get palette(): Palette {
    return this.model.ui.palette;
  }

  build() {
    Stack() {
      if (this.place === undefined) {
        Column()
      } else if (this.place.city.forecast === undefined) {
        if (this.place.status === Status.Failure) {
          ErrorView({
            message: Messages.forecastIssue(this.place.issue, this.place.city.name),
            palette: this.palette,
            onRetry: () => {
              this.model.weather.refreshPlace(this.placeKey);
            }
          })
        } else {
          ForecastShimmer({ palette: this.palette })
        }
      } else {
        ForecastContent({
          place: this.place,
          forecast: this.place.city.forecast,
          pageWidth: this.areaWidth,
          topPadding: this.topPadding,
          palette: this.palette,
          animate: this.model.settings.state.animatedBackground
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.place?.city.forecast === undefined ? this.topPadding : 0 })
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.areaWidth = Number(newArea.width);
    })
  }
}

@ComponentV2
struct ForecastContent {
  @Require @Param place: CityState;
  @Require @Param forecast: Forecast;
  @Param pageWidth: number = 360;
  @Param topPadding: number = 0;
  @Require @Param palette: Palette;
  @Param animate: boolean = true;
  @Local model: AppModel = AppModel.shared();
  @Local refreshing: boolean = false;

  get compact(): boolean {
    return this.pageWidth < 600;
  }

  get wide(): boolean {
    return this.pageWidth >= WIDE_WIDTH;
  }

  get scene(): SkyScene {
    return Sky.scene(this.forecast.current.weatherCode, this.forecast.current.isDay);
  }

  get today(): Daily | undefined {
    return ForecastUtil.today(this.forecast);
  }

  get currentHour(): Hourly | undefined {
    return ForecastUtil.currentHour(this.forecast);
  }

  get isCurrentLocation(): boolean {
    return States.isCurrentLocation(this.place);
  }

  get subtitle(): string {
    return CityUtil.subtitle(this.place.city);
  }

  /** Date and time at the place, not on this device. */
  get localTime(): string {
    const now = ForecastUtil.localNow(this.forecast);
    return `${Format.date(now)} · ${Format.clock(now)} (${Format.utcOffset(this.forecast.utcOffsetSeconds)})`;
  }

  get condition(): string {
    return S.get(WeatherIcons.describe(this.forecast.current.weatherCode));
  }

  get feelsLine(): string {
    const parts: string[] = [S.get($r('app.string.feelsLike'), `${Format.temp(this.forecast.current.apparentTemperature.value)}°`)];
    const today = this.today;
    if (today !== undefined) {
      parts.push(S.get($r('app.string.widgetRange'), `${Format.temp(today.temperatureMax.value)}°`,
        `${Format.temp(today.temperatureMin.value)}°`));
    }
    return parts.join('  ·  ');
  }

  get rainChance(): string {
    const hour = this.currentHour;
    return hour === undefined ? '--' :
      `${Math.round(hour.precipitationProbability.value)}${hour.precipitationProbability.unit}`;
  }

  get wind(): string {
    const current = this.forecast.current;
    return `${Math.round(current.windSpeed.value)} ${current.windSpeed.unit}`;
  }

  get windLabel(): string {
    return S.get($r('app.string.windWithDirection'), Format.compassPoint(this.forecast.current.windDirection.value));
  }

  get humidity(): string {
    const current = this.forecast.current;
    return `${Math.round(current.relativeHumidity.value)}${current.relativeHumidity.unit}`;
  }

  get differenceC(): number | undefined {
    return NormalsUtil.differenceC(this.forecast, this.place.normals);
  }

  get updated(): string {
    const updatedAt = this.place.updatedAt;
    return updatedAt === undefined ? '' : S.get($r('app.string.updatedAgo'), Format.age(updatedAt));
  }

  refresh(): void {
    this.model.weather.refreshPlace(this.place.key);
  }

  build() {
    Stack() {
      SkyBackground({
        kind: this.scene.kind,
        night: this.scene.night,
        dark: this.palette.dark,
        ink: this.palette.onSurface,
        animate: this.animate
      })

      Refresh({ refreshing: this.refreshing }) {
        Scroll() {
          Column() {
            this.statusStrip()
            Row() {
              Column() {
                this.header()
              }
              .layoutWeight(1)
              if (this.wide) {
                Column({ space: 10 }) {
                  this.sideCards()
                }
                .width(this.pageWidth >= 1100 ? 400 : 340)
                .padding({ right: 10 })
              }
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')
            .margin({ top: 20 })

            if (!this.wide && this.forecast.minutely.length > 0) {
              Column() {
                MinutelyRainCard({ forecast: this.forecast, palette: this.palette })
              }
              .padding({ left: 10, right: 10, bottom: 10 })
              .width('100%')
            }
            RangeSection({
              forecast: this.forecast,
              palette: this.palette,
              alignEnd: this.compact,
              sidePadding: this.pageWidth >= 1024 ? 20 : 10
            })
              .margin({ top: this.compact ? 10 : 30 })
            if (!this.wide) {
              Column({ space: 10 }) {
                DetailsGrid({ forecast: this.forecast, palette: this.palette })
                SunMoonCard({ forecast: this.forecast, latitude: this.place.city.latitude, palette: this.palette })
                TipsCard({ forecast: this.forecast, palette: this.palette })
                if (this.forecast.airQuality !== undefined) {
                  AirQualityCard({ air: this.forecast.airQuality, palette: this.palette })
                }
              }
              .padding({ left: 10, right: 10 })
            }
            Column().height(24 + this.model.ui.contentBottomInset)
          }
          .width('100%')
          .padding({ top: this.topPadding })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
      }
      .onRefreshing(() => {
        this.refreshing = true;
        this.model.weather.refreshPlace(this.place.key).finally(() => {
          this.refreshing = false;
        });
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  sideCards() {
    if (this.forecast.minutely.length > 0) {
      MinutelyRainCard({ forecast: this.forecast, palette: this.palette })
    }
    DetailsGrid({ forecast: this.forecast, palette: this.palette })
    SunMoonCard({ forecast: this.forecast, latitude: this.place.city.latitude, palette: this.palette })
    if (this.forecast.airQuality !== undefined) {
      AirQualityCard({ air: this.forecast.airQuality, palette: this.palette })
    }
    TipsCard({ forecast: this.forecast, palette: this.palette })
  }

  /** "Updated 5 min ago", a progress bar while refreshing, or a retry link after a failed refresh. */
  @Builder
  statusStrip() {
    if (this.place.status === Status.Loading) {
      Progress({ value: 100, total: 100, type: ProgressType.Linear })
        .style({ strokeWidth: 2, enableScanEffect: true })
        .color(this.palette.primary)
        .width('100%')
        .height(2)
    } else if (this.place.status === Status.Failure) {
      Row({ space: 4 }) {
        Image($r('app.media.ic_cloud_off')).width(14).height(14).fillColor(this.palette.error)
        Text(this.updated.length === 0 ? S.get($r('app.string.couldNotRefresh')) :
          `${S.get($r('app.string.couldNotRefresh'))} · ${this.updated}`)
          .fontSize(12)
          .fontColor(this.palette.error)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
        Button($r('app.string.retry'), { type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.TEXTUAL })
          .fontSize(13)
          .onClick(() => this.refresh())
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 4 })
    } else {
      Row({ space: 2 }) {
        Text(this.updated).fontSize(12).fontColor(this.palette.onSurfaceVariant)
        if (!this.compact) {
          Image($r('app.media.ic_refresh'))
            .width(18)
            .height(18)
            .fillColor(this.palette.onSurfaceVariant)
            .margin(6)
            .accessibilityText(S.get($r('app.string.refresh')))
            .onClick(() => this.refresh())
        }
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .padding({ top: 6 })
    }
  }

  @Builder
  header() {
    Row({ space: 6 }) {
      if (this.isCurrentLocation) {
        Image($r('app.media.ic_near_me'))
          .width(20)
          .height(20)
          .fillColor(this.palette.primary)
          .accessibilityText(S.get($r('app.string.yourLocation')))
      }
      Text(this.place.city.name)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .flexShrink(1)
    }
    .justifyContent(FlexAlign.Center)
    .padding({ left: 20, right: 20 })

    if (this.subtitle.length > 0) {
      Text(this.subtitle)
        .fontSize(14)
        .fontColor(this.palette.onSurfaceVariant)
        .textAlign(TextAlign.Center)
        .margin({ top: 2 })
    }
    Text(this.localTime)
      .fontSize(14)
      .fontColor(this.palette.onSurfaceVariant)
      .textAlign(TextAlign.Center)
      .margin({ top: 6 })
      .padding({ left: 20, right: 20 })

    Row({ space: 8 }) {
      Text(`${Format.temp(this.forecast.current.temperature.value)}°`)
        .fontSize(this.compact ? 88 : 104)
        .fontWeight(200)
        .fontColor(this.palette.onSurface)
        .maxLines(1)
        .minFontSize(40)
        .maxFontSize(this.compact ? 88 : 104)
        .flexShrink(1)
      Image(WeatherIcons.icon(this.forecast.current.weatherCode, !this.forecast.current.isDay))
        .width(this.compact ? 128 : 150)
        .height(this.compact ? 128 : 150)
        .objectFit(ImageFit.Contain)
    }
    .justifyContent(FlexAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(S.get($r('app.string.semanticsCurrent'), Format.temp(this.forecast.current.temperature.value), this.condition))

    Text(this.condition)
      .fontSize(22)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette.onSurface)
      .textAlign(TextAlign.Center)
      .padding({ left: 20, right: 20 })
    Text(this.feelsLine)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.palette.onSurfaceVariant)
      .textAlign(TextAlign.Center)
      .margin({ top: 4 })

    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      if (this.differenceC !== undefined) {
        this.comparisonChip(this.differenceC)
      }
      this.radarChip()
    }
    .padding({ left: 16, right: 16 })
    .margin({ top: 10 })
    .width('100%')

    this.stats()
  }

  /** "3° warmer than usual" against the 20-year average high for today. */
  @Builder
  comparisonChip(differenceC: number) {
    Row({ space: 6 }) {
      Image(this.anomalyIcon(differenceC)).width(18).height(18).fillColor(this.anomalyColor(differenceC))
      Text(this.anomalyLabel(differenceC)).fontSize(14).fontColor(this.palette.onSurface)
    }
    .padding({ left: 12, right: 14, top: 6, bottom: 6 })
    .border({ width: 1, color: Colors.alpha(this.anomalyColor(differenceC), 0.4), radius: 20 })
    .margin(4)
    .onClick(() => {
      const normals = this.place.normals;
      if (normals !== undefined) {
        this.model.ui.showSnack(S.get($r('app.string.tempNormalsSource'), `${normals.fromYear}`, `${normals.toYear}`));
      }
    })
  }

  /** Opens the rain radar on this place. */
  @Builder
  radarChip() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_radar')).width(18).height(18).fillColor(this.palette.primary)
      Text($r('app.string.radar')).fontSize(14).fontColor(this.palette.onSurface)
    }
    .padding({ left: 12, right: 14, top: 6, bottom: 6 })
    .border({ width: 1, color: this.palette.outlineVariant, radius: 20 })
    .margin(4)
    .onClick(() => {
      const target: RadarTarget = {
        latitude: this.place.city.latitude,
        longitude: this.place.city.longitude,
        name: this.place.city.name
      };
      this.model.ui.radarTarget = target;
      this.model.nav.pushPathByName('radar', null);
    })
  }

  anomalyIcon(differenceC: number): Resource {
    const anomaly = NormalsUtil.anomaly(differenceC);
    if (anomaly === Anomaly.Normal) {
      return $r('app.media.ic_thermostat');
    }
    return anomaly === Anomaly.Warmer || anomaly === Anomaly.MuchWarmer ? $r('app.media.ic_trending_up') :
      $r('app.media.ic_trending_down');
  }

  anomalyColor(differenceC: number): string {
    switch (NormalsUtil.anomaly(differenceC)) {
      case Anomaly.Normal:
        return this.palette.onSurfaceVariant;
      case Anomaly.MuchWarmer:
        return this.palette.error;
      case Anomaly.Warmer:
        return this.palette.tertiary;
      default:
        return this.palette.primary;
    }
  }

  anomalyLabel(differenceC: number): string {
    const degrees = `${NormalsUtil.degreesIn(differenceC, this.forecast.current.temperature.unit)}`;
    switch (NormalsUtil.anomaly(differenceC)) {
      case Anomaly.Normal:
        return S.get($r('app.string.tempAboutNormal'));
      case Anomaly.Warmer:
      case Anomaly.MuchWarmer:
        return S.get($r('app.string.tempWarmerThanUsual'), degrees);
      default:
        return S.get($r('app.string.tempCoolerThanUsual'), degrees);
    }
  }

  @Builder
  stats() {
    // Side space is padding on a wrapper: a full-width element with side margins would overflow the screen.
    Column() {
      this.statsRow()
    }
    .padding({ left: this.compact ? 12 : 20, right: this.compact ? 12 : 20 })
    .margin({ top: 20, bottom: 20 })
    .width('100%')
  }

  @Builder
  statsRow() {
    Row() {
      this.stat($r('app.media.ic_rain_chance'), this.rainChance, S.get($r('app.string.rainChance')))
      Divider().vertical(true).height(48).color(this.palette.outlineVariant)
      this.stat($r('app.media.ic_air'), this.wind, this.windLabel)
      Divider().vertical(true).height(48).color(this.palette.outlineVariant)
      this.stat($r('app.media.ic_water_drop'), this.humidity, S.get($r('app.string.humidity')))
    }
    .padding({ top: 14, bottom: 14, left: 8, right: 8 })
    .borderRadius(20)
    .backgroundColor(Colors.alpha(this.palette.surfaceLow, 0.85))
    .constraintSize({ maxWidth: 520 })
    .width('100%')
  }

  @Builder
  stat(icon: Resource, value: string, label: string) {
    Column({ space: 4 }) {
      Image(icon).width(22).height(22).fillColor(this.palette.primary)
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .maxLines(1)
        .minFontSize(10)
        .maxFontSize(16)
      Text(label)
        .fontSize(11)
        .fontColor(this.palette.onSurfaceVariant)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .accessibilityGroup(true)
    .accessibilityText(`${label}: ${value}`)
  }
}
