// The music of the ventures (assets/combat/): the joust (a jig in G mixolydian: tabor and
// pipes, then the stands), the siege (D dorian, slow: war drum and drone, then tension), the
// raid (D dorian: a stealthy pulse, then the alarm) and the merchant train (G mixolydian:
// a road song on the lute, then the ambush).

import {
  bells, hum, layer, lutes, mutedLutes, pipes, shawms, strokes, vielles,
} from './band.mjs';
import { mixLooped } from './dsp.mjs';
import { crowd, whoop } from './foley.mjs';
import { loop, times } from './score.mjs';

// The joust counts in quavers: six to the bar, 96 dotted crotchets a minute.
const JOUST = { beats: 144, bpm: 288 };
const SIEGE = { beats: 32, bpm: 64 };
const RAID = { beats: 48, bpm: 96 };
const MERCHANT = { beats: 48, bpm: 96 };

const twice = (notes) => times(notes, 2);

const JIG = [
  'G4^ B4 D5 D5^ E5 D5 | B4^ D5 B4 G4:2^ A4 | B4^ C5 D5 E5^ D5 B4 | A4:2^ B4 A4:3',
  'D5:2^ E5 F5:2^ E5 | D5^ B4 G4 B4:2^ D5 | C5:2^ D5 E5^ D5 C5 | B4^ A4 G4 A4:3',
  'G5:2^ E5 D5:2^ B4 | C5^ D5 E5 D5:2^ B4 | A4^ B4 C5 B4^ A4 F4 | G4:3^ G4:2 -',
].map(twice).join(' | ');

const JIG_LUTE = [
  'G2 D3+G3 | G2 D3+G3 | G2 C3+G3 | D3 A3+D4',
  'D3 A3+D4 | G2 D3+G3 | C3 G3+C4 | D3 A3+D4',
  'G2 D3+G3 | C3 G3+C4 | F2 C3+F3 | G2 D3+G3',
].map(twice).join(' | ');

function stands(c) {
  const count = loop(c, JOUST.beats, JOUST.bpm).length;
  const calls = new Float64Array(count);
  for (let i = 0; i < 14; i++) {
    mixLooped(calls, whoop(c, c.range(0.5, 1.1)), Math.floor(c.rand() * count), c.range(0.3, 0.6));
  }
  return layer(c, { ...JOUST, wet: 0.12 }, [
    { name: 'stands', buffer: crowd(c, count / c.sr, { voices: 10, loop: true }) },
    { name: 'calls', buffer: calls },
  ]);
}

const STEALTH = `D3 -:.5 D3:.5 F3 E3 | D3 -:.5 A2:.5 C3 - |
  D3 -:.5 D3:.5 G3 F3 | E3 -:.5 C3:.5 D3 -`;
const ALARM = `D4:.5^ D4:.5 - C4:.5 D4:.5 - | F4^ E4 D4:2 |
  D4:.5^ D4:.5 - F4:.5 G4:.5 - | A4^ G4 E4:2`;

const ROAD = [
  'G4^ B4:.5 D5:.5 D5 B4 | C5^ E5:.5 C5:.5 D5:2 | B4^ D5:.5 B4:.5 A4 F4 | G4^ A4 G4:2',
  'F4^ A4:.5 C5:.5 C5 A4 | G4^ B4:.5 D5:.5 D5:2 | E5^ D5:.5 C5:.5 B4 A4 | G4:3^ -',
];
const ROAD_BASS = ['G2 D3 | C3 G2 | G2 F2 | G2 D3', 'F2 C3 | G2 D3 | C3 D3 | G2:3 -:1'];
const AMBUSH = `G4:.5^ G4:.5 B4:.5 G4:.5 D5 C5 | B4:.5^ B4:.5 D5:.5 B4:.5 F5 E5 |
  D5:.5^ D5:.5 C5:.5 B4:.5 A4 F4 | G4:2^ -:2`;

