import { Format } from '../common/Format';
import { Palette } from '../common/Theme';
import { TripText } from '../common/TripText';
import { Sky, WeatherIcons } from '../common/Weather';
import { S } from '../common/AppContext';
import { Trip, TripOutlook, TripStop, TripTiming, TripUtil } from '../model/Trips';
import { AppModel } from '../state/AppModel';

const WHITE: string = '#FFFFFF';
const SOFT_WHITE: string = '#D1FFFFFF';

/**
 * A trip in the Trips list: name, dates, stops and a one-line weather outlook,
 * tinted by the most common forecast sky (lib/components/trip_card.dart).
 */
@ComponentV2
export struct TripCard {
  @Param tripId: string = '';
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get trip(): Trip | undefined {
    return this.model.trips.trip(this.tripId);
  }

  get outlook(): TripOutlook | undefined {
    const trip = this.trip;
    return trip === undefined ? undefined : TripUtil.outlook(this.model.trips.days(trip));
  }

  get code(): number {
    return this.outlook?.commonCode ?? -1;
  }

  /** Sky colours for upcoming and current trips with a forecast; plain card otherwise. */
  get tinted(): boolean {
    const trip = this.trip;
    return this.code >= 0 && trip !== undefined && TripUtil.timing(trip) !== TripTiming.Past;
  }

  get foreground(): string {
    return this.tinted ? WHITE : this.palette.onSurface;
  }

  get soft(): string {
    return this.tinted ? SOFT_WHITE : this.palette.onSurfaceVariant;
  }

  get colors(): string[] {
    return this.tinted ? Sky.gradient(Sky.scene(this.code, true)) : [this.palette.surfaceLow, this.palette.surfaceLow];
  }

  get loading(): boolean {
    const trip = this.trip;
    return trip !== undefined && trip.stops.some((stop: TripStop) => this.model.trips.loading.includes(stop.id));
  }

  get name(): string {
    return this.trip?.name ?? '';
  }

  get dates(): string {
    const trip = this.trip;
    return trip === undefined ? '' : TripText.datesAndLength(trip);
  }

  get route(): string {
    const trip = this.trip;
    return trip === undefined ? '' : trip.stops.map((stop: TripStop) => stop.city.name).join('  →  ');
  }

  get timing(): string {
    const trip = this.trip;
    return trip === undefined ? '' : TripText.timing(trip);
  }

  get range(): string {
    const outlook = this.outlook;
    if (outlook === undefined || outlook.low === undefined || outlook.high === undefined) {
      return '';
    }
    return S.get($r('app.string.tripOutlookRange'), `${Format.temp(outlook.low)}°`, `${Format.temp(outlook.high)}°`);
  }

  get rain(): string {
    const outlook = this.outlook;
    return outlook === undefined || outlook.forecastDays === 0 ? '' : TripText.rainyDays(outlook.rainyDays);
  }

  get condition(): string {
    const outlook = this.outlook;
    return this.code < 0 || outlook === undefined || outlook.forecastDays === 0 ? '' :
      S.get(WeatherIcons.describe(this.code));
  }

  build() {
    Column() {
      if (this.trip !== undefined) {
        Column() {
          Row() {
            Column({ space: 2 }) {
              Text(this.name)
                .fontSize(21)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.foreground)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.dates).fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.soft)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            if (this.code >= 0) {
              Image(WeatherIcons.icon(this.code, false)).width(48).height(48).objectFit(ImageFit.Contain)
            }
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')

          Text(this.route)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.foreground)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 12 })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            this.pill(this.timing)
            if (this.range.length > 0) {
              this.pill(this.range)
            }
            if (this.rain.length > 0) {
              this.pill(this.rain)
            }
            if (this.condition.length > 0) {
              Text(this.condition).fontSize(12).fontColor(this.soft).margin({ right: 8, bottom: 6 })
            }
            if (this.loading) {
              LoadingProgress().width(16).height(16).color(this.foreground).margin({ bottom: 6 })
            }
          }
          .margin({ top: 12 })
        }
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .borderRadius(24)
        .linearGradient({ angle: 135, colors: [[this.colors[0], 0], [this.colors[1], 1]] })
        .width('100%')
        .onClick(() => {
          this.model.ui.tripId = this.tripId;
          this.model.nav.pushPathByName('trip', null);
        })
      }
    }
    .width('100%')
  }

  @Builder
  pill(text: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.foreground)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(20)
      .backgroundColor(this.tinted ? '#2EFFFFFF' : this.palette.surfaceHigh)
      .margin({ right: 8, bottom: 6 })
  }
}
