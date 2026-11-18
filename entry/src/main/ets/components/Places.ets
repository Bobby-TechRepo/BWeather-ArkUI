import { S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Messages } from '../common/Messages';
import { Colors, Palette } from '../common/Theme';
import { Sky, SkyScene, SkyKind, WeatherIcons } from '../common/Weather';
import { ForecastUtil } from '../model/ForecastUtil';
import { Daily, Forecast, Hourly } from '../model/Models';
import { AppModel } from '../state/AppModel';
import { CityState, LocationIssue, States, Status } from '../state/StateTypes';
import { CardShimmer } from './Placeholders';

const WHITE: string = '#FFFFFF';
const SOFT_WHITE: string = '#D1FFFFFF';

/**
 * Card for one place, tinted by the sky there: name, local time, conditions,
 * temperature, today's high/low and the next hours (lib/components/location.dart).
 */
@ComponentV2
export struct LocationCard {
  @Require @Param place: CityState;
  /** Narrow layout for the desktop side panel. */
  @Param compact: boolean = false;
  @Require @Param palette: Palette;
  @Local model: AppModel = AppModel.shared();

  get forecast(): Forecast | undefined {
    return this.place.city.forecast;
  }

  get scene(): SkyScene {
    const current = this.forecast?.current;
    if (current === undefined) {
      const overcast: SkyScene = { kind: SkyKind.Overcast, night: false };
      return overcast;
    }
    return Sky.scene(current.weatherCode, current.isDay);
  }

  get colors(): string[] {
    return Sky.gradient(this.scene);
  }

  get today(): Daily | undefined {
    const forecast = this.forecast;
    return forecast === undefined ? undefined : ForecastUtil.today(forecast);
  }

  get hours(): Hourly[] {
    const forecast = this.forecast;
    return forecast === undefined ? [] : ForecastUtil.upcomingHours(forecast, this.compact ? 4 : 6);
  }

  get subtitle(): string {
    const parts: string[] = [];
    if (States.isCurrentLocation(this.place)) {
      parts.push(S.get(this.place.approximate ? $r('app.string.approximateLocation') : $r('app.string.yourLocation')));
    }
    const forecast = this.forecast;
    if (forecast !== undefined) {
      parts.push(Format.clock(ForecastUtil.localNow(forecast)));
    }
    return parts.join(' · ');
  }

  get condition(): string {
    const current = this.forecast?.current;
    return current === undefined ? S.get($r('app.string.forecastUnavailable')) : S.get(WeatherIcons.describe(current.weatherCode));
  }

  get temperature(): string {
    const current = this.forecast?.current;
    return current === undefined ? '--' : `${Format.temp(current.temperature.value)}°`;
  }

  get range(): string {
    const today = this.today;
    return today === undefined ? '' :
      S.get($r('app.string.widgetRange'), `${Format.temp(today.temperatureMax.value)}°`, `${Format.temp(today.temperatureMin.value)}°`);
  }

  get canRemove(): boolean {
    return !States.isCurrentLocation(this.place);
  }

  build() {
    Column() {
      if (this.forecast === undefined && this.place.status !== Status.Failure) {
        CardShimmer({ palette: this.palette })
      } else {
        this.card()
      }
    }
    .width('100%')
  }

