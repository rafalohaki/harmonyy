import type {View} from './view';
import type {Band} from './scenes/Caption';

export type StillScene = {
  kind: 'still';
  /** Path inside `demo/public`. */
  asset: string;
  /** Frames this scene stays on screen. */
  duration: number;
  step: string;
  caption: string;
  sub?: string;
  /** Which edge the caption band is anchored to. */
  band: Band;
  from: View;
  to: View;
  /** 0..1 darkening over the still. */
  dim?: number;
};

export type CardScene = {
  kind: 'title' | 'closing';
  duration: number;
};

export type Scene = StillScene | CardScene;

export const TITLE = {
  title: 'Bridge — a system input layer that gives people a voice',
  subtitle: 'Every text field on the device. Not an app.',
};

export const CLOSING = {
  line: 'OpenHarmony / HarmonyOS · API 20+ · github.com/rafalohaki/harmonyy',
  honesty: 'Frames captured from the HarmonyOS emulator. Not a mock-up.',
  note: 'Eleven stills taken on-device with the system snapshot_display tool, assembled with Remotion. No screen in this video was drawn or simulated.',
};

/**
 * Storyboard order. Camera positions are in source-image pixels (1320 x 2856);
 * `MIN_ZOOM` is 0.818, the smallest zoom that still covers the frame.
 */
export const SCENES: Scene[] = [
  {kind: 'title', duration: 120},

  {
    kind: 'still',
    asset: 'stills/01-onboarding.jpeg',
    duration: 195,
    step: '01 · What it is',
    caption: 'The first screen explains the product and the two steps to turn it on.',
    sub: 'Type however you can — or build the sentence from pictures.',
    band: 'bottom',
    from: {cx: 660, cy: 1000, zoom: 0.818},
    to: {cx: 660, cy: 1290, zoom: 0.9},
  },
  {
    kind: 'still',
    asset: 'stills/02-advanced-settings.jpeg',
    duration: 165,
    step: '02 · Configuration',
    caption: 'It is an input method, so it lives in the system. Configuration is optional.',
    sub: 'Any OpenAI-compatible endpoint. The key never leaves the device.',
    band: 'top',
    from: {cx: 660, cy: 900, zoom: 0.86},
    to: {cx: 660, cy: 1150, zoom: 0.95},
  },
  {
    kind: 'still',
    asset: 'stills/03-attached.jpeg',
    duration: 150,
    step: '03 · Attached',
    caption: 'Tap any text field in any app. Bridge attaches like the system keyboard.',
    sub: 'No SDK, no per-app integration — nothing for the app to support.',
    band: 'top',
    from: {cx: 660, cy: 1900, zoom: 0.86},
    to: {cx: 660, cy: 2150, zoom: 0.95},
  },
  {
    kind: 'still',
    asset: 'stills/04-typed.jpeg',
    duration: 150,
    step: '04 · Typed',
    caption: 'Type however you can. Broken Polish is fine.',
    sub: '"ja chciec jutro przyjsc na spotkanie o 10"',
    band: 'top',
    from: {cx: 660, cy: 1750, zoom: 0.86},
    to: {cx: 660, cy: 1900, zoom: 0.95},
  },
  {
    kind: 'still',
    asset: 'stills/05-rewrite-variants.jpeg',
    duration: 210,
    step: '05 · Rewritten',
    caption: 'The model rewrites it in place — observed latency 1.0–1.9 s.',
    sub: 'Three variants come back: minimal, natural, polished.',
    band: 'top',
    from: {cx: 660, cy: 2200, zoom: 0.95},
    to: {cx: 660, cy: 2280, zoom: 1.1},
  },
  {
    kind: 'still',
    asset: 'stills/06-rewrite-applied.jpeg',
    duration: 150,
    step: '06 · Applied',
    caption: 'Pick one and it replaces the text in the field.',
    sub: 'Nothing to copy, nothing to paste.',
    band: 'top',
    from: {cx: 660, cy: 1700, zoom: 0.86},
    to: {cx: 660, cy: 1800, zoom: 1.0},
  },
  {
    kind: 'still',
    asset: 'stills/07-compose-picked.jpeg',
    duration: 150,
    step: '07 · Picked',
    caption: 'Or do not type at all. Three picture taps: jeść, później, rodzina.',
    sub: 'Every tile carries its word, so nothing has to be guessed.',
    band: 'top',
    from: {cx: 660, cy: 2100, zoom: 0.9},
    to: {cx: 660, cy: 2220, zoom: 1.0},
  },
  {
    kind: 'still',
    asset: 'stills/08-compose-variants.jpeg',
    duration: 165,
    step: '08 · Composed',
    caption: 'Three taps become a grammatical sentence.',
    sub: 'Composed by the model from the picked concepts.',
    band: 'top',
    from: {cx: 660, cy: 2150, zoom: 0.9},
    to: {cx: 660, cy: 2250, zoom: 1.05},
  },
  {
    kind: 'still',
    asset: 'stills/09-compose-applied.jpeg',
    duration: 135,
    step: '09 · Inserted',
    caption: 'The sentence lands in the field, ready to send.',
    sub: 'Nothing was typed.',
    band: 'top',
    from: {cx: 660, cy: 1650, zoom: 0.88},
    to: {cx: 660, cy: 1780, zoom: 1.0},
  },
  {
    kind: 'still',
    asset: 'stills/10-pii-hidden.jpeg',
    duration: 225,
    step: '10 · Private',
    caption:
      'Personal data is stripped on the device before anything is sent — and put back afterwards.',
    sub: 'The status line says how many items stayed on this device.',
    band: 'top',
    from: {cx: 660, cy: 2050, zoom: 0.9},
    to: {cx: 660, cy: 2150, zoom: 1.02},
  },
  {
    kind: 'still',
    asset: 'stills/11-offline-only.jpeg',
    duration: 180,
    step: '11 · Offline',
    caption: 'When it cannot reach the model it says so, and keeps working.',
    sub: 'A labelled local result — never a silent failure.',
    band: 'top',
    from: {cx: 660, cy: 1450, zoom: 0.82},
    to: {cx: 660, cy: 1600, zoom: 0.92},
  },

  {kind: 'closing', duration: 225},
];

/** Frame each scene starts at. */
export const sceneStarts = (scenes: Scene[]): number[] => {
  const starts: number[] = [];
  let cursor = 0;
  for (const scene of scenes) {
    starts.push(cursor);
    cursor += scene.duration;
  }
  return starts;
};

export const TOTAL_DURATION = SCENES.reduce((total, scene) => total + scene.duration, 0);
