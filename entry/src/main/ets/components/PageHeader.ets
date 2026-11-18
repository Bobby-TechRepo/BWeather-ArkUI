import { S } from '../common/AppContext';
import { Palette } from '../common/Theme';
import { AppModel } from '../state/AppModel';

@Builder
function noActions() {
}

/**
 * Title bar for pushed pages (they hide the system one): back button, title
 * and optional actions, kept clear of the status bar when the app is drawn
 * edge to edge.
 */
@ComponentV2
export struct PageHeader {
  @Param title: ResourceStr = '';
  /** A larger title, for pages whose title is their main heading (city search). */
  @Param large: boolean = false;
  @Require @Param palette: Palette;
  @Local model: AppModel = AppModel.shared();
  @BuilderParam actions: () => void = noActions;

  build() {
    Row({ space: 4 }) {
      Row() {
        Image($r('app.media.ic_arrow_back')).width(24).height(24).fillColor(this.palette.onSurface)
      }
      .justifyContent(FlexAlign.Center)
      .width(40)
      .height(40)
      .borderRadius(20)
      .accessibilityText(S.get($r('app.string.close')))
      .onClick(() => {
        this.model.nav.pop();
      })

      Text(this.title)
        .fontSize(this.large ? 24 : 20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 4 })

      this.actions()
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: 6, right: 8, top: this.model.ui.topInset + 8, bottom: 8 })
    .width('100%')
    .backgroundColor(this.palette.surfaceLowest)
  }
}
