// Deterministic DSP building blocks of scripts/make_audio.mjs. Buffers are Float64Array in
// -1..1, times are seconds, frequencies are Hz. `c` is the context of the file being made:
// its sample rate and a PRNG seeded by the file's name, so a file never depends on the others.

export const TAU = 2 * Math.PI;

export function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hashSeed(text) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

export function context(sr, name) {
  const rand = mulberry32(hashSeed(name));
  return {
    sr,
    rand,
    range: (low, high) => low + (high - low) * rand(),
    pick: (list) => list[Math.floor(rand() * list.length)],
  };
}

export const fromDb = (value) => 10 ** (value / 20);
export const toDb = (value) => 20 * Math.log10(Math.max(value, 1e-9));
export const silence = (c, seconds) => new Float64Array(Math.max(1, Math.round(seconds * c.sr)));
const asFunction = (value) => (typeof value === 'function' ? value : () => value);

// ---- Mixing

/** Adds `source` into `target` from sample `at`; what does not fit is dropped. */
export function mix(target, source, at = 0, gain = 1) {
  const count = Math.min(source.length, target.length - at);
  for (let i = Math.max(0, -at); i < count; i++) target[at + i] += source[i] * gain;
  return target;
}

/** Like mix(), but what runs past the end of `target` comes back in at its start. */
export function mixLooped(target, source, at = 0, gain = 1) {
  const count = target.length;
  for (let i = 0; i < source.length; i++) {
    target[(((at + i) % count) + count) % count] += source[i] * gain;
  }
  return target;
}

/** A new buffer holding every part: [buffer, start in seconds = 0, gain = 1]. */
export function stack(c, parts) {
  let length = 1;
  for (const [source, at = 0] of parts) {
    length = Math.max(length, Math.round(at * c.sr) + source.length);
  }
  const out = new Float64Array(length);
  for (const [source, at = 0, gain = 1] of parts) mix(out, source, Math.round(at * c.sr), gain);
  return out;
}

export function scale(buffer, gain) {
  for (let i = 0; i < buffer.length; i++) buffer[i] *= gain;
  return buffer;
}

/** Scales the buffer so its largest sample is `top`: filtered noise has no level of its own. */
export function peaked(buffer, top = 1) {
  let now = 0;
  for (let i = 0; i < buffer.length; i++) now = Math.max(now, Math.abs(buffer[i]));
  return now > 0 ? scale(buffer, top / now) : buffer;
}

// ---- Sources. `hz` is a number or a function of the time.

export function sine(c, seconds, hz) {
  const out = silence(c, seconds);
  const pitch = asFunction(hz);
  let phase = 0;
  for (let i = 0; i < out.length; i++) {
    out[i] = Math.sin(phase);
    phase += (TAU * pitch(i / c.sr)) / c.sr;
  }
  return out;
}

/** Additive tone: amps[k] is the level of harmonic k + 1; harmonics near Nyquist are left out. */
export function harmonics(c, seconds, hz, amps) {
  const out = silence(c, seconds);
  const pitch = asFunction(hz);
  let phase = 0;
  for (let i = 0; i < out.length; i++) {
    const now = pitch(i / c.sr);
    let value = 0;
    for (let k = 0; k < amps.length && (k + 1) * now < 0.45 * c.sr; k++) {
      value += amps[k] * Math.sin((k + 1) * phase);
    }
    out[i] = value;
    phase += (TAU * now) / c.sr;
  }
  return out;
}

/** Two-operator FM: a carrier at `hz`, a modulator at `hz * ratio`, depth `index` (may vary). */
export function fm(c, seconds, hz, ratio, index) {
  const out = silence(c, seconds);
  const pitch = asFunction(hz);
  const depth = asFunction(index);
  let carrier = 0;
  let modulator = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / c.sr;
    out[i] = Math.sin(carrier + depth(t) * Math.sin(modulator));
    const step = (TAU * pitch(t)) / c.sr;
    carrier += step;
    modulator += step * ratio;
  }
  return out;
}

export function noise(c, seconds) {
  const out = silence(c, seconds);
  for (let i = 0; i < out.length; i++) out[i] = c.rand() * 2 - 1;
  return out;
}

/** Struck-object modes: [hz, level, decay time constant]; `glide(t)` bends all of them. */
export function modal(c, seconds, partials, glide = null) {
  const out = silence(c, seconds);
  for (const [hz, level, tau] of partials) {
    if (hz >= 0.45 * c.sr) continue;
    let phase = 0;
    for (let i = 0; i < out.length; i++) {
      const t = i / c.sr;
      out[i] += level * Math.exp(-t / tau) * Math.sin(phase);
      phase += (TAU * hz * (glide ? glide(t) : 1)) / c.sr;
    }
  }
  return out;
}

// ---- Envelopes: functions of the time, applied with shape().

