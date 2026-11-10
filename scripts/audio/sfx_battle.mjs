// Battle sounds (assets/combat/): horns, hooves, impacts, missiles and the helmet "klong".

import { decay, hump, line, lowpass1, noise, peaked, shape, stack } from './dsp.mjs';
import {
  creak, crumb, drum, hoof, klong, metal, scatter, snap, thud, whoosh, wood,
} from './foley.mjs';
import { horn, pitch, pluck } from './instruments.mjs';
import { reverb } from './master.mjs';

/** A dull burst of noise: the crunch inside a heavy impact. */
export function crunch(c, hz, tau) {
  const burst = lowpass1(lowpass1(noise(c, tau * 6), c, hz), c, hz);
  return peaked(shape(burst, c, (t) => Math.exp(-t / tau) * Math.min(1, t / 0.002)));
}

/** A throwing arm let go: the frame creaks, the arm slams the beam, the sling cuts the air. */
export function armRelease(c, strain, air) {
  return stack(c, [
    [creak(c, { seconds: strain, from: 30, to: 75 }), 0, 0.5],
    [wood(c, { hz: 240, tau: 0.055, click: 0.7 }), strain - 0.02],
    [thud(c, { hz: 78, tau: 0.1, puff: 0.6 }), strain - 0.02, 0.9],
    [whoosh(c, { seconds: air, from: 260, to: 950, q: 1.2, peak: 0.25 }), strain, 0.45],
  ]);
}

function charge(c) {
  const seconds = 1.2;
  const parts = [];
  for (let i = 0; i < 36; i++) {
    const at = seconds * c.rand() ** 0.6;
    parts.push([hoof(c, { hard: c.range(0.3, 0.8) }), at, 0.2 + 0.8 * (at / seconds)]);
  }
  const ground = peaked(lowpass1(lowpass1(noise(c, seconds + 0.2), c, 110), c, 110));
  shape(ground, c, line([[0, 0], [seconds, 1], [seconds + 0.2, 0]]));
  parts.push([ground, 0, 0.9]);
  return shape(stack(c, parts), c, line([[0, 1], [seconds + 0.05, 1], [seconds + 0.3, 0]]));
}

function volley(c) {
  const parts = [[whoosh(c, { seconds: 0.7, from: 900, to: 3200, q: 1.2, peak: 0.3 }), 0.04, 0.8]];
  for (let i = 0; i < 9; i++) {
    const string = pluck(c, 0.25, c.range(110, 190), { bright: 0.5, sustain: 0.18, hard: 0.6 });
    parts.push([string, c.range(0, 0.14), 0.45]);
  }
  return stack(c, parts);
}

const scoop = (hz, depth = 0.06, tau = 0.12) => (t) => hz * (1 - depth * Math.exp(-t / tau));

export default [
  {
    id: 'battle_horn', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c, n) => {
      const hz = pitch(['D3', 'C3'][n]);
      const options = { attack: 0.16, release: 0.3, breath: 0.05 };
      return reverb(stack(c, [
        [horn(c, scoop(hz), 1.2, { ...options, bright: 2.6 })],
        [horn(c, scoop(hz / 2), 1.2, { ...options, bright: 1.6 }), 0, 0.4],
      ]), c, { wet: 0.3, tail: 0.45 });
    },
  },
  { id: 'battle_charge', folder: 'combat', kind: 'sfx', rms: -16, variants: 2, make: charge },
  {
    id: 'battle_impact', folder: 'combat', kind: 'hit', variants: 3,
    make: (c) => stack(c, [
      [thud(c, { hz: 68, tau: 0.16, puff: 0.8, puffHz: 900 }), 0, 0.8],
      [crunch(c, 2800, 0.1), 0, 0.7],
      [scatter(c, {
        count: 4, to: 0.07, fall: 1,
        make: () => wood(c, { hz: c.range(300, 800), tau: c.range(0.03, 0.05), click: 0.8 }),
      }), 0, 0.6],
      [scatter(c, {
        count: 4, to: 0.09, fall: 1,
        make: () => metal(c, { hz: c.range(500, 1600), tau: c.range(0.12, 0.28), strike: 0.6 }),
      }), 0, 0.5],
    ]),
  },
  { id: 'battle_volley', folder: 'combat', kind: 'sfx', variants: 2, make: volley },
  {
    id: 'battle_treb_shot', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c) => armRelease(c, 0.5, 0.4),
  },
  {
    id: 'battle_blast', folder: 'combat', kind: 'hit', variants: 3,
    make: (c) => stack(c, [
      [thud(c, { hz: 52, tau: 0.22, puff: 1, puffHz: 700 })],
      [crunch(c, 1200, 0.1), 0, 0.6],
      [scatter(c, { count: 14, from: 0.04, to: 0.75, make: () => crumb(c), fall: 1.6 }), 0, 0.4],
    ]),
  },
  {
    id: 'battle_formation', folder: 'combat', kind: 'sfx', rms: -20, variants: 2,
    make: (c) => stack(c, [
      [drum(c, 't', 0.8)],
      ...[0.11, 0.22, 0.32].map((at) => {
        const step = snap(c, c.range(700, 1400), 0.02, 0.8);
        return [shape(step, c, hump(0.14, 0.2)), at, 0.3];
      }),
    ]),
  },
  {
    id: 'battle_rout', folder: 'combat', kind: 'sfx',
    make: (c) => {
      const [from, to] = [pitch('A3'), pitch('D3')];
      const fall = (t) => from * (to / from) ** (Math.min(1, t) ** 1.3);
      const call = horn(c, fall, 1.15, { bright: 2.4, attack: 0.08, release: 0.4 });
      return reverb(shape(call, c, line([[0, 1], [0.4, 1], [1.15, 0.5]])), c, { wet: 0.25, tail: 0.4 });
    },
  },
  {
    id: 'battle_rally', folder: 'combat', kind: 'sfx', rms: -16,
    make: (c) => reverb(stack(c, [
      [horn(c, scoop(pitch('D3'), 0.04), 0.32, { bright: 3 })],
      [horn(c, scoop(pitch('A3'), 0.03, 0.06), 0.7, { bright: 3.4, release: 0.25 }), 0.27],
    ]), c, { wet: 0.25, tail: 0.4 }),
  },
  {
    id: 'battle_leader_captured', folder: 'combat', kind: 'sfx', rms: -16,
    make: (c) => reverb(stack(c, [
      [drum(c, 'D', 1)],
      ...['D2', 'A2', 'D3'].map((name) => {
        const blast = horn(c, pitch(name), 0.9, { bright: 4, attack: 0.03, release: 0.5 });
        return [shape(blast, c, (t) => 0.55 + 0.45 * decay(0.15)(t)), 0.01, 0.5];
      }),
    ]), c, { wet: 0.3, tail: 0.6 }),
  },
  {
    id: 'battle_klong', folder: 'combat', kind: 'sfx', variants: 3,
    make: (c, n) => klong(c, { hz: [430, 470, 400][n], tau: 0.22 }),
  },
];
