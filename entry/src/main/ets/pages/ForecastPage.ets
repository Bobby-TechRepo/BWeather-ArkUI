import { AppModel, UiStore } from '../state/AppModel';
import { CityState, States } from '../state/StateTypes';
import { ForecastView } from '../components/ForecastView';
import { NoPlaces } from '../components/Placeholders';
import { LocationBanner } from '../components/Places';

/** Swipeable forecast pages: the user's location first, then saved cities (lib/pages/forecast.dart). */
@ComponentV2
export struct ForecastPage {
  @Local model: AppModel = AppModel.shared();
  /** Held as its own state variable so @Monitor can watch selectionRequest. */
  @Local ui: UiStore = AppModel.shared().ui;
  @Local index: number = 0;
  private swiper: SwiperController = new SwiperController();

  /** The banner covers the status bar when it shows; otherwise the pages do. */
  get topPadding(): number {
    return States.locationBannerShown(this.model.weather.state) ? 0 : this.model.ui.topInset;
  }

  get keys(): string[] {
    return States.places(this.model.weather.state).map((place: CityState) => place.key);
  }

  /** Pages to the place someone asked to see (e.g. a card tapped in Locations). */
  @Monitor('ui.selectionRequest')
  onSelection(monitor: IMonitor): void {
    // Runs after the next layout, so a city that was just added is already a page.
    setTimeout(() => {
      const target = this.keys.indexOf(this.model.ui.selectedPlace);
      if (target !== -1 && target !== this.index) {
        if (Math.abs(target - this.index) === 1) {
          this.swiper.changeIndex(target, true);
        } else {
          this.index = target;
        }
      }
    }, 50);
  }

  build() {
    Column() {
      LocationBanner()
      if (this.keys.length === 0) {
        NoPlaces({
          topPadding: this.topPadding,
          palette: this.model.ui.palette,
          onUseLocation: () => {
            this.model.weather.useMyLocation();
          },
          onAddCity: () => {
            this.model.nav.pushPathByName('cities', null);
          }
        })
          .layoutWeight(1)
      } else {
        Swiper(this.swiper) {
          ForEach(this.keys, (key: string) => {
            ForecastView({ placeKey: key, topPadding: this.topPadding })
          }, (key: string) => key)
        }
        .index(this.index)
        .loop(false)
        .indicator(false)
        .cachedCount(1)
        .layoutWeight(1)
        .width('100%')
        .onChange((index: number) => {
          this.index = index;
          const keys = this.keys;
          if (index < keys.length) {
            this.model.ui.placeVisible(keys[index]);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
