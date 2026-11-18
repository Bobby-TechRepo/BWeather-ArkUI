import { S } from '../common/AppContext';
import { Colors, Palette } from '../common/Theme';
import { CapitalCity } from '../data/Capitals';
import { CityUtil } from '../model/ForecastUtil';
import { City } from '../model/Models';
import { PageHeader } from '../components/PageHeader';
import { AppModel } from '../state/AppModel';
import { CapitalGroup, SearchStore } from '../state/SearchStore';
import { CityState, CURRENT_LOCATION_KEY, Status } from '../state/StateTypes';

/** Where a row sits in its card, for the rounded corners. */
enum RowPosition {
  Only = 'only',
  First = 'first',
  Middle = 'middle',
  Last = 'last'
}

function position(index: number, count: number): RowPosition {
  if (count === 1) {
    return RowPosition.Only;
  }
  if (index === 0) {
    return RowPosition.First;
  }
  return index === count - 1 ? RowPosition.Last : RowPosition.Middle;
}

/**
 * City search (lib/screens/cities.dart): a large title and search field, then
 * shortcuts and the built-in capitals in A–Z cards until the user types, then
 * live results. Also used as a picker by the trip editor (ui.pickCity).
 */
@ComponentV2
export struct CitiesPage {
  @Local model: AppModel = AppModel.shared();
  @Local text: string = '';
  /** True when opened by the trip editor: the city is returned, not saved to Locations. */
  @Local picking: boolean = false;

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get search(): SearchStore {
    return this.model.search;
  }

  /** Places already in Locations get a tick instead of the add icon. */
  get savedIds(): string[] {
    return this.model.weather.state.cities.map((place: CityState) => place.key);
  }

  get location(): CityState | undefined {
    return this.model.weather.state.location;
  }

  /** "Use my location" while there's no precise location yet (add mode). */
  get offerLocate(): boolean {
    const location = this.location;
    return !this.picking && (location === undefined || location.approximate);
  }

  /** The user's own location as a one-tap choice (picker mode). */
  get offerCurrent(): boolean {
    return this.picking && this.location !== undefined;
  }

  aboutToAppear(): void {
    // Start from the city list, not the last search.
    this.model.search.clear();
    this.picking = this.model.ui.pickCity !== undefined;
  }

  aboutToDisappear(): void {
    // Closed without choosing: the next search adds to Locations again.
    if (this.picking) {
      this.model.ui.pickCity = undefined;
    }
  }

  select(city: City): void {
    const pick = this.model.ui.pickCity;
    if (this.picking && pick !== undefined) {
      pick(city);
      this.model.nav.pop();
      return;
    }
    const key = this.model.weather.addCity(city);
    this.model.ui.showPlace(key);
    this.model.nav.pop();
  }

  selectCapital(capital: CapitalCity): void {
    // Use the coordinates we already have instead of searching by name,
    // which could pick a different place with the same name.
    const city: City = {
      name: capital.name,
      country: capital.country,
      timezone: 'auto',
      latitude: capital.latitude,
      longitude: capital.longitude
    };
    this.select(city);
  }

  useMyLocation(): void {
    const model = this.model;
    model.nav.pop();
    // The location banner shows progress while GPS works.
    model.weather.useMyLocation().then(() => {
      if (model.weather.state.location !== undefined) {
        model.ui.showPlace(CURRENT_LOCATION_KEY);
      }
    });
  }

