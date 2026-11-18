import { Palette } from '../common/Theme';

export interface SegmentOption {
  value: string;
  label: ResourceStr;
}

/** A Material-style segmented button (Flutter's SegmentedButton) for short choices. */
@ComponentV2
export struct Segmented {
  @Param options: SegmentOption[] = [];
  @Param selected: string = '';
  @Require @Param palette: Palette;
  @Event onSelect: (value: string) => void = (value: string) => {
  };

  build() {
    Row() {
      ForEach(this.options, (option: SegmentOption, index: number) => {
        Text(option.label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(option.value === this.selected ? this.palette.primary : this.palette.onSurface)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 48 })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(option.value === this.selected ? this.palette.indicator : Color.Transparent)
          .border({
            width: { left: index === 0 ? 0 : 1 },
            color: this.palette.outline
          })
          .onClick(() => this.onSelect(option.value))
      }, (option: SegmentOption) => option.value)
    }
    .border({ width: 1, color: this.palette.outline, radius: 20 })
    .clip(true)
  }
}