export function shape(buffer, c, envelope) {
  for (let i = 0; i < buffer.length; i++) buffer[i] *= envelope(i / c.sr);
  return buffer;
}

export const decay = (tau) => (t) => Math.exp(-t / tau);
export const rise = (seconds) => (t) =>
  t >= seconds ? 1 : 0.5 - 0.5 * Math.cos((Math.PI * t) / seconds);

/** Attack, decay to `sustain`, release over the last `release` seconds of `length`. */
export function adsr(attack, decaySeconds, sustain, release, length) {
  return (t) => {
    let value = sustain;
    if (t < attack) value = 0.5 - 0.5 * Math.cos((Math.PI * t) / attack);
    else if (t < attack + decaySeconds) value = 1 - ((1 - sustain) * (t - attack)) / decaySeconds;
    const left = length - t;
    if (left < release) value *= left <= 0 ? 0 : 0.5 - 0.5 * Math.cos((Math.PI * left) / release);
    return value;
  };
}

/** Swells to 1 at `peak` (a share of `length`) and falls back to 0, both as raised cosines. */
export function hump(length, peak = 0.5) {
  const top = length * peak;
  return (t) => {
    if (t <= 0 || t >= length) return 0;
    if (t < top) return 0.5 - 0.5 * Math.cos((Math.PI * t) / top);
    return 0.5 + 0.5 * Math.cos((Math.PI * (t - top)) / (length - top));
  };
}

/** Straight lines through [time, value] points. */
export function line(points) {
  return (t) => {
    if (t <= points[0][0]) return points[0][1];
    for (let i = 1; i < points.length; i++) {
      const [t1, v1] = points[i];
      if (t <= t1) {
        const [t0, v0] = points[i - 1];
        return v0 + ((v1 - v0) * (t - t0)) / (t1 - t0);
      }
    }
    return points[points.length - 1][1];
  };
}

// ---- Filters, all in place.

export function lowpass1(buffer, c, hz) {
  const a = 1 - Math.exp((-TAU * hz) / c.sr);
  let y = 0;
  for (let i = 0; i < buffer.length; i++) {
    y += a * (buffer[i] - y);
    buffer[i] = y;
  }
  return buffer;
}

export function highpass1(buffer, c, hz) {
  const a = 1 - Math.exp((-TAU * hz) / c.sr);
  let y = 0;
  for (let i = 0; i < buffer.length; i++) {
    y += a * (buffer[i] - y);
    buffer[i] -= y;
  }
  return buffer;
}

/** RBJ biquad; kind is 'lowpass', 'highpass', 'bandpass' (peak gain 1) or 'peak' (gainDb). */
export function biquad(buffer, c, kind, hz, q = 0.707, gainDb = 0) {
  const w = (TAU * Math.min(hz, 0.45 * c.sr)) / c.sr;
  const cos = Math.cos(w);
  const alpha = Math.sin(w) / (2 * q);
  let b0;
  let b1;
  let b2;
  let a0 = 1 + alpha;
  let a2 = 1 - alpha;
  if (kind === 'lowpass') [b0, b1, b2] = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2];
  else if (kind === 'highpass') [b0, b1, b2] = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2];
  else if (kind === 'bandpass') [b0, b1, b2] = [alpha, 0, -alpha];
  else if (kind === 'peak') {
    const amp = 10 ** (gainDb / 40);
    [b0, b1, b2] = [1 + alpha * amp, -2 * cos, 1 - alpha * amp];
    [a0, a2] = [1 + alpha / amp, 1 - alpha / amp];
  } else throw new Error(`unknown biquad kind ${kind}`);
  const a1 = -2 * cos;
  let x1 = 0;
  let x2 = 0;
  let y1 = 0;
  let y2 = 0;
  for (let i = 0; i < buffer.length; i++) {
    const x = buffer[i];
    const y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    buffer[i] = y;
  }
  return buffer;
}

/** State-variable filter whose cutoff may move (stable while it does): 'low', 'band', 'high'. */
export function sweep(buffer, c, kind, hz, q = 0.707) {
  const cutoff = asFunction(hz);
  const k = 1 / q;
  let s1 = 0;
  let s2 = 0;
  let g = 0;
  for (let i = 0; i < buffer.length; i++) {
    if (i % 16 === 0) g = Math.tan((Math.PI * Math.min(cutoff(i / c.sr), 0.45 * c.sr)) / c.sr);
    const a1 = 1 / (1 + g * (g + k));
    const v3 = buffer[i] - s2;
    const v1 = a1 * s1 + g * a1 * v3;
    const v2 = s2 + g * v1;
    s1 = 2 * v1 - s1;
    s2 = 2 * v2 - s2;
    if (kind === 'low') buffer[i] = v2;
    else if (kind === 'band') buffer[i] = v1 * k;
    else buffer[i] = buffer[i] - k * v1 - v2;
  }
  return buffer;
}
