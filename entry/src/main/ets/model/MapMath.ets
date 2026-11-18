/**
 * Web Mercator tile maths for the radar map (what flutter_map did in the
 * Flutter app). Positions are "world pixels" at a zoom: the whole world is
 * 256 * 2^zoom pixels wide, with (0, 0) at the top-left (180°W, ~85°N).
 */

export const TILE_SIZE: number = 256;
/** Web Mercator stops here; beyond it the map would be infinitely tall. */
const MAX_LATITUDE: number = 85.05112878;

/** A point as a fraction of the world (0..1 across, 0..1 down). */
export interface WorldPoint {
  x: number;
  y: number;
}

/** One tile to draw: where (world pixels at the display zoom) and which image. */
export interface TileSpec {
  /** Stable while the tile stays on screen at this size (ForEach key). */
  key: string;
  url: string;
  left: number;
  top: number;
  size: number;
}

export class MapMath {
  static toWorld(latitude: number, longitude: number): WorldPoint {
    const lat = Math.max(-MAX_LATITUDE, Math.min(MAX_LATITUDE, latitude)) * Math.PI / 180;
    const point: WorldPoint = {
      x: (longitude + 180) / 360,
      y: (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2
    };
    return point;
  }

  static worldSize(zoom: number): number {
    return TILE_SIZE * Math.pow(2, zoom);
  }

  /**
   * Tiles covering a [width] x [height] view centred on [center] at display
   * [zoom], drawn from tile level [tileZoom] (lower levels are stretched, as
   * radar tiles stop at zoom 7). [template] has {z}, {x} and {y}.
   */
  static visibleTiles(layer: string, template: string, center: WorldPoint, zoom: number, tileZoom: number,
    width: number, height: number): TileSpec[] {
    const world = MapMath.worldSize(zoom);
    const count = Math.pow(2, tileZoom);
    const size = world / count;
    const left = center.x * world - width / 2;
    const top = center.y * world - height / 2;
    const firstX = Math.floor(left / size);
    const lastX = Math.floor((left + width) / size);
    const firstY = Math.max(0, Math.floor(top / size));
    const lastY = Math.min(count - 1, Math.floor((top + height) / size));
    const tiles: TileSpec[] = [];
    for (let y = firstY; y <= lastY; y++) {
      for (let x = firstX; x <= lastX; x++) {
        // The map repeats sideways; the image wraps, the position doesn't.
        const wrapped = ((x % count) + count) % count;
        const url = template.replace('{z}', `${tileZoom}`).replace('{x}', `${wrapped}`).replace('{y}', `${y}`);
        const tile: TileSpec = {
          key: `${layer}/${tileZoom}/${x}/${y}/${Math.round(size * 100)}`,
          url: url,
          left: x * size,
          top: y * size,
          size: size
        };
        tiles.push(tile);
      }
    }
    return tiles;
  }
}
