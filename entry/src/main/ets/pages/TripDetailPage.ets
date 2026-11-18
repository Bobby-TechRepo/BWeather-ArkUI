import { uniformTypeDescriptor } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { systemShare } from '@kit.ShareKit';
import { AppContext, S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Colors, Palette } from '../common/Theme';
import { TripText } from '../common/TripText';
import { WeatherIcons } from '../common/Weather';
import { DayKind, PackingItem, Trip, TripDay, TripStop, TripTiming, TripUtil } from '../model/Trips';
import { Notifier } from '../data/Notifier';
import { PageHeader } from '../components/PageHeader';
import { AppModel } from '../state/AppModel';

/** One trip: day-by-day weather per stop, packing list, reminder and sharing (lib/screens/trips/trip_detail.dart). */
@ComponentV2
export struct TripDetailPage {
  @Local model: AppModel = AppModel.shared();
  @Local tripId: string = '';
  @Local refreshing: boolean = false;

  aboutToAppear(): void {
    this.tripId = this.model.ui.tripId;
    this.model.trips.refresh(this.tripId, false);
  }

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get trip(): Trip | undefined {
    return this.model.trips.trip(this.tripId);
  }

  get days(): TripDay[] {
    const trip = this.trip;
    return trip === undefined ? [] : this.model.trips.days(trip);
  }

  get packing(): PackingItem[] {
    return TripUtil.packingFor(this.days);
  }

  get packed(): string[] {
    return this.trip?.packed ?? [];
  }

  get hasTypical(): boolean {
    return this.days.some((day: TripDay) => day.kind === DayKind.Typical);
  }

  get failed(): boolean {
    const trip = this.trip;
    return trip !== undefined && trip.stops.some((stop: TripStop) => this.model.trips.failed.includes(stop.id));
  }

  get loading(): boolean {
    const trip = this.trip;
    return trip !== undefined && trip.stops.some((stop: TripStop) => this.model.trips.loading.includes(stop.id));
  }

  get title(): string {
    return this.trip?.name ?? '';
  }

  get dates(): string {
    const trip = this.trip;
    return trip === undefined ? '' : TripText.datesAndLength(trip);
  }

  get upcoming(): boolean {
    const trip = this.trip;
    return trip !== undefined && TripUtil.timing(trip) === TripTiming.Upcoming;
  }

  get remind(): boolean {
    return this.trip?.remind ?? false;
  }

  /** Turning the reminder on asks for notification permission first. */
  async setReminder(on: boolean): Promise<void> {
    if (on) {
      const context = AppContext.ability;
      const granted = context !== undefined && await Notifier.requestPermission(context);
      if (!granted) {
        this.model.ui.showSnack(S.get($r('app.string.notifyPermissionDenied')));
        return;
      }
    }
    this.model.trips.setReminder(this.tripId, on);
    this.model.syncBackgroundWork();
  }

  get timing(): string {
    const trip = this.trip;
    return trip === undefined ? '' : TripText.timing(trip);
  }

  /** Whether [index] is the first day at a new stop (shows the stop header). */
  newStop(index: number): boolean {
    const days = this.days;
    return index === 0 || days[index - 1].stop.id !== days[index].stop.id;
  }

