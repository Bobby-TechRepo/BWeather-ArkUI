import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContext, S } from '../common/AppContext';
import { Format } from '../common/Format';
import { Colors, Palette } from '../common/Theme';
import { WallTime } from '../common/WallTime';
import { PageHeader } from '../components/PageHeader';
import { Radar, RadarFrame, RadarFrames, TileCache } from '../data/Radar';
import { MapMath, TileSpec, WorldPoint } from '../model/MapMath';
import { AppModel, RadarTarget } from '../state/AppModel';

const MIN_ZOOM: number = 2;
const MAX_ZOOM: number = 10;
/** RainViewer's free tiles stop here; the map stretches them beyond. */
const RADAR_MAX_ZOOM: number = 7;
const FRAME_INTERVAL_MS: number = 1200;

/**
 * Rain radar for the past ~2 hours (lib/screens/radar.dart): OpenStreetMap
 * base map with RainViewer radar tiles on top, drawn as a simple tile map.
 *
 * RainViewer's free API: 256 px tiles up to zoom 7, past frames only, at most
 * 100 requests a minute per IP, and the credit "Weather data by RainViewer"
 * must stay visible. So only the shown frame is loaded, playback skips every
 * other frame, and the map stops at zoom 10. OpenStreetMap needs the
 * "© OpenStreetMap contributors" credit and an identifying User-Agent.
 */
@ComponentV2
export struct RadarPage {
  @Local model: AppModel = AppModel.shared();
  @Local target: RadarTarget = { latitude: 0, longitude: 0, name: '' };
  @Local center: WorldPoint = { x: 0.5, y: 0.5 };
  @Local zoom: number = 6;
  @Local viewWidth: number = 0;
  @Local viewHeight: number = 0;
  /** Live finger movement, folded into [center] when the gesture ends. */
  @Local panX: number = 0;
  @Local panY: number = 0;
  /** Live pinch, folded into [zoom] when the gesture ends. */
  @Local pinch: number = 1;
  @Local pinchX: number = 0;
  @Local pinchY: number = 0;
  @Local frames: RadarFrames | undefined = undefined;
  @Local failed: boolean = false;
  @Local index: number = 0;
  @Local playing: boolean = false;
  /** Bumped when a tile arrives, so the tile lists are read again. */
  @Local version: number = 0;
  private player: number = -1;

  aboutToAppear(): void {
    const target = this.model.ui.radarTarget;
    if (target !== undefined) {
      this.target = target;
      this.center = MapMath.toWorld(target.latitude, target.longitude);
    }
    this.load();
  }

  aboutToDisappear(): void {
    this.stop();
    TileCache.clear();
  }

  get palette(): Palette {
    return this.model.ui.palette;
  }

  get frame(): RadarFrame | undefined {
    const frames = this.frames;
    if (frames === undefined || frames.past.length === 0) {
      return undefined;
    }
    return frames.past[Math.max(0, Math.min(this.index, frames.past.length - 1))];
  }

  get world(): number {
    return MapMath.worldSize(this.zoom);
  }

  /** Where the world's top-left corner is on screen (before the live gesture offset). */
  get originX(): number {
    return this.viewWidth / 2 - this.center.x * this.world;
  }

  get originY(): number {
    return this.viewHeight / 2 - this.center.y * this.world;
  }

