// Stings (assets/ui/): three to six seconds of brass, bells, lute and drums that play over
// the music when a battle, a venture or the campaign is decided.

import { line, shape, silence } from './dsp.mjs';
import { drum } from './foley.mjs';
import { bell, chime, horn, lute, pitch } from './instruments.mjs';
import { reverb } from './master.mjs';
import { play, tuned } from './score.mjs';

const brass = (c, name, seconds, velocity) => horn(c, pitch(name), seconds, {
  bright: 2.4 + 2.4 * velocity, attack: 0.035, release: Math.min(0.3, seconds * 0.4),
});
const mellow = (c, name, seconds, velocity) => horn(c, pitch(name), seconds, {
  bright: 1.4 + velocity, attack: 0.12, release: Math.min(0.5, seconds * 0.4), breath: 0.05,
});
const bells = (c, name) => bell(c, pitch(name), 1.1);
const chimes = (c, name) => chime(c, pitch(name), 0.5);
const drums = (c, name, seconds, velocity) => drum(c, name, velocity);
const lutes = tuned(lute);

const RING = 5;

/** The parts played one over the other, in a hall; what still rings fades out by `ends`. */
function sting(c, { bpm, ends, wet = 0.3 }, parts) {
  const dry = silence(c, ends + RING);
  for (const part of parts) play(c, dry, part, { bpm });
  const out = reverb(dry, c, { room: 0.84, wet, tail: 0 });
  shape(out, c, line([[0, 1], [ends - 0.9, 1], [ends, 0]]));
  return out.slice(0, Math.round(ends * c.sr));
}

export default [
  {
    id: 'sting_battle_won', folder: 'ui', kind: 'sting',
    make: (c) => sting(c, { bpm: 132, ends: 3.9 }, [
      { voice: brass, notes: 'D4:.5 D4:.5 A4 D5:4^', gain: 0.9 },
      { voice: brass, notes: 'A3:.5 A3:.5 D4 A4:4', gain: 0.6 },
      { voice: brass, notes: 'D3:2 D3:4', gain: 0.55 },
      { voice: drums, notes: 'd^:.5 d:.5 d^ D^:4', gain: 0.9 },
    ]),
  },
  {
    id: 'sting_battle_lost', folder: 'ui', kind: 'sting',
    make: (c) => sting(c, { bpm: 72, ends: 4.9 }, [
      { voice: mellow, notes: 'A3 F3 D3:2.5', gain: 0.9 },
      { voice: mellow, notes: 'D2:4.5_', gain: 0.6 },
      { voice: drums, notes: 'D:2 D_:2.5', gain: 0.9 },
    ]),
  },
  {
    id: 'sting_success', folder: 'ui', kind: 'sting',
    make: (c) => sting(c, { bpm: 126, ends: 4 }, [
      { voice: lutes, notes: 'G3 B3 D4 G4 B4 D5:2^', step: 0.5 },
      { voice: lutes, notes: '-:2.5 G3+D4:2', gain: 0.7 },
      { voice: chimes, notes: '-:2.5 G5:2', gain: 0.35 },
    ]),
  },
  {
    id: 'sting_fail', folder: 'ui', kind: 'sting',
    make: (c) => sting(c, { bpm: 90, ends: 3.9 }, [
      { voice: lutes, notes: 'D4 C4 A3 F3 D3:2^', step: 0.5 },
      { voice: mellow, notes: '-:2 D2:2_', gain: 0.5 },
      { voice: drums, notes: '-:2 d_:2', gain: 0.7 },
    ]),
  },
  {
    id: 'sting_coronation', folder: 'ui', kind: 'sting', limit: 6,
    make: (c) => sting(c, { bpm: 96, ends: 5.95, wet: 0.35 }, [
      { voice: brass, notes: 'D4:.5 D4:.5 A4 G4:.5 A4:.5 B4 D5:4^', gain: 0.9 },
      { voice: brass, notes: 'A3:.5 A3:.5 D4 D4:.5 D4:.5 G4 A4:4', gain: 0.6 },
      { voice: brass, notes: 'D3:2 G3:2 D3:4', gain: 0.55 },
      { voice: bells, notes: 'D5 C5 B4 A4 D5 A4 D4:2', gain: 0.3 },
      { voice: drums, notes: 'D^:2 D:2 D^ d:.5 d:.5 D^:2', gain: 0.9 },
    ]),
  },
  {
    id: 'sting_victory', folder: 'ui', kind: 'sting',
    make: (c) => sting(c, { bpm: 120, ends: 5.4 }, [
      { voice: brass, notes: 'G4:.5 G4:.5 B4:.5 D5:.5 G5:1.5 F5:.5 G5:4^', gain: 0.9 },
      { voice: brass, notes: 'D4:.5 D4:.5 G4:.5 B4:.5 D5:1.5 C5:.5 D5:4', gain: 0.6 },
      { voice: brass, notes: 'G3:2 G3:2 G3:4', gain: 0.55 },
      { voice: lutes, notes: '-:4 G3+D4+G4+B4:4^', gain: 0.6 },
      { voice: chimes, notes: '-:4 D6 B5 G5:2', gain: 0.2 },
      { voice: drums, notes: 'd^:.5 d:.5 d:.5 d:.5 D^:1.5 d:.5 D^:4', gain: 0.9 },
    ]),
  },
  {
    id: 'sting_defeat', folder: 'ui', kind: 'sting', limit: 6,
    make: (c) => sting(c, { bpm: 66, ends: 5.95 }, [
      { voice: mellow, notes: 'D4 C4 A3 D3:2.5', gain: 0.9 },
      { voice: mellow, notes: 'D2:5.5_', gain: 0.6 },
      { voice: bells, notes: 'D4:2.75 D4:2.75_', gain: 0.4 },
      { voice: drums, notes: 'D:2.75 D_:2.75', gain: 0.8 },
    ]),
  },
];
