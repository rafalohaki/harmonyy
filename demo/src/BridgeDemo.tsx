import React from 'react';
import {AbsoluteFill, Sequence, interpolate, useCurrentFrame} from 'remotion';
import {COLORS} from './theme';
import {ClosingCard, TitleCard} from './scenes/Cards';
import {StillSceneView} from './scenes/Scene';
import {CLOSING, SCENES, TITLE, TOTAL_DURATION, sceneStarts} from './timeline';
import type {Scene} from './timeline';

/** Thin progress bar along the bottom edge — orientation only, never covers content. */
const ProgressBar: React.FC = () => {
  const frame = useCurrentFrame();
  const progress = interpolate(frame, [0, TOTAL_DURATION - 1], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 7}}>
      <div
        style={{
          height: '100%',
          width: `${progress * 100}%`,
          backgroundColor: COLORS.accent,
        }}
      />
    </div>
  );
};

/** Fades the whole video to ink over the final stretch. */
const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [TOTAL_DURATION - 26, TOTAL_DURATION - 2], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return <AbsoluteFill style={{backgroundColor: COLORS.ink, opacity, pointerEvents: 'none'}} />;
};

/** Renders one storyboard entry. Positive `kind` check first so the union narrows. */
const SceneBody: React.FC<{scene: Scene}> = ({scene}) => {
  if (scene.kind === 'still') {
    return <StillSceneView durationInFrames={scene.duration} scene={scene} />;
  }
  if (scene.kind === 'title') {
    return <TitleCard subtitle={TITLE.subtitle} title={TITLE.title} />;
  }
  return <ClosingCard honesty={CLOSING.honesty} line={CLOSING.line} note={CLOSING.note} />;
};

export const BridgeDemo: React.FC = () => {
  const starts = sceneStarts(SCENES);

  return (
    <AbsoluteFill style={{backgroundColor: COLORS.ink}}>
      {SCENES.map((scene, index) => (
        <Sequence
          key={`${scene.kind}-${index}`}
          from={starts[index]}
          durationInFrames={scene.duration}
          name={scene.kind === 'still' ? scene.step : scene.kind}
        >
          <SceneBody scene={scene} />
        </Sequence>
      ))}

      <ProgressBar />
      <Outro />
    </AbsoluteFill>
  );
};
