import { Palette } from '../common/Theme';

/** A grey block that gently pulses while content loads (Flutter used the shimmer package). */
@ComponentV2
export struct Bone {
  @Param boneWidth: Length = '100%';
  @Param boneHeight: Length = 16;
  @Param radius: number = 8;
  @Require @Param palette: Palette;
  @Local dim: boolean = false;

  build() {
    Column()
      .width(this.boneWidth)
      .height(this.boneHeight)
      .borderRadius(this.radius)
      .backgroundColor(this.palette.surfaceHigh)
      .opacity(this.dim ? 0.45 : 1)
      .animation({ duration: 900, iterations: -1, playMode: PlayMode.Alternate, curve: Curve.EaseInOut })
      .onAppear(() => {
        this.dim = true;
      })
  }
}

/** Loading layout for a forecast page (lib/components/shimmering/forecast.dart). */
@ComponentV2
export struct ForecastShimmer {
  @Require @Param palette: Palette;

  build() {
    Column({ space: 14 }) {
      Bone({ boneWidth: 180, boneHeight: 28, palette: this.palette }).margin({ top: 32 })
      Bone({ boneWidth: 240, boneHeight: 14, palette: this.palette })
      Row({ space: 16 }) {
        Bone({ boneWidth: 130, boneHeight: 96, radius: 20, palette: this.palette })
        Bone({ boneWidth: 110, boneHeight: 110, radius: 55, palette: this.palette })
      }
      Bone({ boneWidth: 160, boneHeight: 20, palette: this.palette })
      Bone({ boneWidth: '90%', boneHeight: 88, radius: 20, palette: this.palette }).margin({ top: 12 })
      Row({ space: 12 }) {
        ForEach([0, 1, 2, 3], (index: number) => {
          Bone({ boneWidth: 92, boneHeight: 160, radius: 16, palette: this.palette })
        }, (index: number) => `${index}`)
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}

/** Loading card for a place in the Locations list (lib/components/shimmering/location.dart). */
@ComponentV2
export struct CardShimmer {
  @Require @Param palette: Palette;

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 8 }) {
          Bone({ boneWidth: 140, boneHeight: 20, palette: this.palette })
          Bone({ boneWidth: 90, boneHeight: 12, palette: this.palette })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Bone({ boneWidth: 64, boneHeight: 44, radius: 12, palette: this.palette })
      }
      .width('100%')
      Bone({ boneWidth: '100%', boneHeight: 56, radius: 12, palette: this.palette })
    }
    .padding(18)
    .borderRadius(24)
    .backgroundColor(this.palette.surfaceLow)
    .width('100%')
  }
}

/** A failed load with a retry button (lib/components/error.dart). */
@ComponentV2
export struct ErrorView {
  @Param message: string = '';
  @Require @Param palette: Palette;
  @Event onRetry: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Image($r('app.media.ic_cloud_off'))
        .width(96)
        .height(96)
        .fillColor(this.palette.outline)
      Text(this.message)
        .fontSize(14)
        .fontColor(this.palette.error)
        .textAlign(TextAlign.Center)
        .letterSpacing(0.6)
        .padding({ left: 30, right: 30 })
      Button($r('app.string.retry'))
        .backgroundColor(this.palette.primary)
        .fontColor(this.palette.onPrimary)
        .margin({ top: 8 })
        .onClick(() => this.onRetry())
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}

/** No location and no saved cities yet (lib/pages/forecast.dart). */
@ComponentV2
export struct NoPlaces {
  @Require @Param palette: Palette;
  @Param topPadding: number = 0;
  @Event onUseLocation: () => void = () => {
  };
  @Event onAddCity: () => void = () => {
  };

  build() {
    Column({ space: 4 }) {
      Image($r('app.media.ic_globe')).width(64).height(64).fillColor(this.palette.primary).margin({ bottom: 8 })
      Text($r('app.string.noPlacesTitle')).fontSize(22).fontColor(this.palette.onSurface)
      Text($r('app.string.noPlacesBody')).fontSize(14).fontColor(this.palette.onSurfaceVariant).textAlign(TextAlign.Center)
      Button() {
        Row({ space: 8 }) {
          Image($r('app.media.ic_my_location')).width(18).height(18).fillColor(this.palette.onPrimary)
          Text($r('app.string.useMyLocation')).fontSize(15).fontColor(this.palette.onPrimary)
        }
        .padding({ left: 16, right: 16 })
      }
      .height(44)
      .backgroundColor(this.palette.primary)
      .margin({ top: 16 })
      .onClick(() => this.onUseLocation())
      Button($r('app.string.addCity'), { buttonStyle: ButtonStyleMode.TEXTUAL })
        .fontColor(this.palette.primary)
        .onClick(() => this.onAddCity())
    }
    .padding({ left: 24, right: 24, bottom: 24, top: 24 + this.topPadding })
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}
