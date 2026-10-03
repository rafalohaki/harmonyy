import {FRAME_H, FRAME_W, IMG_H, IMG_W, MIN_ZOOM} from './theme';

/**
 * A camera position over a source still, in source-image pixels.
 *
 * `cx` / `cy` is the point of the still that sits at the centre of the frame;
 * `zoom` is the scale applied to source pixels (1 = native resolution).
 */
export type View = {
  cx: number;
  cy: number;
  zoom: number;
};

export const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

/** The still shown at full width — the least zoomed-in view that covers the frame. */
export const FULL_WIDTH_ZOOM = FRAME_W / IMG_W;

/**
 * Largest zoom that still fits a region of the still inside the frame.
 * `coverage` < 1 leaves a little breathing room around the region.
 */
export const zoomForRegion = (w: number, h: number, coverage = 0.94) =>
  Math.max(MIN_ZOOM, Math.min(FRAME_W / w, FRAME_H / h) * coverage);

export type Placement = {
  left: number;
  top: number;
  width: number;
  height: number;
};

/**
 * Map a camera position onto the frame, then clamp it so no gap can ever appear at
 * an edge. Clamping is what keeps the framing predictable when a view targets a
 * region near the top or bottom of a tall still.
 */
export const place = (view: View): Placement => {
  const zoom = Math.max(view.zoom, MIN_ZOOM);
  const width = IMG_W * zoom;
  const height = IMG_H * zoom;

  const left = clamp(FRAME_W / 2 - view.cx * zoom, Math.min(0, FRAME_W - width), 0);
  const top = clamp(FRAME_H / 2 - view.cy * zoom, Math.min(0, FRAME_H - height), 0);

  return {left, top, width, height};
};
