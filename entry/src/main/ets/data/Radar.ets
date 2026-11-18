import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FailureKind, Http, RequestFailure } from './Http';

/** One radar image set: [time] in unix seconds, [path] for the tile URLs. */
export interface RadarFrame {
  time: number;
  path: string;
}

/** RainViewer's past radar frames (lib/.../model.dart RadarFrames), oldest first. */
export interface RadarFrames {
  host: string;
  past: RadarFrame[];
}

interface WeatherMaps {
  host?: string;
  radar?: RadarFramesJson;
}

interface RadarFramesJson {
  past?: RadarFrame[];
}

/**
 * Map services for the radar. OpenStreetMap needs an identifying User-Agent,
 * which ArkUI's Image can't send, so every tile is downloaded here and shown
 * as a PixelMap.
 */
export class Radar {
  static readonly USER_AGENT: string = 'BWeather-HarmonyOS/1.0 (com.bsoft.hos.bweather)';
  static readonly OSM_TILES: string = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static readonly OSM_COPYRIGHT: string = 'https://www.openstreetmap.org/copyright';
  static readonly RAINVIEWER: string = 'https://www.rainviewer.com/';
  private static readonly MAPS: string = 'https://api.rainviewer.com/public/weather-maps.json';

  static async frames(): Promise<RadarFrames> {
    const text = await Http.get(Radar.MAPS, Radar.headers());
    try {
      const json = JSON.parse(text) as WeatherMaps;
      const past = (json.radar?.past ?? [])
        .filter((frame: RadarFrame) => typeof frame.time === 'number' && typeof frame.path === 'string');
      const frames: RadarFrames = { host: json.host ?? 'https://tilecache.rainviewer.com', past: past };
      return frames;
    } catch (error) {
      throw new RequestFailure(FailureKind.Data, 'Radar response could not be read');
    }
  }

  /** Tile URL template for a frame: 256 px tiles, colour scheme 2, smoothed, with snow. */
  static frameTemplate(frames: RadarFrames, frame: RadarFrame): string {
    return `${frames.host}${frame.path}/256/{z}/{x}/{y}/2/1_1.png`;
  }

  static headers(): Record<string, string> {
    const headers: Record<string, string> = { 'User-Agent': Radar.USER_AGENT };
    return headers;
  }
}

/**
 * Downloaded tiles by URL, newest last. Tiles still on screen are never
 * released, so an Image can't end up showing a freed PixelMap.
 */
export class TileCache {
  private static readonly LIMIT: number = 220;
  private static tiles: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private static pending: Set<string> = new Set<string>();
  private static failed: Map<string, number> = new Map<string, number>();

  static get(url: string): image.PixelMap | undefined {
    return TileCache.tiles.get(url);
  }

  /** Starts downloading [url] unless it is cached, loading or failed recently; [done] runs once it's ready. */
  static request(url: string, done: () => void): void {
    if (TileCache.tiles.has(url) || TileCache.pending.has(url)) {
      return;
    }
    const failedAt = TileCache.failed.get(url);
    if (failedAt !== undefined && Date.now() - failedAt < 30000) {
      return;
    }
    TileCache.pending.add(url);
    Http.getBytes(url, Radar.headers(), 12000)
      .then((bytes: ArrayBuffer) => {
        const source = image.createImageSource(bytes);
        return source.createPixelMap().finally(() => {
          source.release();
        });
      })
      .then((pixels: image.PixelMap) => {
        TileCache.tiles.set(url, pixels);
        TileCache.failed.delete(url);
        done();
      })
      .catch((error: Object) => {
        TileCache.failed.set(url, Date.now());
        hilog.info(0x0000, 'Radar', 'Tile failed: %{public}s', url);
      })
      .finally(() => {
        TileCache.pending.delete(url);
      });
  }

  /** Releases the oldest tiles that aren't in [visible]. */
  static trim(visible: Set<string>): void {
    if (TileCache.tiles.size <= TileCache.LIMIT) {
      return;
    }
    const remove: string[] = [];
    let excess = TileCache.tiles.size - TileCache.LIMIT;
    TileCache.tiles.forEach((pixels: image.PixelMap, url: string) => {
      if (excess > 0 && !visible.has(url)) {
        remove.push(url);
        excess--;
      }
    });
    for (const url of remove) {
      TileCache.tiles.get(url)?.release();
      TileCache.tiles.delete(url);
    }
  }

  /** Frees everything (when the radar closes). */
  static clear(): void {
    TileCache.tiles.forEach((pixels: image.PixelMap) => {
      pixels.release();
    });
    TileCache.tiles.clear();
    TileCache.failed.clear();
  }
}
