import { Format } from '../common/Format';
import { Colors, Palette } from '../common/Theme';
import { Hourly } from '../model/Models';

const SLOT_WIDTH: number = 52;
const CHART_HEIGHT: number = 190;
const TOP: number = 22;
const LINE_AREA: number = 70;
const BAR_AREA: number = 50;
const LABEL_AREA: number = 22;

/**
 * Next-24-hours chart: temperature line on top, rain-chance bars below
 * (lib/components/hourly_chart.dart). Scrolls horizontally.
 */
@ComponentV2
export struct HourlyChart {
  @Param hours: Hourly[] = [];
  @Require @Param palette: Palette;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  @Monitor('hours', 'palette')
  onDataChange(monitor: IMonitor): void {
    this.draw();
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 16 }) {
        this.legend(this.palette.primary, $r('app.string.chartLegendTemperature'))
        this.legend(Colors.alpha(this.palette.tertiary, 0.6), $r('app.string.chartLegendRain'))
      }
      .padding({ left: 12, right: 12 })

      Scroll() {
        Canvas(this.ctx)
          .width(Math.max(1, this.hours.length) * SLOT_WIDTH)
          .height(CHART_HEIGHT)
          .onReady(() => {
            this.ready = true;
            this.draw();
          })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ left: 8, right: 8 })
      .width('100%')
      .align(Alignment.Start)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  legend(color: string, label: Resource) {
    Row({ space: 6 }) {
      Column().width(12).height(12).borderRadius(3).backgroundColor(color)
      Text(label).fontSize(12).fontColor(this.palette.onSurface)
    }
  }

  private draw(): void {
    if (!this.ready) {
      return;
    }
    const ctx = this.ctx;
    const count = this.hours.length;
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    if (count === 0) {
      return;
    }
    const slot = SLOT_WIDTH;
    const temperatures = this.hours.map((hour: Hourly) => hour.temperature.value);
    let minT = temperatures[0];
    let maxT = temperatures[0];
    for (const t of temperatures) {
      minT = Math.min(minT, t);
      maxT = Math.max(maxT, t);
    }
    const span = Math.max(maxT - minT, 1);
    const top = TOP;
    const lineArea = LINE_AREA;
    const xAt = (i: number): number => slot * i + slot / 2;
    const yAt = (t: number): number => top + lineArea - (t - minT) / span * lineArea;
    const barBottom = top + lineArea + 8 + BAR_AREA;

    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';

    // Rain-chance bars.
    for (let i = 0; i < count; i++) {
      const chance = Math.max(0, Math.min(100, this.hours[i].precipitationProbability.value));
      const barHeight = chance / 100 * BAR_AREA;
      if (barHeight <= 0) {
        continue;
      }
      ctx.fillStyle = Colors.rgba(this.palette.tertiary, 0.45);
      this.roundRect(xAt(i) - slot * 0.3, barBottom - barHeight, slot * 0.6, barHeight, 3);
      if (chance >= 20) {
        ctx.font = this.font(11);
        ctx.fillStyle = this.palette.onSurfaceVariant;
        ctx.fillText(`${Math.round(chance)}%`, xAt(i), barBottom - barHeight - 2);
      }
    }

    // Temperature line.
    ctx.strokeStyle = this.palette.primary;
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(xAt(0), yAt(temperatures[0]));
    for (let i = 1; i < count; i++) {
      const controlX = (xAt(i - 1) + xAt(i)) / 2;
      ctx.bezierCurveTo(controlX, yAt(temperatures[i - 1]), controlX, yAt(temperatures[i]), xAt(i), yAt(temperatures[i]));
    }
    ctx.stroke();

    ctx.font = this.font(13);
    for (let i = 0; i < count; i++) {
      ctx.fillStyle = this.palette.primary;
      ctx.beginPath();
      ctx.arc(xAt(i), yAt(temperatures[i]), 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = this.palette.onSurface;
      ctx.fillText(`${Format.temp(temperatures[i])}°`, xAt(i), yAt(temperatures[i]) - 6);
    }

    // Hour labels.
    ctx.font = this.font(12);
    ctx.fillStyle = this.palette.onSurfaceVariant;
    for (let i = 0; i < count; i++) {
      ctx.fillText(Format.hour(this.hours[i].time), xAt(i), barBottom + LABEL_AREA - 4);
    }
  }

  /** Canvas font sizes are in px; text should follow vp like the rest of the UI. */
  private font(vp: number): string {
    return `${Math.round(this.getUIContext().vp2px(vp))}px sans-serif`;
  }

  /** A bar with rounded top corners, built from arcs and lines only (arcTo is not used). */
  private roundRect(x: number, y: number, width: number, height: number, radius: number): void {
    const ctx = this.ctx;
    const r = Math.max(0, Math.min(radius, width / 2, height));
    if (r < 0.5) {
      ctx.fillRect(x, y, width, height);
      return;
    }
    ctx.beginPath();
    ctx.moveTo(x, y + height);
    ctx.lineTo(x, y + r);
    ctx.arc(x + r, y + r, r, Math.PI, Math.PI * 1.5);
    ctx.lineTo(x + width - r, y);
    ctx.arc(x + width - r, y + r, r, Math.PI * 1.5, Math.PI * 2);
    ctx.lineTo(x + width, y + height);
    ctx.closePath();
    ctx.fill();
  }
}