  get baseTiles(): TileSpec[] {
    if (this.viewWidth === 0 || this.version < 0) {
      return [];
    }
    return MapMath.visibleTiles('osm', Radar.OSM_TILES, this.center, this.zoom,
      Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Math.round(this.zoom))), this.viewWidth, this.viewHeight);
  }

  get radarTiles(): TileSpec[] {
    const frames = this.frames;
    const frame = this.frame;
    if (frames === undefined || frame === undefined || this.viewWidth === 0 || this.version < 0) {
      return [];
    }
    return MapMath.visibleTiles(frame.path, Radar.frameTemplate(frames, frame), this.center, this.zoom,
      Math.min(RADAR_MAX_ZOOM, Math.round(this.zoom)), this.viewWidth, this.viewHeight);
  }

  get markerPoint(): WorldPoint {
    const point = MapMath.toWorld(this.target.latitude, this.target.longitude);
    const result: WorldPoint = { x: point.x * this.world, y: point.y * this.world };
    return result;
  }

  get timeLabel(): string {
    const frame = this.frame;
    if (frame === undefined) {
      return '';
    }
    const time = frame.time * 1000;
    const minutes = Math.floor((Date.now() - time) / 60000);
    const age = minutes <= 1 ? S.get($r('app.string.ageJustNow')) : S.get($r('app.string.ageMinutes'), `${minutes}`);
    return `${Format.clock(WallTime.deviceNow(time))}\n${age}`;
  }

  async load(): Promise<void> {
    this.failed = false;
    try {
      const frames = await Radar.frames();
      this.frames = frames;
      this.failed = frames.past.length === 0;
      this.index = Math.max(0, frames.past.length - 1);
      this.requestTiles();
    } catch (error) {
      hilog.info(0x0000, 'Radar', 'Frames unavailable: %{public}s', JSON.stringify(error));
      this.failed = true;
    }
  }

  /** Downloads whatever is on screen and isn't cached yet. */
  requestTiles(): void {
    const tiles = this.baseTiles.concat(this.radarTiles);
    const visible = new Set<string>();
    for (const tile of tiles) {
      visible.add(tile.url);
      TileCache.request(tile.url, () => {
        this.version++;
      });
    }
    TileCache.trim(visible);
  }

  togglePlay(): void {
    const frames = this.frames;
    if (frames === undefined || frames.past.length < 2) {
      return;
    }
    if (this.playing) {
      this.stop();
      return;
    }
    this.playing = true;
    // Every other frame keeps a loop well inside RainViewer's rate limit.
    this.player = setInterval(() => {
      const count = frames.past.length;
      const first = (count - 1) % 2;
      this.index = this.index + 2 > count - 1 ? first : this.index + 2;
      this.requestTiles();
    }, FRAME_INTERVAL_MS);
  }

  stop(): void {
    if (this.player !== -1) {
      clearInterval(this.player);
      this.player = -1;
    }
    this.playing = false;
  }

  /** Moves the view by the finished pan. */
  commitPan(): void {
    const world = this.world;
    const x = this.center.x - this.panX / world;
    const moved: WorldPoint = { x: x - Math.floor(x), y: Math.max(0, Math.min(1, this.center.y - this.panY / world)) };
    this.center = moved;
    this.panX = 0;
    this.panY = 0;
    this.requestTiles();
  }

  /** Zooms by [delta] levels keeping the point at ([focusX], [focusY]) on screen still. */
  zoomBy(delta: number, focusX: number, focusY: number): void {
    const next = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, this.zoom + delta));
    const world = this.world;
    const nextWorld = MapMath.worldSize(next);
    const fx = (focusX - this.originX) / world;
    const fy = (focusY - this.originY) / world;
    const x = fx - (focusX - this.viewWidth / 2) / nextWorld;
    const moved: WorldPoint = {
      x: x - Math.floor(x),
      y: Math.max(0, Math.min(1, fy - (focusY - this.viewHeight / 2) / nextWorld))
    };
    this.zoom = next;
    this.center = moved;
    this.requestTiles();
  }

  recenter(): void {
    this.center = MapMath.toWorld(this.target.latitude, this.target.longitude);
    this.requestTiles();
  }

  openLink(url: string): void {
    AppContext.ability?.openLink(url).catch((error: Object) => {
      hilog.info(0x0000, 'Radar', 'Link not opened: %{public}s', JSON.stringify(error));
    });
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: `${S.get($r('app.string.radar'))} · ${this.target.name}`, palette: this.palette })
        Stack({ alignContent: Alignment.TopStart }) {
          this.map()
          this.zoomButtons()
          this.bottomPanel()
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(this.palette.surfaceLowest)
  }

  @Builder
  map() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(this.baseTiles, (tile: TileSpec) => {
          this.tileImage(tile, false)
        }, (tile: TileSpec) => `${tile.key}|${TileCache.get(tile.url) !== undefined}`)
        ForEach(this.radarTiles, (tile: TileSpec) => {
          this.tileImage(tile, true)
        }, (tile: TileSpec) => `${tile.key}|${TileCache.get(tile.url) !== undefined}`)
        // Pin tip on the place.
        Image($r('app.media.ic_pin'))
          .width(36)
          .height(36)
          .fillColor(this.palette.primary)
          .position({ x: this.markerPoint.x - 18, y: this.markerPoint.y - 34 })
          .accessibilityText(this.target.name)
      }
      .width(0)
      .height(0)
      .clip(false)
      .position({ x: this.originX + this.panX, y: this.originY + this.panY })
      .scale({ x: this.pinch, y: this.pinch, centerX: this.pinchX - this.originX, centerY: this.pinchY - this.originY })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(this.palette.surfaceHighest)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.viewWidth = Number(newArea.width);
      this.viewHeight = Number(newArea.height);
      this.requestTiles();
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 2 })
          .onAction((event: GestureEvent) => {
            const finger = event.fingerList.length > 0 ? event.fingerList[0] : undefined;
            this.zoomBy(1, finger?.localX ?? this.viewWidth / 2, finger?.localY ?? this.viewHeight / 2);
          }),
        PinchGesture()
          .onActionStart((event: GestureEvent) => {
            this.pinchX = event.pinchCenterX;
            this.pinchY = event.pinchCenterY;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.pinch = event.scale;
          })
          .onActionEnd(() => {
            const scale = this.pinch;
            this.pinch = 1;
            this.zoomBy(Math.log2(Math.max(0.05, scale)), this.pinchX, this.pinchY);
          })
          .onActionCancel(() => {
            this.pinch = 1;
          }),
        PanGesture()
          .onActionUpdate((event: GestureEvent) => {
            this.panX = event.offsetX;
            this.panY = event.offsetY;
          })
          .onActionEnd(() => {
            this.commitPan();
          })
          .onActionCancel(() => {
            this.commitPan();
          })
      )
    )
  }

  @Builder
  tileImage(tile: TileSpec, radar: boolean) {
    if (TileCache.get(tile.url) !== undefined) {
      Image(TileCache.get(tile.url)!)
        .width(tile.size)
        .height(tile.size)
        .position({ x: tile.left, y: tile.top })
        .interpolation(ImageInterpolation.Medium)
        .opacity(radar ? 0.75 : 1)
        // The light map turned into a dark one (flutter_map's darkModeTileBuilder).
        .grayscale(!radar && this.palette.dark ? 1 : 0)
        .invert(!radar && this.palette.dark ? 1 : 0)
        .draggable(false)
        .accessibilityLevel('no')
    }
  }

  @Builder
  zoomButtons() {
    Column() {
      this.mapButton($r('app.media.ic_add'), S.get($r('app.string.zoomIn')), () => {
        this.zoomBy(1, this.viewWidth / 2, this.viewHeight / 2);
      })
      this.mapButton($r('app.media.ic_remove'), S.get($r('app.string.zoomOut')), () => {
        this.zoomBy(-1, this.viewWidth / 2, this.viewHeight / 2);
      })
      this.mapButton($r('app.media.ic_my_location'), this.target.name, () => {
        this.recenter();
      })
    }
    .padding(4)
    .borderRadius(16)
    .backgroundColor(this.palette.surfaceLow)
    .shadow({ radius: 8, color: '#26000000', offsetY: 2 })
    .position({ right: 12, top: 12 })
  }

  @Builder
  mapButton(icon: Resource, label: string, action: () => void) {
    Row() {
      Image(icon).width(24).height(24).fillColor(this.palette.onSurface)
    }
    .justifyContent(FlexAlign.Center)
    .width(44)
    .height(44)
    .borderRadius(12)
    .accessibilityText(label)
    .onClick(action)
  }

  @Builder
  bottomPanel() {
    Column() {
      Column() {
        this.controls()
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(16)
      .backgroundColor(this.palette.surfaceLow)
      .shadow({ radius: 8, color: '#26000000', offsetY: 2 })
      .constraintSize({ maxWidth: 640 })
      .width('100%')

      // Required credits, each linking to its source. Not translated: the providers' wording.
      Row({ space: 12 }) {
        Text('© OpenStreetMap contributors')
          .fontSize(12)
          .fontColor(this.palette.onSurface)
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => this.openLink(Radar.OSM_COPYRIGHT))
        Text('Weather data by RainViewer')
          .fontSize(12)
          .fontColor(this.palette.onSurface)
          .decoration({ type: TextDecorationType.Underline })
          .onClick(() => this.openLink(Radar.RAINVIEWER))
      }
      .justifyContent(FlexAlign.End)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .margin({ top: 8 })
      .borderRadius(8)
      .backgroundColor(Colors.alpha(this.palette.surfaceLowest, 0.85))
    }
    .alignItems(HorizontalAlign.End)
    .padding({ left: 12, right: 12, bottom: 8 + this.model.ui.bottomInset })
    .width('100%')
    .position({ left: 0, bottom: 0 })
  }

  @Builder
  controls() {
    if (this.failed) {
      Row({ space: 8 }) {
        Image($r('app.media.ic_cloud_off')).width(22).height(22).fillColor(this.palette.onSurfaceVariant)
        Text($r('app.string.radarUnavailable')).fontSize(14).fontColor(this.palette.onSurface).layoutWeight(1)
        Button($r('app.string.retry'), { buttonStyle: ButtonStyleMode.TEXTUAL })
          .fontColor(this.palette.primary)
          .onClick(() => {
            this.load();
          })
      }
      .padding({ left: 8 })
      .width('100%')
    } else if (this.frame === undefined) {
      Progress({ value: 0, total: 100, type: ProgressType.Linear })
        .style({ enableSmoothEffect: true })
        .color(this.palette.primary)
        .margin(12)
        .width('90%')
    } else {
      Column() {
        Row({ space: 4 }) {
          Row() {
            Image(this.playing ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
              .width(26)
              .height(26)
              .fillColor(this.palette.onSurface)
          }
          .justifyContent(FlexAlign.Center)
          .width(44)
          .height(44)
          .borderRadius(22)
          .opacity((this.frames?.past.length ?? 0) < 2 ? 0.4 : 1)
          .accessibilityText(S.get(this.playing ? $r('app.string.pause') : $r('app.string.play')))
          .onClick(() => this.togglePlay())

          Slider({
            value: this.index,
            min: 0,
            max: Math.max(1, (this.frames?.past.length ?? 1) - 1),
            step: 1
          })
            .selectedColor(this.palette.primary)
            .layoutWeight(1)
            .enabled((this.frames?.past.length ?? 0) >= 2)
            .onChange((value: number) => {
              this.index = Math.round(value);
              this.requestTiles();
            })

          Text(this.timeLabel)
            .fontSize(12)
            .fontColor(this.palette.onSurfaceVariant)
            .textAlign(TextAlign.End)
            .width(96)
        }
        .width('100%')

        Text($r('app.string.radarNoCoverage'))
          .fontSize(12)
          .fontColor(this.palette.onSurfaceVariant)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 4 })
      }
      .width('100%')
    }
  }
}
