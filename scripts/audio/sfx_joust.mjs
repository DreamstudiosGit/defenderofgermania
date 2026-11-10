// Joust sounds (assets/combat/): trumpets, hooves, lances, the fall and the stands.

import { biquad, hump, line, lowpass1, noise, peaked, shape, stack } from './dsp.mjs';
import { crowd, hoof, klong, metal, scatter, snap, thud, whoop, wood } from './foley.mjs';
import { horn, pitch } from './instruments.mjs';
import { reverb } from './master.mjs';
import { crunch } from './sfx_battle.mjs';

const trumpet = (c, name, seconds) =>
  horn(c, pitch(name), seconds, { bright: 5, attack: 0.03, release: 0.06, breath: 0.02 });

function gallop(c) {
  const parts = [];
  for (let stride = 0; stride < 4; stride++) {
    [0, 0.095, 0.19].forEach((beat, k) => {
      const at = stride * 0.37 + beat + c.range(-0.008, 0.008);
      parts.push([hoof(c, { hard: 0.4 + 0.2 * k }), at, 0.75 + 0.12 * k]);
    });
  }
  return stack(c, parts);
}

function cheer(c) {
  const seconds = 2.5;
  const stands = shape(crowd(c, seconds, { voices: 10 }), c, line([[0, 0.1], [0.7, 1], [1.5, 0.9], [seconds, 0]]));
  const parts = [[stands]];
  for (let i = 0; i < 10; i++) {
    parts.push([whoop(c, c.range(0.4, 0.9)), c.range(0.1, 1.5), c.range(0.12, 0.3)]);
  }
  return shape(stack(c, parts), c, line([[0, 1], [seconds - 0.5, 1], [seconds, 0]]));
}

export default [
  {
    id: 'joust_fanfare', folder: 'combat', kind: 'sfx', rms: -16,
    make: (c) => reverb(stack(c, [
      [trumpet(c, 'G4', 0.14)], [trumpet(c, 'G4', 0.1), 0.16], [trumpet(c, 'G4', 0.1), 0.28],
      [trumpet(c, 'B4', 0.14), 0.4], [trumpet(c, 'D5', 0.7), 0.56], [trumpet(c, 'G4', 0.7), 0.56, 0.5],
    ]), c, { wet: 0.25, tail: 0.45 }),
  },
  {
    id: 'joust_spur', folder: 'combat', kind: 'sfx', variants: 3,
    make: (c) => stack(c, [[hoof(c, { hz: 120, hard: 0.8 })], [snap(c, 2600, 0.006, 1), 0, 0.3]]),
  },
  {
    id: 'joust_spur_off', folder: 'combat', kind: 'sfx', rms: -20, variants: 2,
    make: (c) => {
      const scuff = peaked(shape(biquad(noise(c, 0.09), c, 'bandpass', 520, 1), c, hump(0.09, 0.3)));
      const kick = thud(c, { hz: 82, tau: 0.07, puff: 0.7, puffHz: 350 });
      return lowpass1(stack(c, [[kick], [scuff, 0.01, 0.35]]), c, 1200);
    },
  },
  { id: 'joust_gallop', folder: 'combat', kind: 'sfx', variants: 2, make: gallop },
  {
    id: 'joust_impact', folder: 'combat', kind: 'hit', variants: 2,
    make: (c, n) => stack(c, [
      [wood(c, { hz: [340, 310][n], tau: 0.05, click: 1 })],
      [wood(c, { hz: [910, 840][n], tau: 0.03, click: 0.8 }), 0.002, 0.7],
      [wood(c, { hz: [172, 158][n], tau: 0.09, click: 0.2 }), 0.004, 0.7],
      [crunch(c, 3200, 0.06), 0, 0.6],
      [thud(c, { hz: 88, tau: 0.11, puff: 0.7, puffHz: 800 }), 0, 0.7],
    ]),
  },
  {
    id: 'joust_lance_break', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c) => stack(c, [
      [wood(c, { hz: 420, tau: 0.04, click: 1 })],
      [scatter(c, {
        count: 16, to: 0.5, fall: 1.8,
        make: () => wood(c, { hz: c.range(500, 2600), tau: c.range(0.008, 0.03), click: 0.9 }),
      }), 0.01, 0.7],
      [scatter(c, { count: 12, to: 0.4, make: () => snap(c, c.range(3000, 6000), 0.004) }), 0, 0.25],
    ]),
  },
  {
    id: 'joust_shield_block', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c, n) => stack(c, [
      [wood(c, { hz: [250, 275][n], tau: 0.05, click: 0.5 })],
      [metal(c, { hz: [680, 730][n], tau: 0.11, strike: 0.5 }), 0, 0.45],
      [thud(c, { hz: 95, tau: 0.06, puff: 0.5 }), 0, 0.6],
    ]),
  },
  {
    id: 'joust_unseat', folder: 'combat', kind: 'hit', rms: -15,
    make: (c) => stack(c, [
      [scatter(c, {
        count: 6, to: 0.25, fall: 1,
        make: () => metal(c, { hz: c.range(350, 1300), tau: c.range(0.1, 0.22), strike: 0.6 }),
      }), 0, 0.5],
      [thud(c, { hz: 62, tau: 0.18, puff: 0.9 }), 0.1],
      [klong(c, { hz: 410, tau: 0.28 }), 0.2, 0.7],
      [scatter(c, {
        count: 5, from: 0.3, to: 0.8, fall: 1.2,
        make: () => metal(c, { hz: c.range(1500, 3000), tau: 0.05, strike: 0.5 }),
      }), 0, 0.2],
    ]),
  },
  { id: 'joust_crowd_cheer', folder: 'combat', kind: 'sfx', limit: 2.6, make: cheer },
];
