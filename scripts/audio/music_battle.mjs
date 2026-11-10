// The battle music (assets/combat/), D dorian at a march: drums, drone and a lute ostinato;
// then the shawm's melody; then a bed of clashing arms under distant shouting.

import { hum, layer, lutes, shawms, strokes } from './band.mjs';
import { lowpass1, mixLooped } from './dsp.mjs';
import { crowd, metal, snap, wood } from './foley.mjs';
import { loopThrough } from './master.mjs';
import { loop, times } from './score.mjs';

const BATTLE = { beats: 64, bpm: 128 };

const OSTINATO = {
  Dm: 'D3^ D3 A3 D3 C4 D3 A3 D3',
  C: 'C3^ C3 G3 C3 B3 C3 G3 C3',
  Am: 'A2^ A2 E3 A2 G3 A2 E3 A2',
  F: 'F2^ F2 C3 F2 D3 F2 C3 F2',
  CAm: 'C3^ C3 G3 C3 A2^ A2 E3 A2',
};
const CHORDS = [
  'Dm', 'Dm', 'C', 'Dm', 'Dm', 'Dm', 'C', 'Am', 'F', 'F', 'C', 'C', 'Dm', 'Dm', 'CAm', 'Dm',
];
const BEAT = 'd^ - t d d - t t';
const FILL = 'd^ t t d t t d^ t';

const LEAD = `D4^ A3:.5 D4:.5 E4 F4 | E4 D4:.5 C4:.5 D4:2 | E4^ C4:.5 E4:.5 G4 E4 | D4:1.5 C4:.5 A3:2 |
  D4^ A3:.5 D4:.5 E4 F4 | G4 F4:.5 E4:.5 D4:2 | E4:.5 D4:.5 C4:.5 B3:.5 C4 E4 | C4 B3 A3:2 |
  F4^ A4:.5 F4:.5 C4:2 | A4:1.5^ G4:.5 F4 A4 | G4:1.5 F4:.5 E4 G4 | E4 D4:.5 C4:.5 G3:2 |
  D4:.5 E4:.5 F4:.5 G4:.5 A4^ F4 | G4:.5 F4:.5 E4:.5 D4:.5 E4 C4 | E4 D4 C4 B3 | D4:3^ -`;

const BLADE = [1, 2.76, 5.4, 8.93];

function clash(c) {
  const count = loop(c, BATTLE.beats, BATTLE.bpm).length;
  const shouting = crowd(c, count / c.sr, { voices: 9, loop: true });
  const roar = loopThrough(shouting, (twice) => lowpass1(twice, c, 1400));
  const blows = new Float64Array(count);
  for (let i = 0; i < 150; i++) {
    const kind = c.rand();
    let blow;
    if (kind < 0.45) {
      blow = metal(c, { hz: c.range(900, 3200), tau: c.range(0.04, 0.12), strike: 0.5, ratios: BLADE });
    } else if (kind < 0.8) blow = snap(c, c.range(1800, 4500), c.range(0.006, 0.02));
    else blow = wood(c, { hz: c.range(300, 900), tau: 0.025 });
    mixLooped(blows, blow, Math.floor(c.rand() * count), c.range(0.12, 0.4));
  }
  return layer(c, { ...BATTLE, wet: 0.2 }, [
    { name: 'roar', buffer: roar, gain: 0.5 },
    { name: 'blows', buffer: blows },
  ]);
}

export default [
  {
    track: 'battle', layer: 'drums', folder: 'combat', rms: -20,
    make: (c) => layer(c, BATTLE, [
      { ...hum(c, BATTLE, [['D2', 1], ['A2', 0.7]]), gain: 0.12 },
      { voice: strokes, step: 0.5, gain: 0.5, notes: times([BEAT, BEAT, BEAT, FILL].join(' | '), 4) },
      { voice: strokes, gain: 0.6, notes: times('D^:4', 16) },
      {
        voice: lutes, step: 0.5, gain: 0.3, hold: 0.8,
        notes: CHORDS.map((chord) => OSTINATO[chord]).join(' | '),
      },
    ]),
  },
  {
    track: 'battle', layer: 'lead', folder: 'combat', rms: -22,
    make: (c) => layer(c, { ...BATTLE, wet: 0.2 }, [
      { voice: shawms, gain: 0.3, hold: 0.92, notes: LEAD },
    ]),
  },
  { track: 'battle', layer: 'clash', folder: 'combat', rms: -22, make: clash },
];
