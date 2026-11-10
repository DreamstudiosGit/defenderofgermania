// Raid and merchant train sounds (assets/combat/). The merchant train's blows, blocks and
// falls play the raid's files; data/audio.json gives them their own ids.

import { line, lowpass1, shape, stack } from './dsp.mjs';
import {
  creak, klong, metal, rustle, scatter, snap, thud, whoosh, wood,
} from './foley.mjs';
import { bell, chime, horn, pitch, pluck } from './instruments.mjs';
import { reverb } from './master.mjs';

const BLADE = [1, 2.76, 5.4, 8.93];

function alarm(c) {
  const parts = [];
  for (let i = 0; i < 7; i++) parts.push([bell(c, 523, 0.7), i * 0.27, i % 2 ? 0.8 : 1]);
  const peal = shape(stack(c, parts), c, line([[0, 1], [1.75, 1], [2.25, 0]]));
  return reverb(peal.slice(0, Math.round(2.25 * c.sr)), c, { wet: 0.12, tail: 0.1 });
}

export default [
  {
    id: 'raid_swing', folder: 'combat', kind: 'sfx', rms: -20, variants: 3,
    make: (c, n) => whoosh(c, {
      seconds: [0.2, 0.22, 0.18][n], from: 650, to: [2400, 2800, 2100][n], q: 2.2, peak: 0.55,
    }),
  },
  {
    id: 'raid_hit', folder: 'combat', kind: 'sfx', rms: -16, variants: 3,
    make: (c, n) => stack(c, [
      [thud(c, { hz: [108, 98, 118][n], tau: 0.05, puff: 0.7, puffHz: 900 })],
      [snap(c, 1800, 0.008), 0, 0.5],
      [wood(c, { hz: 370, tau: 0.022, click: 0.3 }), 0, 0.5],
    ]),
  },
  {
    id: 'raid_block', folder: 'combat', kind: 'sfx', variants: 3,
    make: (c, n) => stack(c, [
      [metal(c, { hz: [610, 680, 560][n], tau: 0.2, strike: 0.6, ratios: BLADE })],
      [metal(c, { hz: [1450, 1600, 1330][n], tau: 0.1, strike: 0.3 }), 0.001, 0.4],
    ]),
  },
  {
    id: 'raid_parry', folder: 'combat', kind: 'sfx', variants: 2,
    make: (c, n) => stack(c, [
      [metal(c, { hz: [2250, 2500][n], tau: 0.2, strike: 0.3, ratios: [1, 2.32, 3.9, 5.7] })],
      [metal(c, { hz: [3400, 3750][n], tau: 0.12, strike: 0.2 }), 0, 0.3],
    ]),
  },
  {
    id: 'raid_down', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c, n) => stack(c, [
      [thud(c, { hz: 64, tau: 0.13, puff: 0.8, puffHz: 500 })],
      [rustle(c, { seconds: 0.2, low: 700, high: 3000, grains: 60 }), 0.02, 0.25],
      [klong(c, { hz: [390, 440][n], tau: 0.22 }), 0.09, 0.4],
    ]),
  },
  { id: 'raid_alarm', folder: 'combat', kind: 'sfx', rms: -16, limit: 2.4, make: alarm },
  {
    id: 'raid_door', folder: 'combat', kind: 'sfx',
    make: (c) => stack(c, [
      [creak(c, { seconds: 0.38, from: 28, to: 60, tones: [300, 720, 1500] }), 0, 0.5],
      [thud(c, { hz: 68, tau: 0.13, puff: 0.8, puffHz: 600 }), 0.36],
      [wood(c, { hz: 175, tau: 0.07, click: 0.5 }), 0.36, 0.8],
      [metal(c, { hz: 1900, tau: 0.035, strike: 0.5 }), 0.5, 0.25],
    ]),
  },
  {
    id: 'raid_sneak', folder: 'combat', kind: 'sfx', rms: -20, variants: 3,
    make: (c, n) => rustle(c, {
      seconds: [0.3, 0.26, 0.34][n], low: 700, high: 3200, grains: 55, peak: 0.45,
    }),
  },
  {
    id: 'raid_deed', folder: 'combat', kind: 'sfx', rms: -20,
    make: (c) => reverb(stack(c, [
      [chime(c, pitch('A5'), 0.2), 0, 0.8],
      [chime(c, pitch('D6'), 0.28), 0.13],
    ]), c, { wet: 0.2, tail: 0.35 }),
  },
  {
    id: 'merchant_horn', folder: 'combat', kind: 'sfx', rms: -16,
    make: (c) => reverb(stack(c, [
      [horn(c, pitch('A3'), 0.22, { bright: 4.2, attack: 0.04 })],
      [horn(c, pitch('A3'), 0.65, { bright: 4.2, attack: 0.04, release: 0.2 }), 0.3],
    ]), c, { wet: 0.2, tail: 0.4 }),
  },
  {
    id: 'merchant_wagon_stop', folder: 'combat', kind: 'sfx',
    make: (c) => stack(c, [
      [creak(c, { seconds: 0.42, from: 45, to: 22, tones: [380, 900, 1900] }), 0, 0.5],
      [thud(c, { hz: 78, tau: 0.09, puff: 0.7 }), 0.4],
      [scatter(c, {
        count: 4, from: 0.4, to: 0.62, fall: 1,
        make: () => wood(c, { hz: c.range(300, 700), tau: 0.025, click: 0.5 }),
      }), 0, 0.5],
      [scatter(c, {
        count: 5, from: 0.42, to: 0.75, fall: 1,
        make: () => metal(c, { hz: c.range(1800, 3200), tau: 0.04, strike: 0.4 }),
      }), 0, 0.15],
    ]),
  },
  {
    id: 'merchant_crossbow', folder: 'combat', kind: 'sfx', variants: 2,
    make: (c, n) => stack(c, [
      [lowpass1(pluck(c, 0.3, [175, 190][n], { bright: 0.5, sustain: 0.16, hard: 0.7 }), c, 2800)],
      [wood(c, { hz: 900, tau: 0.008, click: 0.8 }), 0, 0.4],
      [wood(c, { hz: 440, tau: 0.028, click: 0.5 }), 0.17],
      [thud(c, { hz: 120, tau: 0.04, puff: 0.4 }), 0.17, 0.6],
    ]),
  },
];
