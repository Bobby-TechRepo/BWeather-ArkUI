import { S } from '../common/AppContext';
import { Palette } from '../common/Theme';
import { TripCard } from '../components/TripCard';
import { Trip } from '../model/Trips';
import { AppModel, UiStore } from '../state/AppModel';
import { AppTab } from '../state/StateTypes';

/** Trips tab: planned, current and past trips (lib/pages/trips.dart). */
@ComponentV2
export struct TripsPage {
  @Local model: AppModel = AppModel.shared();
  @Local ui: UiStore = AppModel.shared().ui;
  @Local refreshing: boolean = false;

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get trips(): Trip[] {
    return this.model.trips.state.trips;
  }

  /** Cheap when nothing is stale: each stop is only refetched every few hours. */
  @Monitor('ui.tab')
  onTabChange(monitor: IMonitor): void {
    if (this.ui.tab === AppTab.Trips) {
      this.model.trips.refreshAll();
    }
  }

  newTrip(): void {
    this.model.ui.editingTripId = '';
    this.model.nav.pushPathByName('trip-edit', null);
  }

  build() {
    Refresh({ refreshing: this.refreshing }) {
      List({ space: 14 }) {
        ListItem() {
          Row() {
            Text($r('app.string.navTrips'))
              .fontSize(32)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette.onSurface)
              .layoutWeight(1)
            Image($r('app.media.ic_add'))
              .width(26)
              .height(26)
              .fillColor(this.palette.onSurface)
              .margin(10)
              .accessibilityText(S.get($r('app.string.newTrip')))
              .onClick(() => this.newTrip())
          }
          .padding({ left: 16, right: 8, top: 24 + this.model.ui.topInset, bottom: 4 })
          .width('100%')
        }

        if (this.trips.length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              Image($r('app.media.ic_luggage')).width(64).height(64).fillColor(this.palette.primary)
              Text($r('app.string.tripsEmptyTitle'))
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.palette.onSurface)
                .margin({ top: 8 })
              Text($r('app.string.tripsEmptyBody'))
                .fontSize(14)
                .fontColor(this.palette.onSurfaceVariant)
                .textAlign(TextAlign.Center)
              Button() {
                Row({ space: 8 }) {
                  Image($r('app.media.ic_add')).width(18).height(18).fillColor(this.palette.onPrimary)
                  Text($r('app.string.planTrip')).fontSize(15).fontColor(this.palette.onPrimary)
                }
                .padding({ left: 16, right: 16 })
              }
              .height(44)
              .backgroundColor(this.palette.primary)
              .margin({ top: 16 })
              .onClick(() => this.newTrip())
            }
            .padding(32)
            .width('100%')
          }
        }

        ForEach(this.trips, (trip: Trip) => {
          ListItem() {
            Row() {
              Column() {
                TripCard({ tripId: trip.id })
              }
              .width('100%')
              .constraintSize({ maxWidth: 720 })
            }
            .justifyContent(FlexAlign.Center)
            .padding({ left: 16, right: 16 })
            .width('100%')
          }
        }, (trip: Trip) => trip.id)

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
      this.model.trips.refreshAll(true).finally(() => {
        this.refreshing = false;
      });
    })
  }
}
