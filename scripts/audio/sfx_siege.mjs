// Siege sounds (assets/combat/): the trebuchet, the stone in the air, what it hits, fire.

import {
  TAU, hump, line, lowpass1, modal, noise, peaked, shape, sine, stack, sweep,
} from './dsp.mjs';
import { crumb, scatter, snap, thud, wood } from './foley.mjs';
import { armRelease, crunch } from './sfx_battle.mjs';

const rumble = (c, seconds, hz) => peaked(lowpass1(lowpass1(noise(c, seconds), c, hz), c, hz));

function flight(c) {
  const seconds = 1.5;
  const arc = hump(seconds, 0.45);
  const air = sweep(noise(c, seconds), c, 'band', (t) => 300 + 500 * arc(t), 1.4);
  shape(air, c, (t) => arc(t) * (1 + 0.25 * Math.sin(TAU * 9 * t)));
  const low = shape(rumble(c, seconds, 160), c, hump(seconds, 0.5));
  return stack(c, [[peaked(air)], [low, 0, 0.35]]);
}

function ignite(c) {
  const flare = hump(0.9, 0.25);
  const flame = sweep(noise(c, 1), c, 'low', (t) => 180 + 1700 * flare(t), 0.8);
  shape(flame, c, line([[0, 0], [0.1, 1], [0.3, 0.7], [1, 0]]));
  const thump = shape(sine(c, 0.5, 58), c, line([[0, 0], [0.03, 1], [0.5, 0]]));
  const crackle = scatter(c, { count: 18, from: 0.15, to: 0.95, make: () => crumb(c, 2500, 6000), fall: 1 });
  return stack(c, [[peaked(flame)], [thump, 0.02, 0.6], [crackle, 0, 0.2]]);
}

function collapse(c) {
  const ground = shape(rumble(c, 2, 170), c, line([[0, 0], [0.15, 1], [1.2, 0.8], [2, 0]]));
  const stones = scatter(c, {
    count: 16, from: 0.05, to: 1.6, fall: 1.2,
    make: () => stack(c, [
      [thud(c, { hz: c.range(55, 110), tau: c.range(0.06, 0.12), puff: 0.8, puffHz: 900 })],
      [wood(c, { hz: c.range(250, 700), tau: 0.03, click: 0.6 }), 0, 0.4],
    ]),
  });
  const rubble = scatter(c, { count: 40, from: 0.1, to: 1.9, make: () => crumb(c, 900, 4500), fall: 1.1 });
  return stack(c, [[ground], [stones, 0, 0.7], [rubble, 0, 0.3]]);
}

function counterfire(c) {
  const seconds = 0.7;
  const fall = (t) => 2300 * (650 / 2300) ** (t / seconds);
  const whistle = stack(c, [
    [sine(c, seconds, fall), 0, 0.35],
    [peaked(sweep(noise(c, seconds), c, 'band', fall, 6))],
  ]);
  shape(whistle, c, (t) => (t / seconds) ** 1.5 * Math.min(1, (seconds - t) / 0.012));
  return stack(c, [
    [whistle, 0, 0.8],
    [thud(c, { hz: 55, tau: 0.2, puff: 1, puffHz: 700 }), seconds],
    [crunch(c, 1200, 0.09), seconds, 0.5],
    [scatter(c, { count: 8, from: seconds + 0.04, to: seconds + 0.5, make: () => crumb(c) }), 0, 0.3],
  ]);
}

export default [
  {
    id: 'siege_release', folder: 'combat', kind: 'sfx', rms: -16, variants: 2,
    make: (c) => armRelease(c, 0.3, 0.16),
  },
  { id: 'siege_whoosh', folder: 'combat', kind: 'sfx', rms: -20, limit: 1.6, make: flight },
  {
    id: 'siege_hit_stone', folder: 'combat', kind: 'hit', variants: 2,
    make: (c) => stack(c, [
      [thud(c, { hz: 72, tau: 0.12, puff: 0.9, puffHz: 900 }), 0, 0.8],
      [crunch(c, 2200, 0.08), 0, 0.7],
      [snap(c, 3500, 0.006, 0.5), 0, 0.7],
      [modal(c, 0.2, [
        [c.range(800, 1100), 1, 0.02], [c.range(1500, 2000), 0.7, 0.014],
        [c.range(2600, 3300), 0.4, 0.01],
      ]), 0, 0.7],
      [scatter(c, { count: 12, from: 0.05, to: 0.6, make: () => crumb(c, 1500, 5000) }), 0, 0.45],
    ]),
  },
  {
    id: 'siege_hit_wood', folder: 'combat', kind: 'hit', variants: 2,
    make: (c) => stack(c, [
      [wood(c, { hz: 190, tau: 0.07, click: 0.8 })],
      [thud(c, { hz: 78, tau: 0.11, puff: 0.7 }), 0, 0.9],
      [scatter(c, {
        count: 6, to: 0.18, fall: 1,
        make: () => wood(c, { hz: c.range(350, 1200), tau: c.range(0.012, 0.03), click: 0.8 }),
      }), 0.01, 0.5],
    ]),
  },
  {
    id: 'siege_miss', folder: 'combat', kind: 'sfx', variants: 2,
    make: (c) => lowpass1(stack(c, [
      [thud(c, { hz: 58, tau: 0.15, puff: 0.9, puffHz: 320 })],
      [scatter(c, { count: 7, from: 0.06, to: 0.45, make: () => crumb(c, 500, 1600) }), 0, 0.25],
    ]), c, 2000),
  },
  { id: 'siege_ignite', folder: 'combat', kind: 'sfx', make: ignite },
  { id: 'siege_collapse', folder: 'combat', kind: 'hit', limit: 2.2, make: collapse },
  { id: 'siege_counterfire', folder: 'combat', kind: 'sfx', rms: -16, make: counterfire },
];
