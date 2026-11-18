import { displaySync } from '@kit.ArkGraphics2D';
import { Colors } from '../common/Theme';
import { SkyKind } from '../common/Weather';

class Particle {
  readonly x: number;
  readonly y: number;
  readonly size: number;
  readonly speed: number;
  readonly phase: number;

  constructor(x: number, y: number, size: number, speed: number, phase: number) {
    this.x = x;
    this.y = y;
    this.size = size;
    this.speed = speed;
    this.phase = phase;
  }
}

/** Same particles every time (seeded), so the sky doesn't jump between pages. */
function makeParticles(): Particle[] {
  let seed = 7;
  const random = (): number => {
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const particles: Particle[] = [];
  for (let i = 0; i < 160; i++) {
    particles.push(new Particle(random(), random(), random(), 0.6 + random() * 0.8, random() * Math.PI * 2));
  }
  return particles;
}

const PARTICLES: Particle[] = makeParticles();

/**
 * A subtle animated sky drawn behind the forecast (lib/components/weather_background.dart).
 * It only tints the page, so text stays readable in light and dark mode. Still
 * when [animate] is off; paused while the page is off screen.
 */
@ComponentV2
export struct SkyBackground {
  @Param kind: SkyKind = SkyKind.Clear;
  @Param night: boolean = false;
  @Param dark: boolean = false;
  /** Text colour of the theme, used for clouds and stars in light mode. */
  @Param ink: string = '#191C20';
  @Param animate: boolean = true;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private sync: displaySync.DisplaySync | undefined = undefined;
  private visible: boolean = false;
  private ready: boolean = false;
  private startedAt: number = Date.now();

  @Monitor('kind', 'night', 'dark', 'ink')
  onSceneChange(monitor: IMonitor): void {
    this.draw(this.seconds());
  }

  @Monitor('animate')
  onAnimateChange(monitor: IMonitor): void {
    this.updateTicker();
    this.draw(this.seconds());
  }

  aboutToDisappear(): void {
    this.stopTicker();
  }

  private seconds(): number {
    return (Date.now() - this.startedAt) / 1000;
  }

  private updateTicker(): void {
    if (this.animate && this.visible && this.ready) {
      this.startTicker();
    } else {
      this.stopTicker();
    }
  }

  private startTicker(): void {
    if (this.sync !== undefined) {
      return;
    }
    try {
      const sync = displaySync.create();
      const range: ExpectedFrameRateRange = { expected: 30, min: 20, max: 60 };
      sync.setExpectedFrameRateRange(range);
      sync.on('frame', () => {
        this.draw(this.seconds());
      });
      sync.start();
      this.sync = sync;
    } catch (error) {
      this.sync = undefined;
    }
  }

  private stopTicker(): void {
    const sync = this.sync;
    if (sync !== undefined) {
      sync.stop();
      sync.off('frame');
      this.sync = undefined;
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.ready = true;
        this.draw(this.seconds());
        this.updateTicker();
      })
      .onVisibleAreaChange([0.0, 0.05], (isVisible: boolean) => {
        this.visible = isVisible;
        this.updateTicker();
      })
  }

  // ---------------------------------------------------------------- painting

  private draw(t: number): void {
    if (!this.ready) {
      return;
    }
    const ctx = this.ctx;
    const width = ctx.width;
    const height = ctx.height;
    ctx.clearRect(0, 0, width, height);
    if (width <= 0 || height <= 0) {
      return;
    }
    this.paintTint(width, height);
    const hasSun = !this.night && (this.kind === SkyKind.Clear || this.kind === SkyKind.PartlyCloudy);
    const hasStars = this.night && (this.kind === SkyKind.Clear || this.kind === SkyKind.PartlyCloudy);
    if (hasSun) {
      this.paintSun(width, height, t);
    }
    if (hasStars) {
      this.paintStars(width, height, t);
    }
    if (this.kind === SkyKind.Fog) {
      this.paintFog(width, height, t);
    }
    if (this.cloudCount() > 0) {
      this.paintClouds(width, height, t);
    }
    if (this.rainDrops() > 0) {
      this.paintRain(width, height, t);
    }
    if (this.kind === SkyKind.Snow) {
      this.paintSnow(width, height, t);
    }
    if (this.kind === SkyKind.Thunder) {
      this.paintLightning(width, height, t);
    }
  }

  private cloudCount(): number {
    switch (this.kind) {
      case SkyKind.Clear:
      case SkyKind.Fog:
        return 0;
      case SkyKind.PartlyCloudy:
        return 3;
      case SkyKind.Drizzle:
      case SkyKind.Snow:
        return 4;
      default:
        return 6;
    }
  }

  private rainDrops(): number {
    switch (this.kind) {
      case SkyKind.Drizzle:
        return 40;
      case SkyKind.Rain:
        return 80;
      case SkyKind.HeavyRain:
      case SkyKind.Thunder:
        return 140;
      default:
        return 0;
    }
  }

  private tint(): string {
    switch (this.kind) {
      case SkyKind.Clear:
      case SkyKind.PartlyCloudy:
        return this.night ? '#1B2A6B' : '#3D8BFD';
      case SkyKind.Fog:
        return '#9AA5B1';
      case SkyKind.Snow:
        return '#B8D4F0';
      case SkyKind.Thunder:
        return '#4B3F72';
      case SkyKind.Overcast:
        return '#7D8B99';
      default:
        return '#4F6D8A';
    }
  }

  private paintTint(width: number, height: number): void {
    const ctx = this.ctx;
    const strength = this.dark ? 0.35 : 0.18;
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, Colors.rgba(this.tint(), strength));
    gradient.addColorStop(0.7, Colors.rgba(this.tint(), 0));
    gradient.addColorStop(1, Colors.rgba(this.tint(), 0));
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
  }

  private paintSun(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    const x = width * 0.85;
    const y = height * 0.08;
    const radius = Math.min(width, 600) * (0.45 + 0.03 * Math.sin(t * 0.6));
    const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, Colors.rgba('#FFC94D', this.dark ? 0.22 : 0.35));
    gradient.addColorStop(1, Colors.rgba('#FFC94D', 0));
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
  }

  private paintStars(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    const color = this.dark ? '#FFFFFF' : this.ink;
    for (let i = 0; i < 60; i++) {
      const p = PARTICLES[i];
      const twinkle = 0.5 + 0.5 * Math.sin(t * p.speed * 1.5 + p.phase);
      ctx.fillStyle = Colors.rgba(color, (this.dark ? 0.55 : 0.25) * twinkle);
      ctx.beginPath();
      ctx.arc(p.x * width, p.y * height * 0.6, 0.6 + p.size * 1.2, 0, Math.PI * 2);
      ctx.fill();
    }
    // Moon glow, top right.
    const x = width * 0.84;
    const y = height * 0.09;
    const glow = ctx.createRadialGradient(x, y, 0, x, y, 60);
    glow.addColorStop(0, Colors.rgba(color, this.dark ? 0.18 : 0.1));
    glow.addColorStop(1, Colors.rgba(color, 0));
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(x, y, 60, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = Colors.rgba(color, this.dark ? 0.5 : 0.2);
    ctx.beginPath();
    ctx.arc(x, y, 16, 0, Math.PI * 2);
    ctx.fill();
  }

  private paintClouds(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    const base = this.dark ? '#FFFFFF' : this.ink;
    const alpha = this.kind === SkyKind.PartlyCloudy ? (this.dark ? 0.05 : 0.04) : (this.dark ? 0.07 : 0.06);
    ctx.fillStyle = Colors.rgba(base, alpha);
    ctx.filter = 'blur(18px)';
    const span = width + 400;
    for (let i = 0; i < this.cloudCount(); i++) {
      const p = PARTICLES[100 + i];
      const x = ((p.x * span + t * 6 * p.speed) % span) - 200;
      const y = height * (0.04 + p.y * 0.35);
      const w = 140 + p.size * 160;
      // A cloud is three overlapping blurred ovals.
      this.oval(x, y, w, w * 0.42);
      this.oval(x - w * 0.25, y + w * 0.08, w * 0.6, w * 0.3);
      this.oval(x + w * 0.22, y - w * 0.06, w * 0.55, w * 0.32);
    }
    ctx.filter = 'none';
  }

  private oval(x: number, y: number, width: number, height: number): void {
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.ellipse(x, y, width / 2, height / 2, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  private paintRain(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    const drops = this.rainDrops();
    const heavy = drops > 100;
    ctx.strokeStyle = Colors.rgba(this.dark ? '#B3D4FF' : '#2F5D8A', heavy ? 0.28 : 0.2);
    ctx.lineWidth = heavy ? 1.6 : 1.2;
    ctx.lineCap = 'round';
    const length = this.kind === SkyKind.Drizzle ? 8 : 16 + (heavy ? 8 : 0);
    const fall = this.kind === SkyKind.Drizzle ? 260 : 620;
    const slant = 0.18;
    const span = height + length;
    ctx.beginPath();
    for (let i = 0; i < drops; i++) {
      const p = PARTICLES[i];
      const y = ((p.y * span + t * fall * p.speed) % span) - length;
      const x = ((p.x * (width + 40) + y * slant) % (width + 40)) - 20;
      ctx.moveTo(x, y);
      ctx.lineTo(x - length * slant, y - length);
    }
    ctx.stroke();
  }

  private paintSnow(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    ctx.fillStyle = Colors.rgba(this.dark ? '#FFFFFF' : '#6B8BB0', this.dark ? 0.6 : 0.45);
    const span = height + 10;
    for (let i = 0; i < 70; i++) {
      const p = PARTICLES[i];
      const y = ((p.y * span + t * 40 * p.speed) % span) - 5;
      const x = p.x * width + Math.sin(t * 0.8 * p.speed + p.phase) * 18;
      ctx.beginPath();
      ctx.arc(x, y, 1.2 + p.size * 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  private paintFog(width: number, height: number, t: number): void {
    const ctx = this.ctx;
    ctx.fillStyle = Colors.rgba(this.dark ? '#FFFFFF' : this.ink, this.dark ? 0.06 : 0.05);
    ctx.filter = 'blur(30px)';
    for (let i = 0; i < 5; i++) {
      const p = PARTICLES[120 + i];
      const y = height * (0.1 + i * 0.18);
      const dx = Math.sin(t * 0.15 * p.speed + p.phase) * width * 0.15;
      const bandHeight = 50 + p.size * 40;
      this.oval(width * 0.5 + dx, y + bandHeight / 2, width * 1.4, bandHeight);
    }
    ctx.filter = 'none';
  }

  private paintLightning(width: number, height: number, t: number): void {
    // A double flash roughly every 7 seconds.
    const phase = t % 7.0;
    const flash = phase < 0.08 ? 1.0 : (phase > 0.18 && phase < 0.26 ? 0.6 : 0.0);
    if (flash === 0) {
      return;
    }
    this.ctx.fillStyle = Colors.rgba('#FFFFFF', (this.dark ? 0.14 : 0.22) * flash);
    this.ctx.fillRect(0, 0, width, height);
  }
}
