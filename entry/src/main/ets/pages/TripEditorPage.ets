import { S } from '../common/AppContext';
import { Palette } from '../common/Theme';
import { TripText } from '../common/TripText';
import { WallTime } from '../common/WallTime';
import { CityUtil } from '../model/ForecastUtil';
import { City } from '../model/Models';
import { Trip, TripProblem, TripStop, TripUtil } from '../model/Trips';
import { PageHeader } from '../components/PageHeader';
import { AppModel } from '../state/AppModel';
import { TripsStore } from '../state/TripsStore';

/** Calendar date shown by the date picker (device-local) for a wall-time date. */
function toLocalDate(wall: number): Date {
  const date = new Date(wall);
  return new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function fromLocalDate(date: Date): number {
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
}

/** Create a trip (editingTripId "") or edit one (lib/screens/trips/trip_editor.dart). */
@ComponentV2
export struct TripEditorPage {
  @Local model: AppModel = AppModel.shared();
  @Local name: string = '';
  @Local stops: TripStop[] = [];
  @Local problem: TripProblem = TripProblem.None;
  @Local original: Trip | undefined = undefined;

  aboutToAppear(): void {
    const id = this.model.ui.editingTripId;
    this.original = id.length === 0 ? undefined : this.model.trips.trip(id);
    this.name = this.original?.name ?? '';
    this.stops = this.original === undefined ? [] : this.original.stops.slice();
  }

  aboutToDisappear(): void {
    this.model.ui.pickCity = undefined;
  }

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get today(): number {
    return WallTime.deviceToday();
  }

  get problemText(): string {
    switch (this.problem) {
      case TripProblem.NoStops:
        return S.get($r('app.string.tripProblemNoStops'));
      case TripProblem.StopEndsBeforeItStarts:
      case TripProblem.StopsOverlap:
        return S.get($r('app.string.tripProblemOrder'));
      case TripProblem.TooLong:
        return S.get($r('app.string.tripProblemTooLong'), `${TripUtil.MAX_DAYS}`);
      default:
        return '';
    }
  }

  /** Opens the city search as a picker; [done] gets the chosen city. */
  pickCity(done: (city: City) => void): void {
    this.model.ui.pickCity = (city: City) => {
      this.model.ui.pickCity = undefined;
      // Let the search page close before showing anything else.
      setTimeout(() => done(city), 350);
    };
    this.model.nav.pushPathByName('cities', null);
  }

  /** Asks for the arrival date, then the departure date. */
  pickDates(arrive: number, depart: number, done: (arrive: number, depart: number) => void): void {
    const ui = this.getUIContext();
    const first = Math.min(arrive, this.today);
    const last = this.today + 730 * WallTime.DAY;
    ui.showDatePickerDialog({
      start: toLocalDate(first),
      end: toLocalDate(last),
      selected: toLocalDate(arrive),
      onDateAccept: (value: Date) => {
        const chosenArrive = fromLocalDate(value);
        setTimeout(() => {
          ui.showDatePickerDialog({
            start: toLocalDate(chosenArrive),
            end: toLocalDate(last),
            selected: toLocalDate(Math.max(depart, chosenArrive)),
            onDateAccept: (second: Date) => {
              done(chosenArrive, fromLocalDate(second));
            }
          });
        }, 300);
      }
    });
  }

  addStop(): void {
    this.pickCity((city: City) => {
      const start = this.stops.length === 0 ? this.today + 7 * WallTime.DAY : this.stops[this.stops.length - 1].depart;
      this.pickDates(start, start + 2 * WallTime.DAY, (arrive: number, depart: number) => {
        const stop = TripUtil.newStop(this.model.trips.newId(), city, arrive, depart);
        this.stops = this.sorted(this.stops.concat([stop]));
        this.problem = TripProblem.None;
      });
    });
  }

  changeCity(index: number): void {
    this.pickCity((city: City) => {
      const stop = this.stops[index];
      const updated = this.stops.slice();
      updated[index] = TripUtil.newStop(stop.id, city, stop.arrive, stop.depart);
      this.stops = updated;
    });
  }

  changeDates(index: number): void {
    const stop = this.stops[index];
    this.pickDates(stop.arrive, stop.depart, (arrive: number, depart: number) => {
      const updated = this.stops.slice();
      updated[index] = TripUtil.newStop(stop.id, stop.city, arrive, depart);
      this.stops = this.sorted(updated);
      this.problem = TripProblem.None;
    });
  }

  removeStop(index: number): void {
    const updated = this.stops.slice();
    updated.splice(index, 1);
    this.stops = updated;
    this.problem = TripProblem.None;
  }

  sorted(stops: TripStop[]): TripStop[] {
    return stops.slice().sort((a: TripStop, b: TripStop) => a.arrive - b.arrive);
  }

  save(): void {
    const problem = TripUtil.validate(this.stops);
    if (problem !== TripProblem.None) {
      this.problem = problem;
      return;
    }
    const trimmed = this.name.trim();
    const name = trimmed.length === 0 ? S.get($r('app.string.tripDefaultName'), this.stops[0].city.name) : trimmed;
    const base = this.original;
    const trip: Trip = base === undefined ?
      { id: this.model.trips.newId(), name: name, stops: this.stops, packed: [], remind: false } :
      TripsStore.copy(base, name, this.stops, base.packed, base.remind);
    this.model.trips.save(trip);
    if (base === undefined) {
      this.model.ui.tripId = trip.id;
      this.model.nav.replacePathByName('trip', null);
    } else {
      this.model.nav.pop();
    }
  }

  delete(): void {
    const trip = this.original;
    if (trip === undefined) {
      return;
    }
    const trips = this.model.trips;
    trips.delete(trip.id);
    this.model.nav.clear();
    this.model.ui.showSnack(S.get($r('app.string.tripDeleted')), S.get($r('app.string.undo')), () => {
      trips.restore(trip);
    });
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.original === undefined ? $r('app.string.newTrip') : $r('app.string.editTrip'), palette: this.palette }) {
          this.saveButton()
        }
        Scroll() {
          Column() {
            Text($r('app.string.tripName')).fontSize(13).fontColor(this.palette.onSurfaceVariant).margin({ bottom: 6 })
            TextInput({ text: this.name, placeholder: $r('app.string.tripNameHint') })
              .fontColor(this.palette.onSurface)
              .placeholderColor(this.palette.onSurfaceVariant)
              .caretColor(this.palette.primary)
              .backgroundColor(this.palette.surfaceHigh)
              .borderRadius(12)
              .height(52)
              .onChange((value: string) => {
                this.name = value;
              })

            Text($r('app.string.tripStops'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(0.8)
              .textCase(TextCase.UpperCase)
              .fontColor(this.palette.onSurfaceVariant)
              .margin({ top: 24, bottom: 8 })

            ForEach(this.stops, (stop: TripStop, index: number) => {
              this.stopCard(stop, index)
            }, (stop: TripStop) => `${stop.id}|${stop.arrive}|${stop.depart}|${CityUtil.id(stop.city)}`)

            Row({ space: 8 }) {
              Image($r('app.media.ic_add_location')).width(20).height(20).fillColor(this.palette.primary)
              Text($r('app.string.addStop')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.palette.primary)
            }
            .justifyContent(FlexAlign.Center)
            .height(52)
            .width('100%')
            .borderRadius(26)
            .border({ width: 1, color: this.palette.outline, radius: 26 })
            .onClick(() => this.addStop())

            if (this.problemText.length > 0) {
              Text(this.problemText).fontSize(14).fontColor(this.palette.error).margin({ top: 12 })
            }

            if (this.original !== undefined) {
              Row({ space: 8 }) {
                Image($r('app.media.ic_delete')).width(20).height(20).fillColor(this.palette.error)
                Text($r('app.string.deleteTrip')).fontSize(15).fontColor(this.palette.error)
              }
              .padding(12)
              .margin({ top: 32 })
              .onClick(() => this.delete())
            }
            Column().height(32 + this.model.ui.bottomInset)
          }
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ maxWidth: 720 })
          .padding({ left: 16, right: 16, top: 8 })
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(this.palette.surfaceLowest)
  }

  @Builder
  saveButton() {
    Button($r('app.string.save'))
      .height(36)
      .backgroundColor(this.palette.primary)
      .fontColor(this.palette.onPrimary)
      .onClick(() => this.save())
  }

  @Builder
  stopCard(stop: TripStop, index: number) {
    Column() {
      Row({ space: 12 }) {
        Text(`${index + 1}`)
          .fontSize(16)
          .fontColor(this.palette.onPrimary)
          .textAlign(TextAlign.Center)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(this.palette.primary)
        Column() {
          Text(stop.city.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
          if (CityUtil.subtitle(stop.city).length > 0) {
            Text(CityUtil.subtitle(stop.city)).fontSize(13).fontColor(this.palette.onSurfaceVariant)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => this.changeCity(index))
        Image($r('app.media.ic_close'))
          .width(24)
          .height(24)
          .fillColor(this.palette.onSurfaceVariant)
          .margin(8)
          .accessibilityText(S.get($r('app.string.removeStop')))
          .onClick(() => this.removeStop(index))
      }
      .width('100%')

      Row({ space: 6 }) {
        Image($r('app.media.ic_date_range')).width(18).height(18).fillColor(this.palette.primary)
        Text(`${TripText.dateRange(stop.arrive, stop.depart)} · ${TripText.dayCount(TripUtil.nights(stop) + 1)}`)
          .fontSize(14)
          .fontColor(this.palette.primary)
      }
      .padding({ left: 12, right: 14, top: 8, bottom: 8 })
      .border({ width: 1, color: this.palette.outline, radius: 20 })
      .margin({ left: 52, top: 4 })
      .onClick(() => this.changeDates(index))
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, right: 4, top: 4, bottom: 12 })
    .borderRadius(20)
    .backgroundColor(this.palette.surfaceLow)
    .margin({ bottom: 10 })
    .width('100%')
  }
}
