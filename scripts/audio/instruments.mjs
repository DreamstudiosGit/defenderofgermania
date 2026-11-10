// The pitched voices of scripts/make_audio.mjs: plucked string, pipe, shawm, bowed string,
// horn, bells and the drone. Every voice returns a new buffer that starts and ends silent.

import {
  TAU, adsr, biquad, decay, fm, harmonics, lowpass1, modal, noise, peaked, shape, silence,
  stack,
} from './dsp.mjs';

const NOTES = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };

/** "D4", "F#3", "Bb2" -> Hz in equal temperament, A4 = 440. */
export function pitch(name) {
  const match = /^([A-G])([#b]?)(-?\d)$/.exec(name);
  if (!match) throw new Error(`not a note: ${name}`);
  const shift = match[2] === '#' ? 1 : match[2] === 'b' ? -1 : 0;
  return 440 * 2 ** ((NOTES[match[1]] + shift) / 12 + (Number(match[3]) - 4));
}

/**
 * Karplus-Strong string: a burst of noise goes round a delay line of one period; a one-zero
 * low-pass in the loop wears the highs away, an allpass tunes the fraction of a sample.
 * `bright` 0..1 keeps the highs longer, `sustain` is the time to -60 dB, `pick` the plucking
 * point as a share of the string, `hard` 0..1 how sharp the pluck is.
 */
export function pluck(c, seconds, hz, options = {}) {
  const { bright = 0.5, sustain = 2, pick = 0.18, hard = 0.6 } = options;
  const out = silence(c, seconds);
  const period = c.sr / hz;
  const blend = 0.5 - 0.4 * bright;
  let whole = Math.floor(period - blend);
  let fraction = period - blend - whole;
  if (fraction < 0.15) {
    whole -= 1;
    fraction += 1;
  }
  const tuning = (1 - fraction) / (1 + fraction);
  const loss = 0.001 ** (1 / (sustain * hz));
  const burst = new Float64Array(whole);
  const smoothing = 0.2 + 0.75 * hard;
  let low = 0;
  for (let i = 0; i < whole; i++) {
    low += smoothing * (c.rand() * 2 - 1 - low);
    burst[i] = low;
  }
  const gap = Math.max(1, Math.round(pick * whole));
  for (let i = whole - 1; i >= gap; i--) burst[i] -= burst[i - gap];
  let mean = 0;
  for (let i = 0; i < whole; i++) mean += burst[i] / whole;
  let top = 1e-9;
  for (let i = 0; i < whole; i++) top = Math.max(top, Math.abs(burst[i] - mean));
  const string = new Float64Array(whole);
  let at = 0;
  let before = 0;
  let passIn = 0;
  let passOut = 0;
  for (let i = 0; i < out.length; i++) {
    const delayed = string[at];
    const damped = (1 - blend) * delayed + blend * before;
    before = delayed;
    const tuned = tuning * damped + passIn - tuning * passOut;
    passIn = damped;
    passOut = tuned;
    const value = (i < whole ? (burst[i] - mean) / top : 0) + loss * tuned;
    string[at] = value;
    at = (at + 1) % whole;
    out[i] = value;
  }
  return out;
}

/** A lute course: two strings a hair apart through a small wooden body. */
export function lute(c, hz, seconds, velocity = 1) {
  const ring = Math.min(Math.max(seconds * 1.6, 0.9), 2.6);
  const options = {
    bright: 0.35 + 0.25 * velocity,
    sustain: 2.4 * (196 / hz) ** 0.35,
    hard: 0.35 + 0.4 * velocity,
  };
  const out = stack(c, [
    [pluck(c, ring, hz, options)],
    [pluck(c, ring, hz * 1.0028, { ...options, pick: 0.23 }), 0.004, 0.6],
  ]);
  biquad(out, c, 'peak', 190, 2.5, 5);
  biquad(out, c, 'peak', 410, 3, 3);
  biquad(out, c, 'lowpass', 4200, 0.7);
  return peaked(shape(out, c, adsr(0.0008, 0.01, 1, Math.min(0.25, ring * 0.3), ring)));
}

/** A muted, short string for quiet pulses. */
export function mutedLute(c, hz, seconds, velocity = 1) {
  const out = pluck(c, 0.32, hz, { bright: 0.15, sustain: 0.35, hard: 0.2 + 0.3 * velocity });
  biquad(out, c, 'lowpass', 1600, 0.7);
  return peaked(shape(out, c, adsr(0.001, 0.01, 1, 0.12, out.length / c.sr)));
}

const vibrato = (hz, rate, depth, after) => (t) =>
  hz * (1 + depth * Math.min(1, t / after) * Math.sin(TAU * rate * t));

/** A recorder-like pipe: nearly a sine, with breath and a soft chiff at the start. */
export function pipe(c, hz, seconds, velocity = 1) {
  const length = seconds + 0.06;
  const tone = harmonics(c, length, vibrato(hz, 5, 0.004, 0.35), [1, 0.22, 0.1, 0.035, 0.015]);
  const breath = peaked(biquad(noise(c, length), c, 'bandpass', hz * 2, 1.5));
  const chiff = shape(biquad(noise(c, 0.04), c, 'bandpass', hz * 3, 2), c, decay(0.012));
  const out = stack(c, [[tone], [breath, 0, 0.05], [peaked(chiff), 0, 0.12 * velocity]]);
  return peaked(shape(out, c, adsr(0.045, 0.08, 0.85, 0.09, length)));
}

/** A shawm: a reedy, nasal double reed (saw harmonics under two formants). */
export function shawm(c, hz, seconds, velocity = 1) {
  const length = seconds + 0.04;
  const amps = [];
  const formant = (f, centre, width) => Math.exp(-(((f - centre) / width) ** 2));
  for (let k = 1; k <= 24; k++) {
    const f = k * hz;
    amps.push((0.2 + formant(f, 1150, 520) + 0.6 * formant(f, 2700, 750)) / k ** 0.8);
  }
  const out = harmonics(c, length, vibrato(hz, 5.5, 0.003, 0.25), amps);
  biquad(out, c, 'lowpass', 5200 + 1200 * velocity, 0.7);
  return peaked(shape(out, c, adsr(0.022, 0.05, 0.82, 0.05, length)));
}

/** A bowed string: slow to speak, with a slight tremble. */
export function vielle(c, hz, seconds, velocity = 1) {
  const amps = [];
  for (let k = 1; k <= 16; k++) amps.push(1 / (k * (1 + ((k * hz) / 1800) ** 2)));
  const out = stack(c, [
    [harmonics(c, seconds, vibrato(hz, 4.6, 0.003, 0.6), amps)],
    [harmonics(c, seconds, hz * 1.004, amps), 0, 0.6],
  ]);
  const attack = Math.min(0.5, seconds * 0.35);
  shape(out, c, (t) => 1 - 0.12 * velocity * (0.5 + 0.5 * Math.sin(TAU * 5.3 * t)));
  return peaked(shape(out, c, adsr(attack, 0.1, 0.9, Math.min(0.6, seconds * 0.35), seconds)));
}

/**
 * Brass by FM (Chowning): the brightness follows the loudness. `hz` may glide; `bright` is
 * the peak modulation index (2 = mellow horn, 5 = trumpet).
 */
export function horn(c, hz, seconds, options = {}) {
  const { bright = 3, attack = 0.07, release = 0.12, breath = 0.03 } = options;
  const envelope = adsr(attack, 0.12, 0.8, release, seconds);
  const index = (t) => bright * envelope(t);
  const bend = typeof hz === 'function' ? hz : () => hz;
  const air = peaked(biquad(noise(c, seconds), c, 'bandpass', bend(seconds / 2) * 3, 1));
  const out = stack(c, [
    [fm(c, seconds, bend, 1, index)],
    [fm(c, seconds, (t) => bend(t) * 1.004, 1, index), 0, 0.5],
    [air, 0, breath],
  ]);
  biquad(out, c, 'lowpass', 2600 + 500 * bright, 0.7);
  return peaked(shape(out, c, envelope));
}

/** A cast bell: hum, prime, tierce, quint, nominal and upper partials; `tau` is the hum's. */
export function bell(c, hz, tau, seconds = tau * 4) {
  const partials = [
    [0.5, 0.45, 1], [1, 1, 0.8], [1.19, 0.55, 0.65], [1.5, 0.3, 0.5], [2, 0.75, 0.45],
    [2.51, 0.3, 0.3], [2.66, 0.22, 0.26], [3.01, 0.26, 0.2], [4.17, 0.16, 0.14], [5.43, 0.1, 0.1],
  ].map(([ratio, amp, life]) => [hz * ratio, amp, tau * life]);
  const strike = shape(biquad(noise(c, 0.02), c, 'highpass', 1500), c, decay(0.004));
  const out = stack(c, [[modal(c, seconds, partials)], [peaked(strike), 0, 0.3]]);
  return peaked(shape(out, c, adsr(0.0006, 0.01, 1, seconds * 0.3, seconds)));
}

/** A small hand bell or chime by FM (carrier : modulator = 1 : 1.4, the index dies away). */
export function chime(c, hz, tau, seconds = tau * 5) {
  const out = stack(c, [
    [fm(c, seconds, hz, 1.4, (t) => 3.2 * Math.exp(-t / (tau * 0.45)))],
    [fm(c, seconds, hz * 2.003, 1.4, (t) => 1.5 * Math.exp(-t / (tau * 0.3))), 0, 0.3],
  ]);
  shape(out, c, decay(tau));
  lowpass1(out, c, 9000);
  return peaked(shape(out, c, adsr(0.0008, 0.01, 1, seconds * 0.3, seconds)));
}

/**
 * A drone that loops: every partial and every slow swell makes a whole number of rounds in
 * `count` samples. `voices` are [hz, level]; each is two reedy oscillators that beat slowly.
 */
export function drone(c, count, voices, { dark = 900, swell = 0.18 } = {}) {
  const out = new Float64Array(count);
  const seconds = count / c.sr;
  const whole = (hz) => Math.round(hz * seconds) / seconds;
  for (const [hz, gain] of voices) {
    for (const detune of [-1, 1]) {
      const exact = whole(hz) + (detune * Math.round(c.range(7, 13))) / seconds / 2;
      const steady = Math.round(exact * seconds) / seconds;
      const amps = [];
      for (let k = 1; k <= 14; k++) amps.push(1 / (k ** 1.3 * (1 + ((k * steady) / dark) ** 2)));
      const slow = Math.round(c.range(2, 5)) / seconds;
      const offset = c.range(0, TAU);
      const voice = harmonics(c, seconds, steady, amps);
      for (let i = 0; i < count; i++) {
        const breathing = 1 - swell * (0.5 + 0.5 * Math.sin(TAU * slow * (i / c.sr) + offset));
        out[i] += voice[i] * gain * breathing;
      }
    }
  }
  return peaked(out);
}
