import { S } from '../common/AppContext';
import { Messages } from '../common/Messages';
import { Palette } from '../common/Theme';
import { AppModel } from '../state/AppModel';
import { CityState, LocationIssue, Status, WeatherState } from '../state/StateTypes';

/** First-run welcome screen (lib/screens/onboarding.dart). */
@ComponentV2
export struct Onboarding {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get state(): WeatherState {
    return this.model.weather.state;
  }

  get busy(): boolean {
    return this.state.status === Status.Loading;
  }

  get blocked(): boolean {
    return this.state.locationIssue === LocationIssue.PermissionBlocked ||
      this.state.locationIssue === LocationIssue.ServiceDisabled;
  }

  get approximate(): CityState | undefined {
    return this.state.location;
  }

  get continueLabel(): string {
    const place = this.state.location;
    if (place === undefined) {
      return '';
    }
    const name = place.city.country.length === 0 ? place.city.name : `${place.city.name}, ${place.city.country}`;
    return S.get($r('app.string.continueWith'), name);
  }

  build() {
    Scroll() {
      Column() {
        Image($r('app.media.wx_partly_cloudy_day_fill'))
          .width(200)
          .height(200)
          .objectFit(ImageFit.Contain)
        Text($r('app.string.welcomeTitle'))
          .fontSize(28)
          .fontColor(this.palette.primary)
          .textAlign(TextAlign.Center)
          .margin({ top: 16 })
        Text($r('app.string.welcomeSubtitle'))
          .fontSize(16)
          .fontColor(this.palette.onSurfaceVariant)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })

        Button() {
          Row({ space: 8 }) {
            if (this.busy) {
              LoadingProgress().width(20).height(20).color(this.palette.onPrimary)
            } else {
              Image($r('app.media.ic_my_location')).width(18).height(18).fillColor(this.palette.onPrimary)
            }
            Text(this.busy ? $r('app.string.findingYou') : $r('app.string.useMyLocation'))
              .fontSize(16)
              .fontColor(this.palette.onPrimary)
          }
        }
        .height(48)
        .width('100%')
        .backgroundColor(this.palette.primary)
        .enabled(!this.busy)
        .margin({ top: 32 })
        .onClick(() => {
          this.model.weather.useMyLocation();
        })

        if (this.state.locationIssue !== LocationIssue.None) {
          Text(Messages.locationIssue(this.state.locationIssue))
            .fontSize(14)
            .fontColor(this.palette.error)
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
          if (this.blocked) {
            Button($r('app.string.openSettings'), { buttonStyle: ButtonStyleMode.TEXTUAL })
              .fontColor(this.palette.primary)
              .onClick(() => {
                this.model.weather.openLocationSettings();
              })
          }
        }

        if (this.approximate !== undefined) {
          Button(this.continueLabel, { buttonStyle: ButtonStyleMode.NORMAL })
            .fontColor(this.palette.primary)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.palette.outline, radius: 24 })
            .height(48)
            .width('100%')
            .margin({ top: 12 })
            .onClick(() => {
              this.model.weather.completeOnboarding();
            })
          if (this.approximate.approximate) {
            Text($r('app.string.approximateFromNetwork'))
              .fontSize(12)
              .fontColor(this.palette.onSurfaceVariant)
              .textAlign(TextAlign.Center)
              .margin({ top: 4 })
          }
        }

        Row({ space: 8 }) {
          Image($r('app.media.ic_search')).width(20).height(20).fillColor(this.palette.primary)
          Text($r('app.string.searchForCity')).fontSize(15).fontColor(this.palette.primary)
        }
        .padding(12)
        .margin({ top: 12 })
        .onClick(() => {
          this.model.nav.pushPathByName('cities', null);
        })

        Text($r('app.string.locationPrivacyNote'))
          .fontSize(12)
          .fontColor(this.palette.onSurfaceVariant)
          .textAlign(TextAlign.Center)
          .margin({ top: 24 })
      }
      .padding(24)
      .constraintSize({ maxWidth: 420 })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ top: this.model.ui.topInset, bottom: this.model.ui.bottomInset })
    .backgroundColor(this.palette.surface)
  }
}
