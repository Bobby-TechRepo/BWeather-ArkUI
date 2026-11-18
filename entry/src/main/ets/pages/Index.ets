import { Palette } from '../common/Theme';
import { AppModel, LayoutSize, Snack } from '../state/AppModel';
import { CitiesPage } from './CitiesPage';
import { InfoPage, LegalPage } from './InfoPages';
import { MainScreen } from './MainScreen';
import { Onboarding } from './Onboarding';
import { RadarPage } from './RadarPage';
import { TripDetailPage } from './TripDetailPage';
import { TripEditorPage } from './TripEditorPage';

/** The app's root: the welcome screen or the main screen, with pushed pages on top. */
@Entry
@ComponentV2
struct Index {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get snack(): Snack | undefined {
    return this.model.ui.snack;
  }

  get snackText(): string {
    return this.model.ui.snack?.text ?? '';
  }

  get snackAction(): string {
    return this.model.ui.snack?.actionLabel ?? '';
  }

  build() {
    Navigation(this.model.nav) {
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.model.weather.state.onboarded) {
          MainScreen()
        } else {
          Onboarding()
        }
        this.snackbar()
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routes)
    .backgroundColor(this.palette.surfaceLowest)
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.model.ui.width = Number(newArea.width);
      this.model.ui.contentHeight = Number(newArea.height);
    })
  }

  @Builder
  routes(name: string) {
    if (name === 'cities') {
      CitiesPage()
    } else if (name === 'trip') {
      TripDetailPage()
    } else if (name === 'trip-edit') {
      TripEditorPage()
    } else if (name === 'info') {
      InfoPage()
    } else if (name === 'privacy') {
      LegalPage({ doc: 'privacy' })
    } else if (name === 'terms') {
      LegalPage({ doc: 'terms' })
    } else if (name === 'radar') {
      RadarPage()
    }
  }

  /** "Paris removed · Undo" and other short messages (Flutter's SnackBar). */
  @Builder
  snackbar() {
    if (this.snack !== undefined) {
      Row({ space: 8 }) {
        Text(this.snackText)
          .fontSize(14)
          .fontColor(this.palette.dark ? '#191C20' : '#F1F0F4')
          .layoutWeight(1)
        if (this.snackAction.length > 0) {
          Text(this.snackAction)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette.dark ? '#00538A' : '#9CCAFF')
            .padding(8)
            .onClick(() => {
              const action = this.snack?.action;
              this.model.ui.hideSnack();
              if (action !== undefined) {
                action();
              }
            })
        }
      }
      .padding({ left: 16, right: 8, top: 6, bottom: 6 })
      .constraintSize({ minHeight: 48, maxWidth: 560 })
      .borderRadius(12)
      .backgroundColor(this.palette.dark ? '#E0E2E8' : '#2D3135')
      .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 2 })
      .margin({ left: 16, right: 16, bottom: (this.model.ui.layout === LayoutSize.Mobile ? 88 : 24) + this.model.ui.bottomInset })
      .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
    }
  }
}
