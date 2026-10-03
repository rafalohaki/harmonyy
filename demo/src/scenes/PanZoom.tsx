import React from 'react';
import {AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame} from 'remotion';
import {COLORS} from '../theme';
import {place, type View} from '../view';

type PanZoomProps = {
  /** Path inside `demo/public`, e.g. `stills/01-settings.jpeg`. */
  src: string;
  from: View;
  to: View;
  durationInFrames: number;
  /** 0..1 darkening applied on top of the still so captions stay high-contrast. */
  dim?: number;
};

const lerp = (progress: number, from: number, to: number) =>
  interpolate(progress, [0, 1], [from, to]);

/**
 * Shows a real emulator frame with a slow Ken Burns move between two camera
 * positions. The still is never stretched: it keeps its own aspect ratio and the
 * frame is always fully covered, so the move is a crop, never a squash.
 */
export const PanZoom: React.FC<PanZoomProps> = ({src, from, to, durationInFrames, dim = 0}) => {
  const frame = useCurrentFrame();
  const progress = interpolate(frame, [0, Math.max(1, durationInFrames - 1)], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.quad),
  });

  const {left, top, width, height} = place({
    cx: lerp(progress, from.cx, to.cx),
    cy: lerp(progress, from.cy, to.cy),
    zoom: lerp(progress, from.zoom, to.zoom),
  });

  return (
    <AbsoluteFill style={{backgroundColor: COLORS.ink}}>
      <Img
        src={staticFile(src)}
        style={{position: 'absolute', left, top, width, height, maxWidth: 'none'}}
      />
      {dim > 0 ? <AbsoluteFill style={{backgroundColor: `rgba(5, 8, 15, ${dim})`}} /> : null}
    </AbsoluteFill>
  );
};
