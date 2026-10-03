import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {COLORS} from '../theme';
import {Caption} from './Caption';
import {PanZoom} from './PanZoom';
import type {StillScene} from '../timeline';

/** A quick fade from the page ink at the start of a scene, so cuts feel deliberate. */
export const FadeFromBlack: React.FC<{durationInFrames?: number}> = ({durationInFrames = 8}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill
      style={{backgroundColor: COLORS.ink, opacity, pointerEvents: 'none'}}
    />
  );
};

export const StillSceneView: React.FC<{scene: StillScene; durationInFrames: number}> = ({
  scene,
  durationInFrames,
}) => (
  <AbsoluteFill style={{backgroundColor: COLORS.ink}}>
    <PanZoom
      src={scene.asset}
      from={scene.from}
      to={scene.to}
      durationInFrames={durationInFrames}
      dim={scene.dim}
    />
    <Caption band={scene.band} caption={scene.caption} step={scene.step} sub={scene.sub} />
    <FadeFromBlack />
  </AbsoluteFill>
);
