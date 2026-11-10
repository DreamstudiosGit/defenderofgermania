// War table sounds (assets/map/) and the sounds of coin and construction (assets/economy/).

import { biquad, hump, noise, peaked, shape, stack, TAU } from './dsp.mjs';
import { coin, drum, metal, rustle, scatter, thud, whoosh, wood } from './foley.mjs';
import { chime, horn, lute, pitch } from './instruments.mjs';
import { reverb } from './master.mjs';

/** A wooden figure touching the table. */
const piece = (c, hz) => stack(c, [
  [wood(c, { hz, tau: 0.02, click: 0.5 })],
  [thud(c, { hz: 170, tau: 0.025, puff: 0.2 }), 0, 0.35],
]);

function slide(c, seconds) {
  const felt = biquad(noise(c, seconds), c, 'bandpass', 1100, 0.9);
  shape(felt, c, (t) => 0.6 + 0.4 * Math.sin(TAU * 85 * t) ** 2);
  return peaked(shape(felt, c, hump(seconds, 0.4)));
}

export const hammer = (c, hz = 430) => stack(c, [
  [wood(c, { hz, tau: 0.03, click: 0.6 })],
  [metal(c, { hz: hz * 4.4, tau: 0.035, strike: 0.3 }), 0, 0.3],
  [thud(c, { hz: 110, tau: 0.04, puff: 0.3 }), 0, 0.5],
]);

function drumRoll(c) {
  const parts = [];
  let at = 0;
  for (let i = 0; i < 9; i++) {
    parts.push([drum(c, 'b', 0.5 + i / 16), at, 0.35 + 0.06 * i]);
    at += 0.085 - 0.006 * i;
  }
  parts.push([drum(c, 'd', 1), at, 1]);
  return [stack(c, parts), at];
}

export default [
  {
    id: 'map_select', folder: 'map', kind: 'sfx', rms: -20, variants: 3,
    make: (c, n) => piece(c, [760, 820, 700][n]),
  },
  {
    id: 'map_army_move', folder: 'map', kind: 'sfx', rms: -20, variants: 2,
    make: (c, n) => stack(c, [[slide(c, 0.22), 0, 0.35], [piece(c, [540, 500][n]), 0.24]]),
  },
  {
    id: 'map_phase_end', folder: 'map', kind: 'sfx', rms: -20,
    make: (c) => reverb(chime(c, pitch('E6'), 0.28), c, { wet: 0.2, tail: 0.4 }),
  },
  {
    id: 'map_turn_handover', folder: 'map', kind: 'sfx',
    make: (c) => reverb(stack(c, [
      [horn(c, pitch('D4'), 0.24, { bright: 3 })],
      [horn(c, pitch('A4'), 0.55, { bright: 3.2 }), 0.22],
    ]), c, { wet: 0.25, tail: 0.6 }),
  },
  {
    id: 'map_event_card', folder: 'map', kind: 'sfx', rms: -20, limit: 1,
    make: (c) => reverb(stack(c, [
      [whoosh(c, { seconds: 0.09, from: 1200, to: 4200, q: 1.5, peak: 0.3 }), 0, 0.5],
      [rustle(c, { seconds: 0.07, low: 2500, high: 8000, grains: 110 }), 0.02, 0.5],
      ...['D4', 'F4', 'A4', 'D5'].map((name, k) => [lute(c, pitch(name), 0.3, 0.7), 0.09 + 0.055 * k]),
    ]), c, { wet: 0.15, tail: 0.3 }),
  },
  {
    id: 'map_recruit', folder: 'map', kind: 'sfx',
    make: (c) => {
      const [roll, end] = drumRoll(c);
      return stack(c, [
        [roll],
        [metal(c, { hz: 2300, tau: 0.07, strike: 0.5 }), end + 0.08, 0.3],
        [metal(c, { hz: 2900, tau: 0.05, strike: 0.5 }), end + 0.15, 0.22],
      ]);
    },
  },
  {
    id: 'map_conquest', folder: 'map', kind: 'sfx', rms: -16,
    make: (c) => reverb(stack(c, [
      [drum(c, 'D', 1), 0, 1.2],
      ...['D3', 'A3', 'D4'].map((name) => [horn(c, pitch(name), 0.55, { bright: 3.5, attack: 0.03 }), 0.02, 0.5]),
    ]), c, { wet: 0.3, tail: 0.7 }),
  },
  {
    id: 'map_settlement', folder: 'economy', kind: 'sfx', rms: -20,
    make: (c) => stack(c, [
      [rustle(c, { seconds: 0.28, low: 1500, high: 7000, grains: 80, peak: 0.35 }), 0, 0.6],
      [scatter(c, { count: 5, from: 0.24, to: 0.62, make: () => coin(c), fall: 1 }), 0, 0.7],
    ]),
  },
  {
    id: 'map_build_order', folder: 'economy', kind: 'sfx', variants: 2,
    make: (c, n) => stack(c, [[hammer(c, [430, 400][n]), 0, 0.85], [hammer(c, [450, 420][n]), 0.17]]),
  },
  {
    id: 'map_build_done', folder: 'economy', kind: 'sfx',
    make: (c) => reverb(stack(c, [
      [hammer(c), 0, 0.9],
      [horn(c, pitch('G4'), 0.14, { bright: 4, attack: 0.03, release: 0.05 }), 0.17, 0.6],
      [horn(c, pitch('D5'), 0.5, { bright: 4, attack: 0.03 }), 0.31, 0.7],
    ]), c, { wet: 0.2, tail: 0.5 }),
  },
  {
    id: 'map_coin', folder: 'economy', kind: 'sfx', rms: -20, variants: 3,
    make: (c) => scatter(c, { count: 4, from: 0, to: 0.22, make: () => coin(c), fall: 1 }),
  },
];
