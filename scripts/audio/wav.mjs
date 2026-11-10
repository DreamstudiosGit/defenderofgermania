// 16-bit mono WAV files and the numbers the report of scripts/make_audio.mjs prints about them.

import { toDb } from './dsp.mjs';

const FULL = 32768;

export function quantise(buffer) {
  const out = new Int16Array(buffer.length);
  for (let i = 0; i < buffer.length; i++) {
    out[i] = Math.max(-32767, Math.min(32767, Math.round(buffer[i] * 32767)));
  }
  return out;
}

export function encode(pcm, sr) {
  const bytes = Buffer.alloc(44 + pcm.length * 2);
  bytes.write('RIFF', 0, 'ascii');
  bytes.writeUInt32LE(36 + pcm.length * 2, 4);
  bytes.write('WAVEfmt ', 8, 'ascii');
  bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20);
  bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(sr, 24);
  bytes.writeUInt32LE(sr * 2, 28);
  bytes.writeUInt16LE(2, 32);
  bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36, 'ascii');
  bytes.writeUInt32LE(pcm.length * 2, 40);
  for (let i = 0; i < pcm.length; i++) bytes.writeInt16LE(pcm[i], 44 + i * 2);
  return bytes;
}

/**
 * What the file holds, measured on the samples as written: length, peak and RMS (dBFS), DC
 * offset (share of full scale), the louder of the first and last sample (dBFS; a click when
 * it is not near silence) and the RMS frequency (Hz; how bright the sound is).
 */
export function measure(pcm, sr) {
  let top = 0;
  let sum = 0;
  let squares = 0;
  let steps = 0;
  for (let i = 0; i < pcm.length; i++) {
    const value = pcm[i] / FULL;
    top = Math.max(top, Math.abs(value));
    sum += value;
    squares += value * value;
    if (i > 0) steps += ((pcm[i] - pcm[i - 1]) / FULL) ** 2;
  }
  return {
    seconds: pcm.length / sr,
    peakDb: toDb(top),
    rmsDb: toDb(Math.sqrt(squares / pcm.length)),
    dc: sum / pcm.length,
    edgeDb: toDb(Math.max(Math.abs(pcm[0]), Math.abs(pcm[pcm.length - 1])) / FULL),
    brightHz: squares > 0 ? (sr / (2 * Math.PI)) * Math.sqrt(steps / squares) : 0,
  };
}

/**
 * How well the end of a loop runs into its start: the step and the bend (second difference)
 * across the seam, each divided by the RMS of that measure inside the file. Around 1 the
 * seam is an ordinary place in the music; far above, it clicks.
 */
export function seam(pcm) {
  const count = pcm.length;
  const at = (i) => pcm[((i % count) + count) % count];
  let steps = 0;
  let bends = 0;
  for (let i = 1; i < count - 1; i++) {
    steps += (pcm[i] - pcm[i - 1]) ** 2;
    bends += (pcm[i + 1] - 2 * pcm[i] + pcm[i - 1]) ** 2;
  }
  const typicalStep = Math.sqrt(steps / (count - 2)) + 1;
  const typicalBend = Math.sqrt(bends / (count - 2)) + 1;
  let bend = 0;
  for (const i of [-1, 0]) bend = Math.max(bend, Math.abs(at(i + 1) - 2 * at(i) + at(i - 1)));
  return { step: Math.abs(at(0) - at(-1)) / typicalStep, bend: bend / typicalBend };
}
