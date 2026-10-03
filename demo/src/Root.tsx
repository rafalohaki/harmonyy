import React from 'react';
import {Composition} from 'remotion';
import {BridgeDemo} from './BridgeDemo';
import {FPS, FRAME_H, FRAME_W} from './theme';
import {TOTAL_DURATION} from './timeline';

export const RemotionRoot: React.FC = () => (
  <Composition
    id="BridgeDemo"
    component={BridgeDemo}
    durationInFrames={TOTAL_DURATION}
    fps={FPS}
    width={FRAME_W}
    height={FRAME_H}
  />
);
