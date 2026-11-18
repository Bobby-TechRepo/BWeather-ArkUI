import { Colors, Palette } from '../common/Theme';
import { LocationList } from '../components/Places';
import { AppModel, LayoutSize } from '../state/AppModel';
import { AppTab } from '../state/StateTypes';
import { ForecastPage } from './ForecastPage';
import { LocationsPage } from './LocationsPage';
import { SettingsPage } from './SettingsPage';
import { TripsPage } from './TripsPage';

interface Destination {
  tab: AppTab;
  icon: Resource;
  selectedIcon: Resource;
  label: Resource;
  /** The Glyphs icons (nav_*) have more detail and padding than Material ones, so they're drawn larger. */
  iconSize: number;
}

const FORECAST: Destination = {
  tab: AppTab.Forecast,
  icon: $r('app.media.ic_cloud_outline'),
  selectedIcon: $r('app.media.ic_cloud'),
  label: $r('app.string.navForecast'),
  iconSize: 24
};
const LOCATIONS: Destination = {
  tab: AppTab.Locations,
  icon: $r('app.media.nav_locations'),
  selectedIcon: $r('app.media.nav_locations_filled'),
  label: $r('app.string.navLocations'),
  iconSize: 28
};
const TRIPS: Destination = {
  tab: AppTab.Trips,
  icon: $r('app.media.nav_trips'),
  selectedIcon: $r('app.media.nav_trips_filled'),
  label: $r('app.string.navTrips'),
  iconSize: 28
};
const SETTINGS: Destination = {
  tab: AppTab.Settings,
  icon: $r('app.media.nav_settings'),
  selectedIcon: $r('app.media.nav_settings_filled'),
  label: $r('app.string.navSettings'),
  iconSize: 28
};

/**
 * Top-level layout (lib/screens/main.dart): a bottom bar on phones, a
 * navigation rail on tablets, and a rail plus a permanent places panel on
 * wide windows (where the Locations tab isn't needed).
 */
@ComponentV2
export struct MainScreen {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get layout(): LayoutSize {
    return this.model.ui.layout;
  }

  get destinations(): Destination[] {
    return this.layout === LayoutSize.Desktop ? [FORECAST, TRIPS, SETTINGS] : [FORECAST, LOCATIONS, TRIPS, SETTINGS];
  }

  /** The visible tab; "Locations" falls back to the forecast after widening to desktop. */
  get tab(): AppTab {
    const tab = this.model.ui.tab;
    return this.destinations.some((destination: Destination) => destination.tab === tab) ? tab : AppTab.Forecast;
  }

  /** Places panel width: grows with the window, within sensible limits. */
  get panelWidth(): number {
    return Math.max(300, Math.min(380, this.model.ui.width * 0.28));
  }

  build() {
    Column() {
      this.layoutFor()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  layoutFor() {
    if (this.layout === LayoutSize.Mobile) {
      Column() {
        this.pages()
        this.bottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.surfaceLowest)
    } else {
      Row() {
        this.rail()
        Divider().vertical(true).height('100%').color(this.palette.outlineVariant)
        if (this.layout === LayoutSize.Desktop) {
          Column() {
            Text($r('app.string.navLocations'))
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette.onSurface)
              .padding({ left: 16, right: 16, top: 20 + this.model.ui.topInset, bottom: 12 })
              .width('100%')
            LocationList({ compact: true })
              .layoutWeight(1)
            Row({ space: 8 }) {
              Image($r('app.media.ic_add_location')).width(20).height(20).fillColor(this.palette.onPrimary)
              Text($r('app.string.addCity')).fontSize(15).fontColor(this.palette.onPrimary)
            }
            .justifyContent(FlexAlign.Center)
            .height(44)
            .borderRadius(22)
            .backgroundColor(this.palette.primary)
            .margin({ left: 12, right: 12, top: 12, bottom: 12 + this.model.ui.bottomInset })
            .width('90%')
            .onClick(() => {
              this.model.nav.pushPathByName('cities', null);
            })
          }
          .width(this.panelWidth)
          .height('100%')
          .backgroundColor(this.palette.surfaceLowest)
          Divider().vertical(true).height('100%').color(this.palette.outlineVariant)
        }
        this.pages()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette.surfaceLowest)
    }
  }

  /** All tabs stay alive (like IndexedStack); only the selected one is shown. */
  @Builder
  pages() {
    Stack() {
      Column() {
        ForecastPage()
      }
      .visibility(this.tab === AppTab.Forecast ? Visibility.Visible : Visibility.None)

      if (this.layout !== LayoutSize.Desktop) {
        Column() {
          LocationsPage()
        }
        .visibility(this.tab === AppTab.Locations ? Visibility.Visible : Visibility.None)
      }

      Column() {
        TripsPage()
      }
      .visibility(this.tab === AppTab.Trips ? Visibility.Visible : Visibility.None)

      Column() {
        SettingsPage()
      }
      .visibility(this.tab === AppTab.Settings ? Visibility.Visible : Visibility.None)

      // Keeps scrolled lists from running under the status bar icons (the forecast's sky goes under on purpose).
      if (this.tab !== AppTab.Forecast && this.model.ui.topInset > 0) {
        Column()
          .width('100%')
          .height(this.model.ui.topInset)
          .backgroundColor(Colors.alpha(this.palette.surfaceLowest, 0.94))
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .height('100%')
  }

  @Builder
  bottomBar() {
    Row() {
      ForEach(this.destinations, (destination: Destination) => {
        Column({ space: 4 }) {
          Row() {
            Image(this.tab === destination.tab ? destination.selectedIcon : destination.icon)
              .width(destination.iconSize)
              .height(destination.iconSize)
              .fillColor(this.tab === destination.tab ? this.palette.primary : this.palette.onSurfaceVariant)
          }
          .justifyContent(FlexAlign.Center)
          .width(64)
          .height(32)
          .borderRadius(16)
          .backgroundColor(this.tab === destination.tab ? this.palette.indicator : Color.Transparent)
          Text(destination.label)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tab === destination.tab ? this.palette.onSurface : this.palette.onSurfaceVariant)
        }
        .layoutWeight(1)
        .padding({ top: 12, bottom: 12 })
        .onClick(() => {
          this.model.ui.tab = destination.tab;
        })
      }, (destination: Destination) => destination.tab)
    }
    .width('100%')
    .padding({ bottom: this.model.ui.bottomInset })
    .backgroundColor(this.palette.surfaceLow)
  }

  @Builder
  rail() {
    Column({ space: 12 }) {
      ForEach(this.destinations, (destination: Destination) => {
        Column({ space: 4 }) {
          Row() {
            Image(this.tab === destination.tab ? destination.selectedIcon : destination.icon)
              .width(destination.iconSize)
              .height(destination.iconSize)
              .fillColor(this.tab === destination.tab ? this.palette.primary : this.palette.onSurfaceVariant)
          }
          .justifyContent(FlexAlign.Center)
          .width(56)
          .height(32)
          .borderRadius(16)
          .backgroundColor(this.tab === destination.tab ? this.palette.indicator : Color.Transparent)
          Text(destination.label)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tab === destination.tab ? this.palette.primary : this.palette.onSurfaceVariant)
            .maxLines(1)
        }
        .width(80)
        .onClick(() => {
          this.model.ui.tab = destination.tab;
        })
      }, (destination: Destination) => destination.tab)
    }
    .padding({ top: 24 + this.model.ui.topInset })
    .width(80)
    .height('100%')
    .backgroundColor(this.palette.surfaceLowest)
  }
}
