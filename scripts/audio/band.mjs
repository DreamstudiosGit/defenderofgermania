// The players of the music loops: voices for score.mjs and the room they play in.

import { mix, toDb } from './dsp.mjs';
import { drum } from './foley.mjs';
import { bell, drone, lute, mutedLute, pipe, pitch, shawm, vielle } from './instruments.mjs';
import { loopThrough, reverb, rms } from './master.mjs';
import { loop, play, tuned } from './score.mjs';

export const lutes = tuned(lute);
export const mutedLutes = tuned(mutedLute);
export const pipes = tuned(pipe);
export const shawms = tuned(shawm);
export const vielles = tuned(vielle);
export const bells = (c, name) => bell(c, pitch(name), 0.5);
export const strokes = (c, name, seconds, velocity) => drum(c, name, velocity);

/**
 * Seconds before the first beat: the loop closes in the hush before the downbeat instead of
 * inside its attack, and notes played a little early stay in front of the others.
 */
const LEAD_IN = 0.02;

/** The drone of a piece as a ready part: `voices` are [note name, level]. */
export function hum(c, piece, voices, options) {
  const tones = voices.map(([name, level]) => [pitch(name), level]);
  return { name: 'drone', buffer: drone(c, loop(c, piece.beats, piece.bpm).length, tones, options) };
}

/**
 * One layer of a track: a loop of `beats` at `bpm` holding every part, in a small hall. A
 * part is a note list for play() or a ready loop { buffer, gain } (a drone, a bed). All
 * layers of a track pass the same beats and bpm, so they are equally long to the sample.
 * AUDIO_PARTS=1 prints how loud each part is in the mix.
 */
export function layer(c, { beats, bpm, wet = 0.16, room = 0.78 }, parts) {
  const out = loop(c, beats, bpm);
  for (const part of parts) {
    const solo = loop(c, beats, bpm);
    if (part.buffer) mix(solo, part.buffer, 0, part.gain ?? 1);
    else play(c, solo, part, { bpm, beats, wrap: true, start: LEAD_IN });
    if (process.env.AUDIO_PARTS) {
      const what = part.name ?? (part.notes ?? '').slice(0, 24);
      console.log(`    part ${toDb(rms(solo)).toFixed(1).padStart(6)} dB  ${what}`);
    }
    mix(out, solo);
  }
  if (wet <= 0) return out;
  return loopThrough(out, (twice) => reverb(twice, c, { room, wet, tail: 0 }));
}
