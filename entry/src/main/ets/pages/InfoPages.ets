import { Format } from '../common/Format';
import { Palette } from '../common/Theme';
import { PageHeader } from '../components/PageHeader';
import { AppModel } from '../state/AppModel';
import { appVersion } from './SettingsPage';

/** "About BWeather": description, version and data sources (lib/screens/info.dart). */
@ComponentV2
export struct InfoPage {
  @Local model: AppModel = AppModel.shared();

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get sources(): Resource[] {
    return [
      $r('app.string.aboutOpenMeteo'),
      $r('app.string.aboutHistory'),
      $r('app.string.aboutCams'),
      $r('app.string.aboutOsm'),
      $r('app.string.aboutIpapi'),
      $r('app.string.aboutIcons')
    ];
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: $r('app.string.aboutApp'), palette: this.palette })
        Scroll() {
          Column() {
            Image($r('app.media.ic_cloud')).width(64).height(64).fillColor(this.palette.primary)
            Text($r('app.string.appTitle')).fontSize(28).fontColor(this.palette.primary).margin({ top: 8 })
            Text(appVersion()).fontSize(14).fontColor(this.palette.onSurfaceVariant)
            Text($r('app.string.aboutDescription'))
              .fontSize(16)
              .fontColor(this.palette.onSurface)
              .margin({ top: 20 })
              .width('100%')
            Text($r('app.string.aboutDataSources'))
              .fontSize(17)
              .fontColor(this.palette.primary)
              .margin({ top: 24, bottom: 8 })
              .width('100%')
            ForEach(this.sources, (line: Resource, index: number) => {
              Row({ space: 8 }) {
                Text('•').fontSize(15).fontColor(this.palette.onSurface)
                Text(line).fontSize(15).fontColor(this.palette.onSurface).layoutWeight(1)
              }
              .alignItems(VerticalAlign.Top)
              .margin({ bottom: 6 })
              .width('100%')
            }, (line: Resource, index: number) => `${index}`)
            Row({ space: 8 }) {
              Text('•').fontSize(15).fontColor(this.palette.onSurface)
              Text('Interface icons: Material Icons by Google (Apache License 2.0).')
                .fontSize(15)
                .fontColor(this.palette.onSurface)
                .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')

            this.link($r('app.media.ic_privacy'), $r('app.string.privacyPolicy'), 'privacy')
            this.link($r('app.media.ic_description'), $r('app.string.termsOfUse'), 'terms')
          }
          .padding({ left: 20, right: 20, top: 8, bottom: 20 + this.model.ui.bottomInset })
          .constraintSize({ maxWidth: 640 })
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
  link(icon: Resource, title: Resource, route: string) {
    Row({ space: 16 }) {
      Image(icon).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
      Text(title).fontSize(16).fontColor(this.palette.onSurface).layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
    }
    .padding({ top: 14, bottom: 14 })
    .margin({ top: 8 })
    .width('100%')
    .onClick(() => {
      this.model.nav.pushPathByName(route, null);
    })
  }
}

interface LegalSection {
  title: Resource;
  body: Resource;
}

/** In-app Privacy Policy and Terms of Use (lib/screens/legal.dart). */
@ComponentV2
export struct LegalPage {
  /** "privacy" or "terms". */
  @Param doc: string = 'privacy';
  @Local model: AppModel = AppModel.shared();

  /** Bump when the texts change. */
  private lastUpdated: number = Date.UTC(2026, 10, 14);

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get isPrivacy(): boolean {
    return this.doc === 'privacy';
  }

  get sections(): LegalSection[] {
    const privacy: LegalSection[] = [
      { title: $r('app.string.privacyLocationTitle'), body: $r('app.string.privacyLocationBody') },
      { title: $r('app.string.privacyApproximateTitle'), body: $r('app.string.privacyApproximateBody') },
      { title: $r('app.string.privacySearchTitle'), body: $r('app.string.privacySearchBody') },
      { title: $r('app.string.privacyRadarTitle'), body: $r('app.string.privacyRadarBody') },
      { title: $r('app.string.privacyTripsTitle'), body: $r('app.string.privacyTripsBody') },
      { title: $r('app.string.privacyStorageTitle'), body: $r('app.string.privacyStorageBody') },
      { title: $r('app.string.privacyContactTitle'), body: $r('app.string.privacyContactBody') }
    ];
    const terms: LegalSection[] = [
      { title: $r('app.string.termsAccuracyTitle'), body: $r('app.string.termsAccuracyBody') },
      { title: $r('app.string.termsServiceTitle'), body: $r('app.string.termsServiceBody') },
      { title: $r('app.string.termsThirdPartyTitle'), body: $r('app.string.termsThirdPartyBody') }
    ];
    return this.isPrivacy ? privacy : terms;
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.isPrivacy ? $r('app.string.privacyPolicy') : $r('app.string.termsOfUse'), palette: this.palette })
        Scroll() {
          Column() {
            Text($r('app.string.legalLastUpdated', Format.mediumDate(this.lastUpdated)))
              .fontSize(12)
              .fontColor(this.palette.onSurfaceVariant)
              .width('100%')
            Text(this.isPrivacy ? $r('app.string.privacyIntro') : $r('app.string.termsIntro'))
              .fontSize(16)
              .fontColor(this.palette.onSurface)
              .margin({ top: 12 })
              .width('100%')
            ForEach(this.sections, (section: LegalSection, index: number) => {
              Column({ space: 6 }) {
                Text(section.title).fontSize(17).fontColor(this.palette.primary)
                Text(section.body).fontSize(15).fontColor(this.palette.onSurface)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ top: 20 })
              .width('100%')
            }, (section: LegalSection, index: number) => `${this.doc}${index}`)
          }
          .padding({ left: 20, right: 20, top: 8, bottom: 20 + this.model.ui.bottomInset })
          .constraintSize({ maxWidth: 720 })
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
}
