import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {COLORS, FONT} from '../theme';

export type Band = 'top' | 'bottom';

type CaptionProps = {
  /** Small orientation label, e.g. `04 · REWRITTEN`. */
  step: string;
  caption: string;
  sub?: string;
  band: Band;
};

const BAND_HEIGHT = 404;
const FADE_HEIGHT = 96;

const bandStyle = (band: Band): React.CSSProperties => ({
  position: 'absolute',
  left: 0,
  right: 0,
  height: BAND_HEIGHT,
  backgroundColor: COLORS.band,
  padding: '38px 64px',
  display: 'flex',
  flexDirection: 'column',
  ...(band === 'top' ? {top: 0, justifyContent: 'flex-start'} : {bottom: 0, justifyContent: 'flex-end'}),
});

const fadeStyle = (band: Band): React.CSSProperties => ({
  position: 'absolute',
  left: 0,
  right: 0,
  height: FADE_HEIGHT,
  background: `linear-gradient(${band === 'top' ? '180deg' : '0deg'}, ${COLORS.band} 0%, rgba(5, 8, 15, 0) 100%)`,
  ...(band === 'top' ? {top: BAND_HEIGHT} : {bottom: BAND_HEIGHT}),
});

/**
 * The dark band that carries the narration. It is deliberately anchored to the
 * edge that holds boilerplate in the stills (the emulator status bar and the app
 * header at the top, or the empty space below the keyboard panel at the bottom),
 * so it never covers the thing a scene is about.
 */
export const Caption: React.FC<CaptionProps> = ({step, caption, sub, band}) => {
  const frame = useCurrentFrame();
  const enter = interpolate(frame, [4, 22], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const rise = interpolate(frame, [4, 22], [22, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <>
      <div style={fadeStyle(band)} />
      <div style={bandStyle(band)}>
        <div
          style={{
            fontFamily: FONT,
            fontSize: 27,
            fontWeight: 700,
            letterSpacing: 3.4,
            textTransform: 'uppercase',
            color: COLORS.accent,
            opacity: enter,
            transform: `translateY(${rise}px)`,
          }}
        >
          {step}
        </div>
        <div
          style={{
            fontFamily: FONT,
            fontSize: 46,
            fontWeight: 700,
            lineHeight: 1.21,
            color: COLORS.white,
            marginTop: 14,
            letterSpacing: -0.4,
            opacity: enter,
            transform: `translateY(${rise}px)`,
          }}
        >
          {caption}
        </div>
        {sub ? (
          <div
            style={{
              fontFamily: FONT,
              fontSize: 31,
              fontWeight: 500,
              lineHeight: 1.32,
              color: COLORS.muted,
              marginTop: 12,
            }}
          >
            {sub}
          </div>
        ) : null}
      </div>
    </>
  );
};
