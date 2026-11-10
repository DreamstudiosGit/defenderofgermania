// Note lists for the music and the stings of scripts/make_audio.mjs.
//
// A part is a string of notes: "D4:2 F4 -:.5 D3+A3^ | d t_:2". A note is a name, an optional
// "^" (accent) or "_" (soft) and an optional ":beats" (else the part's step). "-" is a rest,
// "+" joins the notes of a chord, "|" only marks a bar. What a name means is up to the voice:
// a pitch (D4, F#3) for an instrument, a stroke (d, t, k) for a drum.

import { mix, mixLooped } from './dsp.mjs';
import { pitch } from './instruments.mjs';

const NOTE = /^([^:^_]+)([\^_]?)(?::(\d*\.?\d+))?([\^_]?)$/;
const VELOCITY = { '': 0.75, '^': 1, _: 0.5 };

export function parse(notes, step = 1) {
  const events = [];
  let at = 0;
  for (const token of notes.split(/[\s|]+/).filter(Boolean)) {
    const match = NOTE.exec(token);
    if (!match) throw new Error(`not a note: "${token}"`);
    const beats = match[3] === undefined ? step : Number(match[3]);
    if (match[1] !== '-') {
      const velocity = VELOCITY[match[2] || match[4]];
      events.push({ at, beats, names: match[1].split('+'), velocity });
    }
    at += beats;
  }
  return { events, beats: at };
}

export const times = (notes, count) => Array(count).fill(notes).join(' | ');

/** A voice for pitched notes from an instrument(c, hz, seconds, velocity). */
export const tuned = (instrument) => (c, name, seconds, velocity) =>
  instrument(c, pitch(name), seconds, velocity);

/**
 * Plays a part into `target`. part: { notes, voice(c, name, seconds, velocity), step = 1,
 * gain = 1, hold = 1 (share of its beats a note sounds), loose = 0 (seconds of human
 * timing) }. With `wrap`, what rings past the end comes back in at the start, so the buffer
 * loops; `beats` is the length every part of the piece must have.
 */
export function play(c, target, part, { bpm, wrap = false, beats = null, start = 0 }) {
  const parsed = parse(part.notes, part.step ?? 1);
  if (beats !== null && Math.abs(parsed.beats - beats) > 1e-6) {
    throw new Error(`part has ${parsed.beats} beats, the piece ${beats}: ${part.notes}`);
  }
  const beat = 60 / bpm;
  for (const event of parsed.events) {
    const seconds = event.beats * beat * (part.hold ?? 1);
    const late = part.loose ? c.range(-part.loose, part.loose) : 0;
    const at = Math.round((start + event.at * beat + late) * c.sr);
    const gain = (part.gain ?? 1) * (0.4 + 0.6 * event.velocity);
    for (const name of event.names) {
      const note = part.voice(c, name, seconds, event.velocity);
      if (wrap) mixLooped(target, note, at, gain);
      else mix(target, note, at, gain);
    }
  }
  return target;
}

/** An empty loop of that many beats. */
export const loop = (c, beats, bpm) => new Float64Array(Math.round(((beats * 60) / bpm) * c.sr));
