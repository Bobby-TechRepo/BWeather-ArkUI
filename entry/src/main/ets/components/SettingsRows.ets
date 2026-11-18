import { Colors, Palette } from '../common/Theme';
import { Segmented, SegmentOption } from './Segmented';

/**
 * Building blocks for grouped settings lists: a section title, a rounded group
 * with hairline dividers, and rows with a coloured icon tile
 * (lib/components/settings_tiles.dart).
 */

@Builder
export function SettingsIcon(icon: Resource, color: string) {
  Row() {
    Image(icon).width(20).height(20).fillColor('#FFFFFF')
  }
  .justifyContent(FlexAlign.Center)
  .width(34)
  .height(34)
  .borderRadius(10)
  .backgroundColor(color)
}

/** Section title, a rounded group and optional small print underneath. */
@ComponentV2
export struct SettingsSection {
  @Param title: ResourceStr = '';
  @Param footer: ResourceStr = '';
  @Require @Param palette: Palette;
  @BuilderParam content: () => void = noRows;

  build() {
    Column() {
      if (this.title !== '') {
        Text(this.title)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.8)
          .fontColor(this.palette.onSurfaceVariant)
          .textCase(TextCase.UpperCase)
          .padding({ left: 12, right: 12, bottom: 8 })
      }
      Column() {
        this.content()
      }
      .borderRadius(20)
      .backgroundColor(this.palette.surfaceLow)
      .clip(true)
      .width('100%')
      if (this.footer !== '') {
        Text(this.footer)
          .fontSize(12)
          .fontColor(this.palette.onSurfaceVariant)
          .padding({ left: 12, right: 12, top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, bottom: 24 })
    .width('100%')
  }
}

@Builder
function noRows() {
}

/** Hairline between rows, indented past the icon. */
@Builder
export function SettingsDivider(palette: Palette) {
  Divider()
    .color(Colors.alpha(palette.outlineVariant, 0.5))
    .margin({ left: 66 })
}

/** A row that opens something: shows the current [value] and a chevron. */
@ComponentV2
export struct SettingsTile {
  @Require @Param icon: Resource;
  @Param color: string = '#2F7BD8';
  @Param title: ResourceStr = '';
  @Param subtitle: string = '';
  @Param value: string = '';
  @Param showChevron: boolean = true;
  @Require @Param palette: Palette;
  @Event onTap: () => void = () => {
  };

  build() {
    Row({ space: 16 }) {
      SettingsIcon(this.icon, this.color)
      Column({ space: 2 }) {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(13).fontColor(this.palette.onSurfaceVariant)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(14)
          .fontColor(this.palette.onSurfaceVariant)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 160 })
      }
      if (this.showChevron) {
        Image($r('app.media.ic_chevron_right')).width(24).height(24).fillColor(this.palette.onSurfaceVariant)
      }
    }
    .padding({ left: 16, right: 12, top: 12, bottom: 12 })
    .constraintSize({ minHeight: 64 })
    .width('100%')
    .onClick(() => this.onTap())
  }
}

@ComponentV2
export struct SettingsSwitchTile {
  @Require @Param icon: Resource;
  @Param color: string = '#2F7BD8';
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';
  @Param isOn: boolean = false;
  @Require @Param palette: Palette;
  @Event onToggle: (isOn: boolean) => void = (isOn: boolean) => {
  };

  build() {
    Row({ space: 16 }) {
      SettingsIcon(this.icon, this.color)
      Column({ space: 2 }) {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface)
        if (this.subtitle !== '') {
          Text(this.subtitle).fontSize(13).fontColor(this.palette.onSurfaceVariant)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(this.palette.primary)
        .onChange((isOn: boolean) => {
          if (isOn !== this.isOn) {
            this.onToggle(isOn);
          }
        })
    }
    .padding({ left: 16, right: 12, top: 12, bottom: 12 })
    .constraintSize({ minHeight: 64 })
    .width('100%')
  }
}

/** A row with a segmented control for short choices like units; stacks on narrow screens. */
@ComponentV2
export struct SettingsSegmentedTile {
  @Require @Param icon: Resource;
  @Param color: string = '#2F7BD8';
  @Param title: ResourceStr = '';
  @Param options: SegmentOption[] = [];
  @Param selected: string = '';
  /** Width available to the row, to decide whether the control fits beside the title. */
  @Param rowWidth: number = 360;
  @Require @Param palette: Palette;
  @Event onSelect: (value: string) => void = (value: string) => {
  };

  get stacked(): boolean {
    return this.rowWidth < 120 + 72 * this.options.length + 120;
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        SettingsIcon(this.icon, this.color)
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface).layoutWeight(1)
        if (!this.stacked) {
          Segmented({
            options: this.options,
            selected: this.selected,
            palette: this.palette,
            onSelect: (value: string) => this.onSelect(value)
          })
        }
      }
      .width('100%')
      if (this.stacked) {
        Row() {
          Segmented({
            options: this.options,
            selected: this.selected,
            palette: this.palette,
            onSelect: (value: string) => this.onSelect(value)
          })
        }
        .padding({ left: 50 })
        .width('100%')
      }
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .width('100%')
  }
}
