// The unpitched voices of scripts/make_audio.mjs: struck wood and metal, thuds, drums, air,
// creaks, rustles, debris and crowds. Every voice returns a new buffer with a peak near 1.

import {
  TAU, biquad, decay, harmonics, highpass1, hump, lowpass1, mix, modal, noise, peaked, rise,
  shape, silence, sine, stack, sweep,
} from './dsp.mjs';
import { loopThrough } from './master.mjs';

/** A few milliseconds of noise in a band, dying away: the attack of most struck things. */
export function snap(c, hz, tau = 0.003, q = 0.9) {
  return peaked(shape(biquad(noise(c, tau * 7), c, 'bandpass', hz, q), c, decay(tau)));
}

/** Struck wood: the modes of a small bar, quickly damped, under a short click. */
export function wood(c, { hz = 600, tau = 0.03, click = 0.5 } = {}) {
  const bar = modal(c, tau * 7 + 0.01, [
    [hz, 1, tau], [hz * 2.76, 0.5, tau * 0.55], [hz * 5.4, 0.22, tau * 0.3],
    [hz * 8.93, 0.1, tau * 0.2],
  ]);
  return peaked(stack(c, [[bar], [snap(c, Math.min(hz * 3.5, 7000), 0.002), 0, click]]));
}

const BAR = [1, 1.51, 2.09, 2.76, 3.42, 4.31, 5.4];

/** Struck metal: inharmonic modes that ring; higher modes die sooner. */
export function metal(c, { hz = 800, tau = 0.2, strike = 0.4, ratios = BAR } = {}) {
  const partials = ratios.map((ratio, k) => [
    hz * ratio * c.range(0.99, 1.01), 0.78 ** k * c.range(0.7, 1.2), tau / (1 + 0.45 * k),
  ]);
  const ring = shape(modal(c, tau * 6, partials), c, rise(0.0008));
  return peaked(stack(c, [[peaked(ring)], [snap(c, 5000, 0.002, 0.6), 0, strike]]));
}

/** A soft heavy impact: a sine that falls in pitch under a puff of dull noise. */
export function thud(c, { hz = 90, tau = 0.12, puff = 0.5, puffHz = 400, drop = 0.55 } = {}) {
  const seconds = tau * 6;
  const body = sine(c, seconds, (t) => hz * (drop + (1 - drop) * Math.exp(-t / (tau * 0.35))));
  shape(body, c, (t) => Math.exp(-t / tau) * Math.min(1, t / 0.002));
  const air = lowpass1(lowpass1(noise(c, seconds), c, puffHz), c, puffHz);
  shape(air, c, (t) => Math.exp(-t / (tau * 0.5)) * Math.min(1, t / 0.002));
  return peaked(stack(c, [[body], [peaked(air), 0, puff]]));
}

/**
 * A frame drum: 'D' war drum, 'd' low stroke, 't' rim stroke, 'k' finger tap, 'b' tabor
 * with its snare, 'c' the clop of a hoof for a walking pulse.
 */
export function drum(c, kind = 'd', velocity = 1) {
  const skin = (hz, tau, slap, wires) => {
    const head = modal(c, tau * 6, [
      [hz, 1, tau], [hz * 1.59, 0.45, tau * 0.6], [hz * 2.14, 0.3, tau * 0.45],
      [hz * 2.65, 0.18, tau * 0.35],
    ], (t) => 1 + 0.12 * Math.exp(-t / 0.03));
    const snare = peaked(shape(highpass1(noise(c, tau * 3), c, 1800), c, decay(tau * 0.5)));
    return peaked(stack(c, [
      [shape(head, c, rise(0.0015))], [snap(c, 1700, 0.008, 0.8), 0, slap], [snare, 0, wires],
    ]));
  };
  if (kind === 'D') return skin(62, 0.32, 0.35 * velocity, 0);
  if (kind === 'd') return skin(92, 0.2, 0.35 * velocity, 0);
  if (kind === 'b') return skin(150, 0.11, 0.4, 0.3 * velocity);
  if (kind === 'k') return skin(260, 0.03, 0.6 * velocity, 0);
  if (kind === 'c') return hoof(c, { hz: 130, hard: 0.5 + 0.4 * velocity });
  if (kind === 't') {
    const rim = wood(c, { hz: 430, tau: 0.035, click: 0.4 * velocity });
    return peaked(stack(c, [[rim, 0, 0.8], [skin(210, 0.05, 0.4, 0), 0, 0.5]]));
  }
  throw new Error(`unknown drum stroke ${kind}`);
}

/** A hoof on turf: a short thud with a hard knock on top. */
export function hoof(c, { hz = 105, hard = 0.5 } = {}) {
  return peaked(stack(c, [
    [thud(c, { hz: hz * c.range(0.9, 1.1), tau: 0.045, puff: 0.6, puffHz: 700 })],
    [wood(c, { hz: 820 * c.range(0.85, 1.15), tau: 0.01, click: 0.4 }), 0, hard * 0.5],
  ]));
}

/** Air: noise through a band that glides from `from` to `to` while it swells and fades. */
export function whoosh(c, { seconds = 0.3, from = 600, to = 2400, q = 2, peak = 0.5 } = {}) {
  const centre = (t) => from * (to / from) ** (t / seconds);
  const air = sweep(noise(c, seconds), c, 'band', centre, q);
  return peaked(shape(air, c, hump(seconds, peak)));
}

