/** Frame geometry and shared visual language for the Bridge demo. */

export const FRAME_W = 1080;
export const FRAME_H = 1920;
export const FPS = 30;

/** Every source still is exactly this size (portrait, from `snapshot_display`). */
export const IMG_W = 1320;
export const IMG_H = 2856;

/**
 * Smallest zoom at which a 1320x2856 still still covers a 1080x1920 frame.
 * Below this the still would have to be letterboxed or squashed; we never do either.
 */
export const MIN_ZOOM = Math.max(FRAME_W / IMG_W, FRAME_H / IMG_H);

export const COLORS = {
  ink: '#05080F',
  inkSoft: '#0C1424',
  white: '#FFFFFF',
  muted: 'rgba(255, 255, 255, 0.76)',
  accent: '#4C8DFF',
  accentSoft: '#A6C6FF',
  band: 'rgba(5, 8, 15, 0.96)',
};

export const FONT =
  '-apple-system, BlinkMacSystemFont, "Helvetica Neue", "Segoe UI", Roboto, Arial, sans-serif';
