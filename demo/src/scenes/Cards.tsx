import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {COLORS, FONT} from '../theme';
import {FadeFromBlack} from './Scene';

const rise = (frame: number, from: number, to: number, start: number, end: number) =>
  interpolate(frame, [start, end], [from, to], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

const veil: React.CSSProperties = {
  background: `radial-gradient(1100px 1400px at 50% 34%, ${COLORS.inkSoft} 0%, ${COLORS.ink} 62%)`,
};

export const TitleCard: React.FC<{title: string; subtitle: string}> = ({title, subtitle}) => {
  const frame = useCurrentFrame();
  const titleIn = rise(frame, 0, 1, 16, 48);
  const titleShift = rise(frame, 26, 0, 16, 48);
  const subIn = rise(frame, 0, 1, 34, 66);
  const ruleWidth = rise(frame, 0, 118, 30, 74);

  return (
    <AbsoluteFill style={{...veil, justifyContent: 'center', padding: '0 108px'}}>
      <div
        style={{
          width: ruleWidth,
          height: 7,
          backgroundColor: COLORS.accent,
          borderRadius: 4,
          marginBottom: 44,
        }}
      />
      <div
        style={{
          fontFamily: FONT,
          fontSize: 84,
          fontWeight: 800,
          lineHeight: 1.09,
          letterSpacing: -2.4,
          color: COLORS.white,
          opacity: titleIn,
          transform: `translateY(${titleShift}px)`,
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 42,
          fontWeight: 600,
          lineHeight: 1.3,
          color: COLORS.accentSoft,
          marginTop: 34,
          opacity: subIn,
        }}
      >
        {subtitle}
      </div>
      <FadeFromBlack durationInFrames={14} />
    </AbsoluteFill>
  );
};

export const ClosingCard: React.FC<{
  line: string;
  honesty: string;
  note: string;
}> = ({line, honesty, note}) => {
  const frame = useCurrentFrame();
  const panelIn = rise(frame, 0, 1, 30, 66);
  const panelShift = rise(frame, 34, 0, 30, 66);
  const noteIn = rise(frame, 0, 1, 58, 92);

  return (
    <AbsoluteFill style={{...veil, justifyContent: 'center', padding: '0 108px'}}>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 40,
          fontWeight: 700,
          lineHeight: 1.36,
          color: COLORS.white,
          letterSpacing: -0.4,
        }}
      >
        {line}
      </div>

      <div
        style={{
          marginTop: 52,
          padding: '40px 42px',
          borderLeft: `9px solid ${COLORS.accent}`,
          background: 'rgba(76, 141, 255, 0.14)',
          borderRadius: '0 18px 18px 0',
          opacity: panelIn,
          transform: `translateY(${panelShift}px)`,
        }}
      >
        <div
          style={{
            fontFamily: FONT,
            fontSize: 50,
            fontWeight: 800,
            lineHeight: 1.2,
            letterSpacing: -0.8,
            color: COLORS.white,
          }}
        >
          {honesty}
        </div>
      </div>

      <div
        style={{
          fontFamily: FONT,
          fontSize: 30,
          fontWeight: 500,
          lineHeight: 1.4,
          color: COLORS.muted,
          marginTop: 44,
          opacity: noteIn,
        }}
      >
        {note}
      </div>
      <FadeFromBlack durationInFrames={12} />
    </AbsoluteFill>
  );
};