  share(): void {
    const trip = this.trip;
    const context = AppContext.ability;
    if (trip === undefined || context === undefined) {
      return;
    }
    try {
      const data = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        content: TripText.share(trip, this.days),
        title: trip.name
      });
      const controller = new systemShare.ShareController(data);
      controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      }).catch((error: Object) => {
        hilog.warn(0x0000, 'Trips', 'Share failed: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.warn(0x0000, 'Trips', 'Share unavailable: %{public}s', JSON.stringify(error));
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.title, palette: this.palette }) {
          this.actions()
        }
        Refresh({ refreshing: this.refreshing }) {
          List() {
            ListItem() {
              this.summary()
            }

            ForEach(this.days, (day: TripDay, index: number) => {
              ListItem() {
                Column() {
                  if (this.newStop(index)) {
                    this.stopHeader(day.stop)
                  }
                  this.dayRow(day)
                }
                .constraintSize({ maxWidth: 720 })
                .padding({ left: 16, right: 16 })
                .width('100%')
              }
            }, (day: TripDay) => JSON.stringify(day))

            ListItem() {
              this.footer()
            }
          }
          .alignListItem(ListItemAlign.Center)
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        }
        .onRefreshing(() => {
          this.refreshing = true;
          this.model.trips.refresh(this.tripId, true).finally(() => {
            this.refreshing = false;
          });
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(this.palette.surfaceLowest)
  }

  @Builder
  actions() {
    Row({ space: 4 }) {
      Image($r('app.media.ic_share'))
        .width(24)
        .height(24)
        .fillColor(this.palette.onSurface)
        .margin(8)
        .accessibilityText(S.get($r('app.string.shareTrip')))
        .onClick(() => this.share())
      Image($r('app.media.ic_edit'))
        .width(24)
        .height(24)
        .fillColor(this.palette.onSurface)
        .margin(8)
        .accessibilityText(S.get($r('app.string.editTrip')))
        .onClick(() => {
          this.model.ui.editingTripId = this.tripId;
          this.model.nav.pushPathByName('trip-edit', null);
        })
    }
  }

  @Builder
  summary() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_date_range')).width(18).height(18).fillColor(this.palette.onSurfaceVariant)
          Text(this.dates).fontSize(14).fontColor(this.palette.onSurface)
        }
        .padding({ left: 10, right: 12, top: 6, bottom: 6 })
        .border({ width: 1, color: this.palette.outlineVariant, radius: 8 })
        .margin({ right: 8, bottom: 8 })
        Text(this.timing)
          .fontSize(14)
          .fontColor(this.palette.onSurface)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .border({ width: 1, color: this.palette.outlineVariant, radius: 8 })
          .margin({ right: 8, bottom: 8 })
        if (this.loading) {
          LoadingProgress().width(20).height(20).color(this.palette.primary).margin({ bottom: 8 })
        }
      }
      if (this.failed) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_cloud_off')).width(18).height(18).fillColor(this.palette.error)
          Text($r('app.string.couldNotRefresh')).fontSize(14).fontColor(this.palette.error).layoutWeight(1)
          Button($r('app.string.retry'), { buttonStyle: ButtonStyleMode.TEXTUAL })
            .fontColor(this.palette.primary)
            .onClick(() => {
              this.model.trips.refresh(this.tripId, true);
            })
        }
        .width('100%')
      }
      if (this.upcoming) {
        Row({ space: 16 }) {
          Image($r('app.media.ic_notifications')).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
          Column({ space: 2 }) {
            Text($r('app.string.tripReminder')).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
            Text($r('app.string.tripReminderDetail')).fontSize(13).fontColor(this.palette.onSurfaceVariant)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.remind })
            .selectedColor(this.palette.primary)
            .onChange((isOn: boolean) => {
              if (isOn !== this.remind) {
                this.setReminder(isOn);
              }
            })
        }
        .padding({ left: 16, right: 12, top: 12, bottom: 12 })
        .margin({ top: 12 })
        .borderRadius(16)
        .backgroundColor(this.palette.surfaceLow)
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: 720 })
    .padding({ left: 16, right: 16, top: 8 })
    .width('100%')
  }

  @Builder
  stopHeader(stop: TripStop) {
    Row({ space: 6 }) {
      Image($r('app.media.ic_pin')).width(20).height(20).fillColor(this.palette.primary)
      Text(stop.city.name)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .layoutWeight(1)
      Text(TripText.dateRange(stop.arrive, stop.depart)).fontSize(12).fontColor(this.palette.onSurfaceVariant)
    }
    .padding({ top: 16, bottom: 8 })
    .width('100%')
  }

  @Builder
  dayRow(day: TripDay) {
    Row({ space: 12 }) {
      Row() {
        if (day.kind === DayKind.Forecast && day.daily !== undefined) {
          Image(WeatherIcons.icon(day.daily.weatherCode, false)).width(40).height(40).objectFit(ImageFit.Contain)
        } else if (day.kind === DayKind.Typical) {
          Image($r('app.media.ic_history')).width(28).height(28).fillColor(this.palette.onSurfaceVariant)
        } else {
          Image($r('app.media.ic_more_horiz')).width(28).height(28).fillColor(this.palette.onSurfaceVariant)
        }
      }
      .justifyContent(FlexAlign.Center)
      .width(44)

      Column() {
        Text(Format.dayDate(day.date)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
        Text(this.condition(day))
          .fontSize(12)
          .fontColor(this.palette.onSurfaceVariant)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (day.leaving !== undefined) {
          Text(S.get($r('app.string.travelDay'), day.leaving.city.name))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette.primary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        if (this.range(day).length > 0) {
          Text(this.range(day)).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
        }
        if (this.rain(day).length > 0) {
          Row({ space: 2 }) {
            Image($r('app.media.ic_water_drop')).width(14).height(14).fillColor(this.palette.primary)
            Text(this.rain(day)).fontSize(12).fontColor(this.palette.primary)
          }
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(16)
    .backgroundColor(this.palette.surfaceLow)
    .margin({ bottom: 8 })
    .width('100%')
  }

  condition(day: TripDay): string {
    if (day.kind === DayKind.Forecast && day.daily !== undefined) {
      return S.get(WeatherIcons.describe(day.daily.weatherCode));
    }
    return day.kind === DayKind.Typical ? S.get($r('app.string.typicalWeather')) : S.get($r('app.string.weatherUnknown'));
  }

  range(day: TripDay): string {
    if (day.kind === DayKind.Forecast && day.daily !== undefined) {
      return `${Format.temp(day.daily.temperatureMax.value)}° / ${Format.temp(day.daily.temperatureMin.value)}°`;
    }
    if (day.kind === DayKind.Typical && day.high !== undefined && day.low !== undefined) {
      return `${Format.temp(day.high)}° / ${Format.temp(day.low)}°`;
    }
    return '';
  }

  rain(day: TripDay): string {
    const probability = day.daily?.precipitationProbabilityMax;
    return day.kind === DayKind.Forecast && probability !== undefined ? `${Math.round(probability.value)}%` : '';
  }

  @Builder
  footer() {
    Column() {
      if (this.hasTypical) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_info')).width(18).height(18).fillColor(this.palette.onSurfaceVariant)
          Text(S.get($r('app.string.typicalWeatherNote'), `${TripUtil.FORECAST_DAYS}`))
            .fontSize(12)
            .fontColor(this.palette.onSurfaceVariant)
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .margin({ top: 12 })
      }

      Text($r('app.string.packingList'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .margin({ top: 24, bottom: 8 })

      Column() {
        if (this.packing.length === 0) {
          Row({ space: 16 }) {
            Image($r('app.media.ic_check_circle')).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
            Text($r('app.string.packingEmpty')).fontSize(15).fontColor(this.palette.onSurface).layoutWeight(1)
          }
          .padding(16)
          .width('100%')
        } else {
          ForEach(this.packing, (item: PackingItem, index: number) => {
            if (index > 0) {
              Divider().color(Colors.alpha(this.palette.outlineVariant, 0.5)).margin({ left: 56 })
            }
            Row({ space: 12 }) {
              Checkbox({ name: item, group: 'packing' })
                .select(this.packed.includes(item))
                .selectedColor(this.palette.primary)
                .onChange((checked: boolean) => {
                  if (checked !== this.packed.includes(item)) {
                    this.model.trips.togglePacked(this.tripId, item);
                  }
                })
              Text(TripText.packingItem(item))
                .fontSize(15)
                .fontColor(this.palette.onSurface)
                .decoration({
                  type: this.packed.includes(item) ? TextDecorationType.LineThrough : TextDecorationType.None,
                  color: this.palette.onSurfaceVariant
                })
                .layoutWeight(1)
            }
            .padding({ left: 12, right: 16, top: 10, bottom: 10 })
            .width('100%')
            .onClick(() => {
              this.model.trips.togglePacked(this.tripId, item);
            })
          }, (item: PackingItem) => item)
        }
      }
      .borderRadius(20)
      .backgroundColor(this.palette.surfaceLow)
      .clip(true)
      .width('100%')

      Column().height(32 + this.model.ui.bottomInset)
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: 720 })
    .padding({ left: 16, right: 16 })
    .width('100%')
  }
}