  capitalId(capital: CapitalCity): string {
    return `${capital.latitude.toFixed(3)},${capital.longitude.toFixed(3)}`;
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({
          title: this.picking ? $r('app.string.searchForCity') : $r('app.string.addCity'),
          large: true,
          palette: this.palette
        })
        Column() {
          this.searchField()
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 16 })
        .width('100%')
        if (!this.search.isSearching) {
          this.capitals()
        } else if (this.search.query.trim().length < SearchStore.MIN_QUERY_LENGTH) {
          this.message($r('app.media.ic_keyboard'), S.get($r('app.string.keepTyping')), this.palette.onSurfaceVariant, false)
        } else if (this.search.status === Status.Failure) {
          this.message($r('app.media.ic_cloud_off'), S.get($r('app.string.searchFailed')), this.palette.error, true)
        } else if (this.search.status === Status.Success && this.search.results.length === 0) {
          this.message($r('app.media.ic_search_off'), S.get($r('app.string.noPlacesMatch'), this.search.query.trim()),
            this.palette.onSurfaceVariant, false)
        } else if (this.search.results.length === 0) {
          Column() {
            this.loadingRows()
          }
          .padding({ left: 16, right: 16, top: 10 })
          .width('100%')
        } else {
          this.results()
        }
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(this.palette.surfaceLowest)
  }

  @Builder
  searchField() {
    Row({ space: 4 }) {
      Image($r('app.media.ic_search')).width(24).height(24).fillColor(this.palette.primary).margin({ left: 16 })
      TextInput({ text: this.text, placeholder: $r('app.string.searchHint') })
        .backgroundColor(Color.Transparent)
        .fontSize(16)
        .fontColor(this.palette.onSurface)
        .placeholderColor(this.palette.onSurfaceVariant)
        .caretColor(this.palette.primary)
        .enterKeyType(EnterKeyType.Search)
        .defaultFocus(true)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.text = value;
          this.search.queryChanged(value);
        })
        .onSubmit(() => {
          this.search.search(this.text);
        })
      if (this.text.length > 0) {
        Image($r('app.media.ic_cancel'))
          .width(22)
          .height(22)
          .fillColor(this.palette.onSurfaceVariant)
          .margin({ right: 14 })
          .accessibilityText(S.get($r('app.string.clearSearch')))
          .onClick(() => {
            this.text = '';
            this.search.clear();
          })
      }
    }
    .height(56)
    .borderRadius(28)
    .backgroundColor(this.palette.surfaceHigh)
    .constraintSize({ maxWidth: 688 })
    .width('100%')
  }

  @Builder
  capitals() {
    List() {
      if (this.offerLocate) {
        ListItem() {
          this.row(S.get($r('app.string.useMyLocation')),
            this.location === undefined ? '' : S.get($r('app.string.approximateLocation')),
            $r('app.media.ic_my_location'), '', false, $r('app.media.ic_chevron_right'), RowPosition.Only)
        }
        .margin({ bottom: 16 })
        .onClick(() => this.useMyLocation())
      }
      if (this.offerCurrent) {
        ListItem() {
          this.row(this.location?.city.name ?? '',
            this.location?.approximate === true ? S.get($r('app.string.approximateLocation')) : S.get($r('app.string.yourLocation')),
            $r('app.media.ic_near_me'), '', false, $r('app.media.ic_chevron_right'), RowPosition.Only)
        }
        .margin({ bottom: 16 })
        .onClick(() => {
          const location = this.location;
          if (location !== undefined) {
            this.select(location.city);
          }
        })
      }
      ForEach(this.search.groups, (group: CapitalGroup) => {
        ListItemGroup({ header: this.letterHeader(group.letter) }) {
          ForEach(group.cities, (capital: CapitalCity, index: number) => {
            ListItem() {
              this.row(capital.name, capital.country, undefined, capital.name.charAt(0).toUpperCase(),
                this.savedIds.includes(this.capitalId(capital)), $r('app.media.ic_add_circle'),
                position(index, group.cities.length))
            }
            .onClick(() => this.selectCapital(capital))
          }, (capital: CapitalCity) => `${capital.name}|${capital.country}`)
        }
        .divider({ strokeWidth: 0.5, color: Colors.alpha(this.palette.outlineVariant, 0.6), startMargin: 68, endMargin: 0 })
        .margin({ bottom: 16 })
      }, (group: CapitalGroup) => group.letter)
      ListItem() {
        Column().height(8 + this.model.ui.bottomInset)
      }
    }
    .sticky(StickyStyle.Header)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 16, right: 16 })
    .constraintSize({ maxWidth: 720 })
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  results() {
    Column() {
      if (this.search.status === Status.Loading) {
        Progress({ value: 100, total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 2, enableScanEffect: true })
          .color(this.palette.primary)
          .width('100%')
          .margin({ bottom: 8 })
      }
      List() {
        ListItemGroup() {
          ForEach(this.search.results, (city: City, index: number) => {
            ListItem() {
              this.row(city.name, CityUtil.subtitle(city), undefined, city.name.charAt(0).toUpperCase(),
                !this.picking && this.savedIds.includes(CityUtil.id(city)), $r('app.media.ic_add_circle'),
                position(index, this.search.results.length))
            }
            .onClick(() => this.select(city))
          }, (city: City) => CityUtil.id(city))
        }
        .divider({ strokeWidth: 0.5, color: Colors.alpha(this.palette.outlineVariant, 0.6), startMargin: 68, endMargin: 0 })
        ListItem() {
          Column().height(16 + this.model.ui.bottomInset)
        }
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1)
      .width('100%')
    }
    .padding({ left: 16, right: 16 })
    .constraintSize({ maxWidth: 720 })
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  letterHeader(letter: string) {
    Text(letter)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .letterSpacing(0.4)
      .fontColor(this.palette.primary)
      .padding({ left: 16, top: 4, bottom: 8 })
      .width('100%')
      .backgroundColor(this.palette.surfaceLowest)
  }

  /** One place: a round badge (initial or icon), name, subtitle and an add / saved mark. */
  @Builder
  row(name: string, subtitle: string, icon: Resource | undefined, initial: string, saved: boolean, trailing: Resource,
    place: RowPosition) {
    Row({ space: 14 }) {
      Row() {
        if (icon !== undefined) {
          Image(icon).width(20).height(20).fillColor(this.palette.primary)
        } else {
          Text(initial).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.palette.primary)
        }
      }
      .justifyContent(FlexAlign.Center)
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(Colors.alpha(this.palette.primary, 0.12))

      Column() {
        Text(name)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette.onSurface)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(14)
            .fontColor(this.palette.onSurfaceVariant)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image(saved ? $r('app.media.ic_check_circle') : trailing)
        .width(24)
        .height(24)
        .fillColor(saved ? this.palette.primary : this.palette.onSurfaceVariant)
    }
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .width('100%')
    .backgroundColor(this.palette.surfaceLow)
    .borderRadius({
      topLeft: place === RowPosition.First || place === RowPosition.Only ? 20 : 0,
      topRight: place === RowPosition.First || place === RowPosition.Only ? 20 : 0,
      bottomLeft: place === RowPosition.Last || place === RowPosition.Only ? 20 : 0,
      bottomRight: place === RowPosition.Last || place === RowPosition.Only ? 20 : 0
    })
  }

  @Builder
  message(icon: Resource, text: string, color: string, retry: boolean) {
    Column({ space: 16 }) {
      Row() {
        Image(icon).width(34).height(34).fillColor(color)
      }
      .justifyContent(FlexAlign.Center)
      .width(72)
      .height(72)
      .borderRadius(36)
      .backgroundColor(this.palette.surfaceHigh)
      Text(text).fontSize(16).fontColor(color).textAlign(TextAlign.Center)
      if (retry) {
        Button() {
          Row({ space: 8 }) {
            Image($r('app.media.ic_refresh')).width(18).height(18).fillColor(this.palette.primary)
            Text($r('app.string.retry')).fontSize(15).fontColor(this.palette.primary)
          }
          .padding({ left: 16, right: 16 })
        }
        .height(44)
        .backgroundColor(this.palette.indicator)
        .onClick(() => {
          this.search.search(this.search.query);
        })
      }
    }
    .padding(32)
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .width('100%')
  }

  /** Grey rows while the first results load. */
  @Builder
  loadingRows() {
    Column() {
      ForEach([0, 1, 2, 3], (index: number) => {
        Row({ space: 14 }) {
          Column().width(40).height(40).borderRadius(20).backgroundColor(this.palette.surfaceHighest)
          Column({ space: 8 }) {
            Column().width(140 - index * 12).height(14).borderRadius(6).backgroundColor(this.palette.surfaceHighest)
            Column().width(90).height(10).borderRadius(6).backgroundColor(this.palette.surfaceHighest)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .padding(14)
        .width('100%')
      }, (index: number) => `${index}`)
    }
    .borderRadius(20)
    .backgroundColor(this.palette.surfaceLow)
    .constraintSize({ maxWidth: 688 })
    .width('100%')
  }
}
