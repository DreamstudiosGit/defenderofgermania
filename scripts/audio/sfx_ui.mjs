// Interface sounds (assets/ui/): all under a quarter of a second, the ticks barely there.

import { biquad, hump, noise, peaked, shape, stack, TAU } from './dsp.mjs';
import { rustle, thud, whoosh, wood } from './foley.mjs';
import { lute, pitch } from './instruments.mjs';

const knock = (c, hz) => stack(c, [
  [wood(c, { hz, tau: 0.022, click: 0.15 })],
  [thud(c, { hz: hz * 0.45, tau: 0.035, puff: 0.3 }), 0, 0.8],
]);

function quill(c) {
  const stroke = biquad(noise(c, 0.11), c, 'bandpass', 4500, 1.5);
  shape(stroke, c, (t) => 0.45 + 0.55 * Math.sin(TAU * 55 * t) ** 2);
  return peaked(shape(stroke, c, hump(0.11, 0.6)));
}

export default [
  {
    id: 'ui_click', folder: 'ui', kind: 'tick', variants: 3,
    make: (c, n) => wood(c, { hz: [1180, 1250, 1120][n], tau: 0.011, click: 0.4 }),
  },
  {
    id: 'ui_hover', folder: 'ui', kind: 'tick', rms: -32, variants: 2,
    make: (c, n) => wood(c, { hz: [1750, 1850][n], tau: 0.005, click: 0.1 }),
  },
  {
    id: 'ui_focus', folder: 'ui', kind: 'tick', variants: 2,
    make: (c, n) => wood(c, { hz: [1480, 1560][n], tau: 0.008, click: 0.2 }),
  },
  {
    id: 'ui_tab', folder: 'ui', kind: 'tick', variants: 2,
    make: (c) => stack(c, [
      [rustle(c, { seconds: 0.09, low: 3000, high: 9000, grains: 120, peak: 0.25 })],
      [whoosh(c, { seconds: 0.07, from: 1800, to: 5200, q: 1.5, peak: 0.3 }), 0, 0.5],
    ]),
  },
  {
    id: 'ui_slider', folder: 'ui', kind: 'tick', variants: 2,
    make: (c, n) => wood(c, { hz: [2050, 2180][n], tau: 0.004, click: 0.15 }),
  },
  {
    id: 'ui_back', folder: 'ui', kind: 'tick', variants: 2,
    make: (c, n) => stack(c, [
      [wood(c, { hz: [330, 310][n], tau: 0.028, click: 0.2 })],
      [thud(c, { hz: 150, tau: 0.03, puff: 0.2 }), 0, 0.6],
    ]),
  },
  {
    id: 'ui_confirm', folder: 'ui', kind: 'ui',
    make: (c) => biquad(stack(c, [
      [lute(c, pitch('D4'), 0.2, 0.6)],
      [lute(c, pitch('A4'), 0.2, 0.7), 0.075],
    ]), c, 'lowpass', 3200),
  },
  {
    id: 'ui_error', folder: 'ui', kind: 'ui',
    make: (c) => stack(c, [[knock(c, 210)], [knock(c, 196), 0.095, 0.9]]),
  },
  {
    id: 'ui_modal_open', folder: 'ui', kind: 'ui', variants: 2,
    make: (c) => rustle(c, { seconds: 0.22, low: 1800, high: 7500, grains: 90, peak: 0.3 }),
  },
  {
    id: 'ui_save', folder: 'ui', kind: 'ui',
    make: (c) => stack(c, [
      [quill(c), 0, 0.8],
      [wood(c, { hz: 380, tau: 0.014, click: 0.2 }), 0.12, 0.6],
      [thud(c, { hz: 115, tau: 0.028, puff: 0.5 }), 0.12],
    ]),
  },
];