  @Builder
  card() {
    Column() {
      Row() {
        Column() {
          Row({ space: 6 }) {
            if (States.isCurrentLocation(this.place)) {
              Image($r('app.media.ic_near_me')).width(16).height(16).fillColor(WHITE)
            }
            Text(this.place.city.name)
              .fontSize(this.compact ? 17 : 21)
              .fontWeight(FontWeight.Medium)
              .fontColor(WHITE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textShadow({ radius: 6, color: '#40000000', offsetX: 0, offsetY: 0 })
              .flexShrink(1)
          }
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(SOFT_WHITE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(this.condition)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(WHITE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: this.compact ? 10 : 18 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.forecast !== undefined) {
          Image(WeatherIcons.icon(this.forecast.current.weatherCode, !this.forecast.current.isDay))
            .width(this.compact ? 40 : 52)
            .height(this.compact ? 40 : 52)
            .objectFit(ImageFit.Contain)
            .margin({ top: 2, right: 4 })
        }
        Column() {
          Text(this.temperature)
            .fontSize(this.compact ? 32 : 36)
            .fontWeight(300)
            .fontColor(WHITE)
            .textShadow({ radius: 6, color: '#40000000', offsetX: 0, offsetY: 0 })
          if (this.range.length > 0) {
            Text(this.range)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(SOFT_WHITE)
              .margin({ top: 6 })
          }
        }
        .alignItems(HorizontalAlign.End)

        if (this.canRemove) {
          Image($r('app.media.ic_more_vert'))
            .width(20)
            .height(20)
            .fillColor(WHITE)
            .margin({ left: 6, top: 4 })
            .accessibilityText(S.get($r('app.string.removeCity'), this.place.city.name))
            .bindMenu([
              {
                value: S.get($r('app.string.removeCity'), this.place.city.name),
                icon: $r('app.media.ic_delete'),
                action: () => {
                  removePlace(this.place.key);
                }
              }
            ])
        } else {
          Column().width(10)
        }
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')

      if (this.place.status === Status.Loading) {
        Progress({ value: 100, total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 2, enableScanEffect: true })
          .color(WHITE)
          .backgroundColor('#33FFFFFF')
          .width('100%')
          .margin({ top: 10 })
      }

      if (this.forecast !== undefined && this.hours.length > 0) {
        Divider()
          .color('#40FFFFFF')
          .margin({ top: this.compact ? 10 : 14, bottom: this.compact ? 8 : 10 })
        Row() {
          ForEach(this.hours, (hour: Hourly) => {
            Column({ space: 2 }) {
              Text(Format.hour(hour.time)).fontSize(11).fontColor(SOFT_WHITE).maxLines(1)
              Image(WeatherIcons.icon(hour.weatherCode, this.forecast === undefined ? false : ForecastUtil.isNight(this.forecast, hour)))
                .width(this.compact ? 24 : 28)
                .height(this.compact ? 24 : 28)
                .objectFit(ImageFit.Contain)
                .margin({ top: 2 })
              Text(`${Format.temp(hour.temperature.value)}°`).fontSize(14).fontWeight(FontWeight.Medium).fontColor(WHITE)
            }
            .layoutWeight(1)
          }, (hour: Hourly) => JSON.stringify(hour))
        }
        .width('100%')
        .accessibilityLevel('no')
      }

      if (this.forecast === undefined && this.place.status === Status.Failure) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_refresh')).width(18).height(18).fillColor(WHITE)
          Text($r('app.string.retry')).fontSize(14).fontColor(WHITE)
        }
        .margin({ top: 8 })
        .onClick(() => {
          this.model.weather.refreshPlace(this.place.key);
        })
      }
    }
    .padding({
      left: this.compact ? 14 : 18,
      right: this.compact ? 10 : 12,
      top: this.compact ? 12 : 16,
      bottom: this.compact ? 12 : 16
    })
    .borderRadius(24)
    .linearGradient({ angle: 135, colors: [[this.colors[0], 0], [this.colors[1], 1]] })
    .shadow({ radius: 12, color: Colors.alpha(this.colors[0], 0.25), offsetX: 0, offsetY: 4 })
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText(this.forecast === undefined ? this.place.city.name :
      `${this.place.city.name}, ${S.get($r('app.string.semanticsCurrent'), Format.temp(this.forecast.current.temperature.value), this.condition)}`)
    .onClick(() => {
      this.model.ui.showPlace(this.place.key);
    })
  }
}

/** Removes a saved city and offers "Undo" (lib/components/location_list.dart). */
export function removePlace(key: string): void {
  const model = AppModel.shared();
  const index = model.weather.state.cities.findIndex((place: CityState) => place.key === key);
  if (index === -1) {
    return;
  }
  const place = model.weather.state.cities[index];
  model.weather.removeCity(key);
  model.ui.showSnack(S.get($r('app.string.cityRemoved'), place.city.name), S.get($r('app.string.undo')), () => {
    model.weather.restoreCity(place, index);
  });
}

/**
 * Saved places: the user's location pinned on top, then saved cities, which
 * can be reordered (long-press and drag), swiped away or removed from their menu.
 */
/**
 * ForEach keeps an item, and the place it was built with, for as long as its
 * key is unchanged. So the key includes what the card shows: a city added
 * while its forecast was loading would otherwise keep its loading card.
 */
function placeItemKey(place: CityState): string {
  const current = place.city.forecast?.current;
  return [place.key, place.status, `${place.updatedAt ?? 0}`, place.city.name,
    current?.temperature.unit ?? '', current?.windSpeed.unit ?? ''].join('|');
}

@ComponentV2
export struct LocationList {
  @Param compact: boolean = false;
  /** Cards never get wider than this; extra room becomes side margins. */
  @Param maxCardWidth: number = 720;
  @Local model: AppModel = AppModel.shared();
  @Local refreshing: boolean = false;
  @BuilderParam header: () => void = emptyHeader;

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get location(): CityState | undefined {
    return this.model.weather.state.location;
  }

  get cities(): CityState[] {
    return this.model.weather.state.cities;
  }

  get gap(): number {
    return this.compact ? 10 : 14;
  }


  build() {
    Refresh({ refreshing: this.refreshing }) {
      List() {
        ListItem() {
          this.header()
        }

        if (this.location === undefined && this.cities.length === 0) {
          ListItem() {
            Column({ space: 12 }) {
              Image($r('app.media.ic_globe')).width(56).height(56).fillColor(this.palette.primary)
              Text($r('app.string.noSavedPlaces'))
                .fontSize(16)
                .fontColor(this.palette.onSurface)
                .textAlign(TextAlign.Center)
            }
            .padding(32)
            .width('100%')
          }
        }

        if (this.location !== undefined) {
          ListItem() {
            this.centered(this.location!)
          }
          .padding({ bottom: this.gap, left: this.compact ? 12 : 16, right: this.compact ? 12 : 16 })
        }

        ForEach(this.cities, (place: CityState) => {
          ListItem() {
            this.centered(place)
          }
          .padding({ bottom: this.gap, left: this.compact ? 12 : 16, right: this.compact ? 12 : 16 })
          .swipeAction({
            end: {
              builder: () => {
                this.deleteArea();
              },
              actionAreaDistance: 72,
              onAction: () => {
                removePlace(place.key);
              }
            },
            edgeEffect: SwipeEdgeEffect.None
          })
        }, (place: CityState) => placeItemKey(place))
          .onMove((from: number, to: number) => {
            this.model.weather.reorderCity(from, to);
          })

        if (this.cities.length > 1) {
          ListItem() {
            Text($r('app.string.reorderHint'))
              .fontSize(12)
              .fontColor(this.palette.onSurfaceVariant)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 24, right: 24, top: 4 })
          }
        }

        ListItem() {
          Column().height(24 + this.model.ui.contentBottomInset)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .onRefreshing(() => {
      this.refreshing = true;
      this.model.weather.refreshAll(true).finally(() => {
        this.refreshing = false;
      });
    })
  }

  @Builder
  centered(place: CityState) {
    Row() {
      Column() {
        LocationCard({ place: place, compact: this.compact, palette: this.palette })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.maxCardWidth })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  deleteArea() {
    Row() {
      Image($r('app.media.ic_delete')).width(24).height(24).fillColor(this.palette.onError)
    }
    .justifyContent(FlexAlign.Center)
    .width(72)
    .height('100%')
    .borderRadius(24)
    .backgroundColor(this.palette.error)
    .margin({ left: 8 })
  }
}

@Builder
function emptyHeader() {
}

/** A tappable field that looks like search and opens the city search. */
@ComponentV2
export struct AddCityField {
  @Require @Param palette: Palette;
  @Event onTapField: () => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Image($r('app.media.ic_search')).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
      Text($r('app.string.searchForCity')).fontSize(16).fontColor(this.palette.onSurfaceVariant).layoutWeight(1)
      Image($r('app.media.ic_add_location')).width(24).height(24).fillColor(this.palette.primary)
    }
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(28)
    .backgroundColor(this.palette.surfaceHigh)
    .width('100%')
    .onClick(() => this.onTapField())
  }
}

/**
 * Slim banner above the forecast when the location is approximate (or
 * missing), offering the precise one (lib/components/location_banner.dart).
 */
@ComponentV2
export struct LocationBanner {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get approximate(): boolean {
    return this.model.weather.state.location?.approximate ?? false;
  }

  get show(): boolean {
    return States.locationBannerShown(this.model.weather.state);
  }

  get busy(): boolean {
    return this.model.weather.state.status === Status.Loading;
  }

  get blocked(): boolean {
    const issue = this.model.weather.state.locationIssue;
    return issue === LocationIssue.PermissionBlocked || issue === LocationIssue.ServiceDisabled;
  }

  get text(): string {
    return this.approximate ? S.get($r('app.string.approximateBanner')) :
      Messages.locationIssue(this.model.weather.state.locationIssue);
  }

  build() {
    Column() {
      if (this.show) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_location_searching')).width(18).height(18).fillColor(this.palette.onSecondaryContainer)
          Text(this.text).fontSize(13).fontColor(this.palette.onSecondaryContainer).layoutWeight(1)
          if (this.busy) {
            LoadingProgress().width(20).height(20).color(this.palette.onSecondaryContainer).margin(10)
          } else {
            Button(this.blocked ? $r('app.string.navSettings') : $r('app.string.usePrecise'), { buttonStyle: ButtonStyleMode.TEXTUAL })
              .fontColor(this.palette.onSecondaryContainer)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                if (this.blocked) {
                  this.model.weather.openLocationSettings();
                } else {
                  this.model.weather.useMyLocation();
                }
              })
          }
        }
        .padding({ left: 12, right: 4, top: 4 + this.model.ui.topInset, bottom: 4 })
        .width('100%')
        .backgroundColor(this.palette.secondaryContainer)
      }
    }
    .width('100%')
  }
}
