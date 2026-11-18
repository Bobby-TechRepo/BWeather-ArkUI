import { S } from '../common/AppContext';
import { Palette } from '../common/Theme';
import { AddCityField, LocationList } from '../components/Places';
import { AppModel } from '../state/AppModel';

/**
 * Locations tab (phones and tablets): a large title, a search field to add
 * cities, then the saved places as sky-tinted cards (lib/pages/locations.dart).
 */
@ComponentV2
export struct LocationsPage {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  addCity(): void {
    this.model.nav.pushPathByName('cities', null);
  }

  build() {
    LocationList() {
      Column() {
        Row() {
          Text($r('app.string.navLocations'))
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette.onSurface)
            .layoutWeight(1)
          Image($r('app.media.ic_add_location'))
            .width(26)
            .height(26)
            .fillColor(this.palette.onSurface)
            .margin(10)
            .accessibilityText(S.get($r('app.string.addCity')))
            .onClick(() => this.addCity())
        }
        .padding({ left: 16, right: 8, top: 24 + this.model.ui.topInset, bottom: 8 })
        .width('100%')
        Row() {
          AddCityField({
            palette: this.palette,
            onTapField: () => this.addCity()
          })
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
        .constraintSize({ maxWidth: 752 })
        .width('100%')
      }
      .width('100%')
    }
  }
}
