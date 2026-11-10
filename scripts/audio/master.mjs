// Room, loudness and edges: the last steps of every file of scripts/make_audio.mjs.

import { fromDb, toDb } from './dsp.mjs';

const COMBS = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
const ALLPASSES = [556, 441, 341, 225];

export function peak(buffer) {
  let top = 0;
  for (let i = 0; i < buffer.length; i++) top = Math.max(top, Math.abs(buffer[i]));
  return top;
}

export function energy(buffer) {
  let sum = 0;
  for (let i = 0; i < buffer.length; i++) sum += buffer[i] * buffer[i];
  return sum;
}

export const rms = (buffer) => Math.sqrt(energy(buffer) / buffer.length);

/**
 * A cheap room (Schroeder / Freeverb: damped feedback combs, then allpasses). `wet` is the
 * share of the dry signal's energy that the room adds; the buffer grows by `tail` seconds.
 */
export function reverb(buffer, c, { room = 0.8, damp = 0.35, wet = 0.25, tail = 1 } = {}) {
  const length = buffer.length + Math.round(tail * c.sr);
  const echo = new Float64Array(length);
  const ratio = c.sr / 44100;
  for (const size of COMBS) {
    const line = new Float64Array(Math.round(size * ratio));
    let at = 0;
    let low = 0;
    for (let i = 0; i < length; i++) {
      const out = line[at];
      low = out * (1 - damp) + low * damp;
      line[at] = (i < buffer.length ? buffer[i] : 0) + low * room;
      at = (at + 1) % line.length;
      echo[i] += out;
    }
  }
  for (const size of ALLPASSES) {
    const line = new Float64Array(Math.round(size * ratio));
    let at = 0;
    for (let i = 0; i < length; i++) {
      const delayed = line[at];
      line[at] = echo[i] + delayed * 0.5;
      at = (at + 1) % line.length;
      echo[i] = delayed - echo[i];
    }
  }
  const dry = energy(buffer);
  const gain = dry > 0 ? Math.sqrt((wet * dry) / Math.max(energy(echo), 1e-12)) : 0;
  for (let i = 0; i < length; i++) echo[i] = echo[i] * gain + (i < buffer.length ? buffer[i] : 0);
  return echo;
}

/** What a looping buffer sounds like through `process` once the loop has gone round. */
export function loopThrough(buffer, process) {
  const twice = new Float64Array(buffer.length * 2);
  twice.set(buffer);
  twice.set(buffer, buffer.length);
  return process(twice).slice(buffer.length, buffer.length * 2);
}

/** Leaves samples below `knee` alone and bends the rest so nothing passes `ceiling`. */
export function softClip(buffer, ceiling, knee) {
  const room = ceiling - knee;
  for (let i = 0; i < buffer.length; i++) {
    const size = Math.abs(buffer[i]);
    if (size > knee) buffer[i] = Math.sign(buffer[i]) * (knee + room * Math.tanh((size - knee) / room));
  }
  return buffer;
}

/**
 * Look-ahead limiter: turns the gain down ahead of every peak above `ceiling` and lets it
 * come back slowly, so a peak is lowered without bending the wave the way a clip does. The
 * gain is the needed reduction held over the look-ahead and then averaged over the same
 * span, which can never leave a sample above the ceiling.
 */
export function limit(buffer, c, ceiling, { ahead = 0.003, release = 0.1 } = {}) {
  const count = buffer.length;
  const span = Math.max(1, Math.round(ahead * c.sr));
  const recover = 1 - Math.exp(-1 / (release * c.sr));
  const need = new Float64Array(count);
  let held = 1;
  for (let i = 0; i < count; i++) {
    const size = Math.abs(buffer[i]);
    held += (1 - held) * recover;
    if (size * held > ceiling) held = ceiling / size;
    need[i] = held;
  }
  const early = new Float64Array(count);
  for (let i = 0; i < count; i++) {
    let lowest = need[i];
    for (let k = 1; k < span && i + k < count; k++) lowest = Math.min(lowest, need[i + k]);
    early[i] = lowest;
  }
  // Before the first sample the window holds early[0], so a peak right at the start is met.
  let sum = span * early[0];
  for (let i = 0; i < count; i++) {
    sum += early[i] - early[Math.max(0, i - span)];
    buffer[i] *= Math.min(1, sum / span);
  }
  return buffer;
}

/**
 * Brings the buffer to an RMS level under a peak ceiling: gain first, and where peaks would
 * pass the ceiling the limiter takes them back. A loop is soft-clipped instead (`looped`): a
 * clip has no memory, so the loop still closes. Returns by how many dB the peaks came down
 * against the rest.
 */
export function level(buffer, c, rmsDb, { peakDb = -1, looped = false } = {}) {
  const target = fromDb(rmsDb);
  const ceiling = fromDb(peakDb) * 0.999;
  const crest = () => toDb(peak(buffer) / rms(buffer));
  if (rms(buffer) <= 0) return 0;
  const before = crest();
  for (let pass = 0; pass < 12; pass++) {
    const gain = target / rms(buffer);
    for (let i = 0; i < buffer.length; i++) buffer[i] *= gain;
    if (peak(buffer) <= ceiling) break;
    if (looped) softClip(buffer, ceiling, ceiling * 0.6);
    else limit(buffer, c, ceiling);
  }
  return before - crest();
}

export function dcBlock(buffer, c, hz = 20) {
  const a = 1 - Math.exp((-2 * Math.PI * hz) / c.sr);
  let low = 0;
  for (let i = 0; i < buffer.length; i++) {
    low += a * (buffer[i] - low);
    buffer[i] -= low;
  }
  return buffer;
}

export function fade(buffer, c, inSeconds, outSeconds) {
  const head = Math.min(Math.round(inSeconds * c.sr), buffer.length >> 1);
  const tail = Math.min(Math.round(outSeconds * c.sr), buffer.length >> 1);
  for (let i = 0; i < head; i++) buffer[i] *= 0.5 - 0.5 * Math.cos((Math.PI * i) / head);
  for (let i = 0; i < tail; i++) {
    buffer[buffer.length - 1 - i] *= 0.5 - 0.5 * Math.cos((Math.PI * i) / tail);
  }
  return buffer;
}

/**
 * Cuts the silence at both ends (everything `floorDb` below the peak), keeps at most
 * `limit` seconds and fades both ends so the file starts and stops without a click.
 */
export function trim(buffer, c, { floorDb = -48, limit = Infinity, fadeIn = 0.0015 } = {}) {
  const floor = peak(buffer) * fromDb(floorDb);
  let first = 0;
  while (first < buffer.length - 1 && Math.abs(buffer[first]) < floor) first++;
  let last = buffer.length - 1;
  while (last > first && Math.abs(buffer[last]) < floor) last--;
  first = Math.max(0, first - Math.round(fadeIn * c.sr));
  last = Math.min(last, first + Math.round(limit * c.sr) - 1);
  const cut = buffer.slice(first, last + 1);
  const seconds = cut.length / c.sr;
  return fade(cut, c, fadeIn, Math.min(0.06, seconds * 0.25));
}