export default [
  {
    track: 'joust', layer: 'pipes', folder: 'combat', rms: -20,
    make: (c) => layer(c, JOUST, [
      { ...hum(c, JOUST, [['G3', 1], ['D4', 0.6]], { dark: 1400 }), gain: 0.09 },
      { voice: strokes, gain: 0.45, notes: times('d^ - b_ d b_ b_', 24) },
      { voice: pipes, gain: 0.17, hold: 0.9, notes: JIG },
      { voice: lutes, step: 3, gain: 0.4, notes: JIG_LUTE },
    ]),
  },
  { track: 'joust', layer: 'crowd', folder: 'combat', rms: -22, make: stands },
  {
    track: 'siege', layer: 'drums', folder: 'combat', rms: -20,
    make: (c) => layer(c, { ...SIEGE, wet: 0.22 }, [
      { ...hum(c, SIEGE, [['D2', 1], ['A2', 0.6]], { dark: 600 }), gain: 0.11 },
      { voice: strokes, gain: 0.6, notes: times('D^:2.5 d_:.5 d:1 | D^:2 -:1 t_:1', 4) },
      {
        voice: lutes, gain: 0.6,
        notes: `D3:2 -:2 | -:2 F3 E3 | D3:2 -:2 | -:2 C3 E3 |
          D3:2 -:2 | -:2 F3 G3 | A3:2 -:2 | - G3 F3 E3`,
      },
    ]),
  },
  {
    track: 'siege', layer: 'tension', folder: 'combat', rms: -22,
    make: (c) => layer(c, { ...SIEGE, wet: 0.25 }, [
      { voice: vielles, step: 4, gain: 0.2, notes: 'A3 A3 B3 A3 C4 B3 A3 G3' },
      { voice: vielles, gain: 0.16, notes: 'E4:8 F4:8 E4:8 D4:4 E4:4' },
      { voice: mutedLutes, step: 0.5, gain: 0.7, notes: times('D3 D3_ D3_ D3_', 16) },
    ]),
  },
  {
    track: 'raid', layer: 'stealth', folder: 'combat', rms: -21,
    make: (c) => layer(c, { ...RAID, wet: 0.12 }, [
      { ...hum(c, RAID, [['D2', 1], ['A2', 0.4]], { dark: 500 }), gain: 0.07 },
      { voice: mutedLutes, gain: 0.5, notes: times(STEALTH, 3) },
      { voice: strokes, gain: 0.5, notes: times('- k_', 24) },
      { voice: lutes, gain: 0.6, notes: '-:14 A4_:2 | -:14 D5_:2 | -:14 A4_:2' },
    ]),
  },
  {
    track: 'raid', layer: 'alarm', folder: 'combat', rms: -22,
    make: (c) => layer(c, RAID, [
      { voice: strokes, step: 0.5, gain: 0.5, notes: times('d^ k t k d d t k', 12) },
      { voice: strokes, gain: 0.5, notes: times('D^:2', 24) },
      { voice: bells, gain: 0.45, notes: times('E5:4', 12) },
      { voice: shawms, gain: 0.3, hold: 0.9, notes: times(ALARM, 3) },
    ]),
  },
  {
    track: 'merchant', layer: 'road', folder: 'combat', rms: -20,
    make: (c) => layer(c, MERCHANT, [
      { ...hum(c, MERCHANT, [['G2', 1], ['D3', 0.7]]), gain: 0.07 },
      { voice: lutes, gain: 0.5, loose: 0.005, notes: [ROAD[0], ROAD[0], ROAD[1]].join(' | ') },
      {
        voice: lutes, step: 2, gain: 0.45,
        notes: [ROAD_BASS[0], ROAD_BASS[0], ROAD_BASS[1]].join(' | '),
      },
      { voice: strokes, gain: 0.3, notes: times('c:.5 c_:.5 -:1', 24) },
    ]),
  },
  {
    track: 'merchant', layer: 'ambush', folder: 'combat', rms: -22,
    make: (c) => layer(c, MERCHANT, [
      { voice: strokes, step: 0.5, gain: 0.5, notes: times('d^ - t d - d t -', 12) },
      { voice: strokes, gain: 0.5, notes: times('D^:4', 12) },
      { voice: shawms, gain: 0.25, hold: 0.9, notes: times(AMBUSH, 3) },
    ]),
  },
];
