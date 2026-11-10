// The calm music (assets/ui/): the main menu (D dorian, one layer) and the war table
// (G mixolydian in three-four: lute and drone, then a light pipe melody).

import { hum, layer, lutes, pipes, strokes } from './band.mjs';
import { times } from './score.mjs';

const MENU = { beats: 32, bpm: 64 };
const MAP = { beats: 36, bpm: 72 };

function menu(c) {
  return layer(c, { ...MENU, wet: 0.2 }, [
    { ...hum(c, MENU, [['D2', 1], ['A2', 0.7], ['D3', 0.3]]), gain: 0.09 },
    {
      voice: lutes, step: 0.5, gain: 0.5, loose: 0.006,
      notes: `D3^ A3 D4 F4 A4 F4 D4 A3 | D3^ A3 D4 F4 A4 F4 E4 D4 |
        C3^ G3 C4 E4 G4 E4 C4 G3 | D3^ A3 D4 F4 A4 D5 A4 F4 |
        F3^ C4 F4 A4 C5 A4 F4 C4 | C3^ G3 C4 E4 G4 E4 D4 C4 |
        A2^ E3 A3 C4 E4 C4 B3 A3 | D3^ A3 D4 A3 D3:2`,
    },
    {
      voice: pipes, gain: 0.09, hold: 0.95,
      notes: `A4:2 D5:2 | C5 B4 A4:2 | G4:2 E4 G4 | A4:3 -:1 |
        C5:2 A4 C5 | B4 G4 E4:2 | C5 B4 A4 G4 | F4 E4 D4:2`,
    },
    { voice: strokes, notes: times('d_:4', 8), gain: 0.25 },
  ]);
}

const MAP_LUTE = `G2^ D3 G3 B3 D4 B3 | G2^ D3 G3 B3 D4 G3 | F2^ C3 F3 A3 C4 A3 | G2^ D3 G3 B3 D4 B3 |
  C3^ G3 C4 E4 G4 E4 | G2^ D3 G3 B3 D4 B3 | F2^ C3 F3 A3 C4 A3 | C3^ G3 C4 E4 C4 G3 |
  G2^ D3 G3 B3 D4 B3 | D3^ A3 D4 F4 A4 F4 | F2^ C3 F3 A3 C4 A3 | G2^ D3 G3 D3 G2:1`;

const MAP_MELODY = `D5:2 B4 | G4:2 A4 | A4 C5 A4 | B4:2 D5 |
  E5:2 C5 | D5 B4 G4 | A4:2 F4 | E4 G4 C5 |
  B4:2 G4 | A4 F4 D4 | F4 A4 C5 | G4:2 -`;

export default [
  { track: 'menu', layer: 'main', folder: 'ui', rms: -20, make: menu },
  {
    track: 'map', layer: 'lute', folder: 'ui', rms: -20,
    make: (c) => layer(c, MAP, [
      { ...hum(c, MAP, [['G2', 1], ['D3', 0.7]]), gain: 0.1 },
      { voice: lutes, step: 0.5, gain: 0.5, loose: 0.006, notes: MAP_LUTE },
    ]),
  },
  {
    track: 'map', layer: 'melody', folder: 'ui', rms: -22,
    make: (c) => layer(c, { ...MAP, wet: 0.22 }, [
      { voice: pipes, gain: 0.3, hold: 0.95, notes: MAP_MELODY },
    ]),
  },
];