/** Wood or rope under strain: an uneven train of small slips through wooden resonances. */
export function creak(c, { seconds = 0.5, from = 35, to = 80, tones = [420, 1050, 2300] } = {}) {
  const slips = silence(c, seconds);
  let t = 0;
  while (t < seconds) {
    slips[Math.min(slips.length - 1, Math.round(t * c.sr))] = c.range(0.5, 1);
    t += c.range(0.75, 1.3) / (from + ((to - from) * t) / seconds);
  }
  const parts = tones.map((hz, k) => [
    biquad(Float64Array.from(slips), c, 'bandpass', hz * c.range(0.95, 1.05), 9), 0, 0.8 ** k,
  ]);
  const out = lowpass1(stack(c, parts), c, 3800);
  return peaked(shape(out, c, hump(seconds, 0.45)));
}

/** Parchment or cloth: grains of hiss between `low` and `high`, `grains` per second. */
export function rustle(c, { seconds = 0.25, low = 2500, high = 8000, grains = 70, peak = 0.4 } = {}) {
  const hiss = biquad(biquad(noise(c, seconds), c, 'highpass', low, 0.7), c, 'lowpass', high, 0.7);
  const texture = silence(c, seconds);
  for (let i = 0; i < grains * seconds; i++) {
    const length = c.range(0.004, 0.018);
    const grain = shape(silence(c, length).fill(c.range(0.3, 1) ** 2), c, hump(length));
    mix(texture, grain, Math.round(c.range(0, seconds - length) * c.sr));
  }
  for (let i = 0; i < hiss.length; i++) hiss[i] *= 0.12 + texture[i];
  return peaked(shape(hiss, c, hump(seconds, peak)));
}

/** Things landing one after another between `from` and `to` seconds, fewer and fainter later. */
export function scatter(c, { count, from = 0, to = 0.5, make, fall = 1.5 }) {
  const parts = [];
  for (let i = 0; i < count; i++) {
    const share = c.rand() ** fall;
    parts.push([make(), from + (to - from) * share, 1 - 0.7 * share]);
  }
  return stack(c, parts);
}

export function coin(c) {
  const hz = c.range(3400, 5200);
  return metal(c, { hz, tau: c.range(0.04, 0.09), strike: 0.25, ratios: [1, 1.34, 2.41, 3.1] });
}

/** A crumb of rubble: a few milliseconds of noise in a band. */
export const crumb = (c, low = 900, high = 4000) =>
  snap(c, c.range(low, high), c.range(0.004, 0.012), 1.2);

/** The comic helmet "klong": a hollow pot of metal whose pitch sags, over a dull bump. */
export function klong(c, { hz = 430, tau = 0.3 } = {}) {
  const pot = modal(c, tau * 5, [
    [hz, 1, tau], [hz * 2.0, 0.55, tau * 0.7], [hz * 2.76, 0.4, tau * 0.5],
    [hz * 4.1, 0.2, tau * 0.3], [hz * 5.4, 0.12, tau * 0.2],
  ], (t) => 0.955 + 0.045 * Math.exp(-t / 0.09));
  const bump = thud(c, { hz: 120, tau: 0.04, puff: 0.3 });
  return peaked(stack(c, [
    [peaked(shape(pot, c, rise(0.001)))], [snap(c, 2200, 0.004, 0.8), 0, 0.4], [bump, 0, 0.5],
  ]));
}

/** One voice of a crowd calling out: a rising, falling vowel. */
export function whoop(c, seconds) {
  const base = c.range(170, 380);
  const lift = c.range(0.15, 0.5);
  const arc = hump(seconds, 0.4);
  const amps = [];
  for (let k = 1; k <= 20; k++) amps.push(1 / k);
  const voice = harmonics(c, seconds, (t) => base * (1 + lift * arc(t)), amps);
  const vowel = stack(c, [
    [biquad(Float64Array.from(voice), c, 'bandpass', c.range(650, 900), 5)],
    [biquad(Float64Array.from(voice), c, 'bandpass', c.range(1100, 1500), 6), 0, 0.7],
    [biquad(voice, c, 'bandpass', c.range(2400, 2900), 7), 0, 0.3],
  ]);
  return peaked(shape(vowel, c, hump(seconds, 0.35)));
}

/**
 * Many people at once: bands of noise in the range of voices, each waxing and waning at the
 * pace of syllables. With `loop` the result repeats without a seam.
 */
export function crowd(c, seconds, { voices = 8, loop = false } = {}) {
  const out = silence(c, seconds);
  const length = out.length / c.sr;
  for (let v = 0; v < voices; v++) {
    const centre = c.range(450, 2400);
    const width = c.range(1.2, 2.6);
    const band = (buffer) =>
      biquad(biquad(buffer, c, 'bandpass', centre, width), c, 'lowpass', 3600, 0.7);
    const source = noise(c, seconds);
    const voiced = loop ? loopThrough(source, band) : band(source);
    const syllables = Math.round(c.range(2.5, 7) * length) / length;
    const breaths = Math.max(1, Math.round(c.range(0.15, 0.5) * length)) / length;
    const [first, second] = [c.range(0, TAU), c.range(0, TAU)];
    for (let i = 0; i < out.length; i++) {
      const t = i / c.sr;
      const calling = 0.55 + 0.45 * Math.sin(TAU * syllables * t + first);
      out[i] += voiced[i] * calling * (0.7 + 0.3 * Math.sin(TAU * breaths * t + second));
    }
  }
  return peaked(out);
}
