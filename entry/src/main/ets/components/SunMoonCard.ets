import { S } from '../common/AppContext';
import { MoonInfo, SunProgress } from '../common/Astronomy';
import { Format } from '../common/Format';
import { Messages } from '../common/Messages';
import { Colors, Palette } from '../common/Theme';
import { ForecastUtil } from '../model/ForecastUtil';
import { Daily, Forecast } from '../model/Models';

const SUN_COLOR: string = '#F4B33C';
const MOON_LIT: string = '#F2EBD3';

/** Sunrise-to-sunset arc with the sun's position and day length, plus the moon phase. */
@ComponentV2
export struct SunMoonCard {
  @Require @Param forecast: Forecast;
  /** The moon looks mirrored south of the equator. */
  @Param latitude: number = 0;
  @Require @Param palette: Palette;

  private arcSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private arc: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.arcSettings);
  private moonSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private moonCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.moonSettings);
  private arcReady: boolean = false;
  private moonReady: boolean = false;

  @Monitor('forecast', 'palette', 'latitude')
  onChange(monitor: IMonitor): void {
    this.drawArc();
    this.drawMoon();
  }

  get today(): Daily | undefined {
    return ForecastUtil.today(this.forecast);
  }

  get hasSun(): boolean {
    const today = this.today;
    return today !== undefined && today.sunrise !== undefined && today.sunset !== undefined;
  }

  get sunrise(): number {
    return this.today?.sunrise ?? 0;
  }

  get sunset(): number {
    return this.today?.sunset ?? 0;
  }

  get daylight(): string {
    if (!this.hasSun) {
      return '--';
    }
    const minutes = Math.round((this.sunset - this.sunrise) / 60000);
    return S.get($r('app.string.daylightDuration'), `${Math.floor(minutes / 60)}`, `${minutes % 60}`);
  }

  get moon(): MoonInfo {
    return MoonInfo.at(Date.now());
  }

  build() {
    Column() {
      Text($r('app.string.sunAndMoon'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.palette.onSurface)
        .margin({ bottom: 12 })

      if (this.hasSun) {
        Canvas(this.arc)
          .width('100%')
          .height(72)
          .onReady(() => {
            this.arcReady = true;
            this.drawArc();
          })
        Row() {
          this.label($r('app.string.sunrise'), Format.clock(this.sunrise), HorizontalAlign.Start)
          this.label($r('app.string.daylight'), this.daylight, HorizontalAlign.Center)
          this.label($r('app.string.sunset'), Format.clock(this.sunset), HorizontalAlign.End)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      Divider()
        .color(Colors.alpha(this.palette.outlineVariant, 0.5))
        .margin({ top: 12, bottom: 12 })

      Row({ space: 14 }) {
        Canvas(this.moonCtx)
          .width(40)
          .height(40)
          .onReady(() => {
            this.moonReady = true;
            this.drawMoon();
          })
        Column() {
          Text(Messages.moonPhase(this.moon.phase))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette.onSurface)
          Text(S.get($r('app.string.moonIllumination'), `${Math.round(this.moon.illumination * 100)}`))
            .fontSize(12)
            .fontColor(this.palette.onSurfaceVariant)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(20)
    .backgroundColor(this.palette.surfaceLow)
    .width('100%')
  }

  @Builder
  label(title: Resource, value: string, align: HorizontalAlign) {
    Column() {
      Text(title).fontSize(11).fontColor(this.palette.onSurfaceVariant).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.palette.onSurface).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(align)
    .layoutWeight(1)
  }

  /** A half-ellipse from sunrise (left) to sunset (right), with the sun where it is now. */
  private drawArc(): void {
    if (!this.arcReady || !this.hasSun) {
      return;
    }
    const ctx = this.arc;
    const width = ctx.width;
    const height = ctx.height;
    ctx.clearRect(0, 0, width, height);
    const inset = 10;
    const cx = width / 2;
    const baseline = height - 4;
    const rx = width / 2 - inset;
    const ry = baseline - inset;

    ctx.strokeStyle = Colors.rgba(this.palette.outline, 0.5);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, baseline);
    ctx.lineTo(width, baseline);
    ctx.stroke();

    ctx.strokeStyle = this.palette.outlineVariant;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(cx, baseline, rx, ry, 0, Math.PI, Math.PI * 2);
    ctx.stroke();

    const progress = SunProgress.at(this.sunrise, this.sunset, ForecastUtil.localNow(this.forecast));
    if (progress < 0) {
      return;
    }
    ctx.strokeStyle = SUN_COLOR;
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.ellipse(cx, baseline, rx, ry, 0, Math.PI, Math.PI + Math.PI * progress);
    ctx.stroke();

    const angle = Math.PI + Math.PI * progress;
    const x = cx + rx * Math.cos(angle);
    const y = baseline + ry * Math.sin(angle);
    ctx.fillStyle = Colors.rgba(SUN_COLOR, 0.25);
    ctx.beginPath();
    ctx.arc(x, y, 12, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = SUN_COLOR;
    ctx.beginPath();
    ctx.arc(x, y, 7, 0, Math.PI * 2);
    ctx.fill();
  }

  /** The moon's lit shape for its place in the cycle (0 new, 0.5 full). */
  private drawMoon(): void {
    if (!this.moonReady) {
      return;
    }
    const ctx = this.moonCtx;
    const size = Math.min(ctx.width, ctx.height);
    const r = size / 2;
    const cx = ctx.width / 2;
    const cy = ctx.height / 2;
    ctx.clearRect(0, 0, ctx.width, ctx.height);

    ctx.fillStyle = Colors.rgba(this.palette.onSurface, 0.18);
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();

    const fraction = this.moon.fraction;
    const waxing = fraction < 0.5;
    // Seen from the southern hemisphere the lit side is mirrored.
    const litRight = waxing !== (this.latitude < 0);
    // Half-width of the terminator ellipse; positive means a crescent.
    const k = r * Math.cos(2 * Math.PI * fraction);
    const rx = Math.max(0.01, Math.min(r, Math.abs(k)));

    ctx.fillStyle = MOON_LIT;
    ctx.beginPath();
    // Lit limb, from the top to the bottom on the lit side.
    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !litRight);
    // Terminator back to the top: on the lit side for a crescent, the other side when gibbous.
    const terminatorRight = k > 0 ? litRight : !litRight;
    if (terminatorRight) {
      ctx.ellipse(cx, cy, rx, r, 0, Math.PI / 2, -Math.PI / 2, true);
    } else {
      ctx.ellipse(cx, cy, rx, r, 0, Math.PI / 2, Math.PI * 1.5, false);
    }
    ctx.closePath();
    ctx.fill();
  }
}
