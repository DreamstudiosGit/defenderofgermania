// Synthesises every sound effect and music loop of the game as 16-bit mono WAV files below
// assets/ (placeholders until recordings exist; data/audio.json says which id plays which
// file). Deterministic: every file is made from a PRNG seeded by its own name, so a second
// run changes nothing. Prints one line of measurements per file and exits 1 when a file
// misses its targets (peak, loudness, DC offset, clean edges, loop seam).
//
// Usage: node scripts/make_audio.mjs [--only=<part of a file name>] [--check]
//   --check  renders and measures but writes nothing; reports files that would change.
// Afterwards: godot --headless --import (twice when an .import file was changed here).

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { context } from './audio/dsp.mjs';
import { dcBlock, level, loopThrough, trim } from './audio/master.mjs';
import { encode, measure, quantise, seam } from './audio/wav.mjs';
import ui from './audio/sfx_ui.mjs';
import map from './audio/sfx_map.mjs';
import battle from './audio/sfx_battle.mjs';
import joust from './audio/sfx_joust.mjs';
import siege from './audio/sfx_siege.mjs';
import raid from './audio/sfx_raid.mjs';
import stings from './audio/stings.mjs';
import calm from './audio/music_calm.mjs';
import fight from './audio/music_battle.mjs';
import ventures from './audio/music_ventures.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SFX_RATE = 44100;
const MUSIC_RATE = 24000;
const PEAK_DB = -1;
/** Share of full scale. A short low thud never averages to exactly zero. */
const DC_LIMIT = 0.002;
/** RMS targets in dBFS, before the volume_db of data/audio.json. */
const LOUDNESS = { tick: -30, ui: -26, sfx: -18, hit: -14, sting: -16 };
const RMS_TOLERANCE_DB = 1;
/** The first and the last sample of an effect, in dBFS: louder would click. */
const EDGE_DB = -60;
/** How far the seam of a loop may stand out from the rest of it (see seam() in wav.mjs). */
const SEAM_STEP = 4;
const SEAM_BEND = 6;
const UI_SECONDS = 0.245;
const HEAD_SECONDS = 0.003;
const COMPRESS = { music: 2, sfx: 0 };

const only = (process.argv.find((arg) => arg.startsWith('--only=')) ?? '').slice(7);
const checkOnly = process.argv.includes('--check');

function renderEffect(entry, n) {
  const many = (entry.variants ?? 1) > 1;
  const name = `sfx_${entry.id}${many ? `_${n + 1}` : ''}`;
  const c = context(SFX_RATE, name);
  const raw = entry.make(c, n);
  const padded = new Float64Array(raw.length + Math.round(HEAD_SECONDS * c.sr));
  padded.set(raw, padded.length - raw.length);
  const short = entry.kind === 'tick' || entry.kind === 'ui';
  const limit = entry.limit ?? (short ? UI_SECONDS : Infinity);
  const cut = trim(dcBlock(padded, c), c, { limit });
  const target = entry.rms ?? LOUDNESS[entry.kind];
  const limited = level(cut, c, target, { peakDb: PEAK_DB });
  const pcm = quantise(cut);
  const stats = measure(pcm, c.sr);
  const problems = problemsOf(stats, target);
  if (stats.edgeDb > EDGE_DB) problems.push('edge');
  if (stats.seconds > limit + 0.001) problems.push('long');
  const path = `assets/${entry.folder}/${name}.wav`;
  return { path, pcm, sr: c.sr, stats, target, limited, problems };
}

function renderLayer(entry) {
  const name = `music_${entry.track}_${entry.layer}`;
  const c = context(MUSIC_RATE, name);
  const steady = loopThrough(entry.make(c), (twice) => dcBlock(twice, c, 25));
  const limited = level(steady, c, entry.rms, { peakDb: PEAK_DB, looped: true });
  const pcm = quantise(steady);
  const stats = measure(pcm, c.sr);
  const closing = seam(pcm);
  const problems = problemsOf(stats, entry.rms);
  if (closing.step > SEAM_STEP || closing.bend > SEAM_BEND) problems.push('seam');
  const path = `assets/${entry.folder}/${name}.wav`;
  return { path, pcm, sr: c.sr, stats, target: entry.rms, limited, problems, closing, track: entry.track };
}

function problemsOf(stats, target) {
  const problems = [];
  if (stats.peakDb > PEAK_DB) problems.push('peak');
  if (Math.abs(stats.rmsDb - target) > RMS_TOLERANCE_DB) problems.push('rms');
  if (Math.abs(stats.dc) > DC_LIMIT) problems.push('dc');
  return problems;
}

/** Writes the file when its bytes differ; returns 'new', 'changed' or 'same'. */
function store(file) {
  const target = join(ROOT, file.path);
  const bytes = encode(file.pcm, file.sr);
  const state = !existsSync(target) ? 'new' : readFileSync(target).equals(bytes) ? 'same' : 'changed';
  if (state !== 'same' && !checkOnly) {
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, bytes);
  }
  return state;
}

/** Music is imported QOA-compressed, effects as plain PCM; true when the .import changed. */
function setCompression(file, mode) {
  const target = `${join(ROOT, file.path)}.import`;
  if (!existsSync(target)) return false;
  const text = readFileSync(target, 'utf8');
  const wanted = text.replace(/^compress\/mode=\d+$/m, `compress/mode=${mode}`);
  if (wanted === text) return false;
  if (!checkOnly) writeFileSync(target, wanted);
  return true;
}

const fixed = (value, digits = 1) => value.toFixed(digits).padStart(6);

function report(file, state) {
  const { stats } = file;
  const { closing } = file;
  const loop = closing ? `seam ${closing.step.toFixed(2)}/${closing.bend.toFixed(2)}` : '';
  console.log([
    file.path.padEnd(46), `${fixed(stats.seconds, 2)} s`, `peak ${fixed(stats.peakDb)}`,
    `rms ${fixed(stats.rmsDb)} (${file.target})`, `dc ${stats.dc.toFixed(5).padStart(8)}`,
    `edge ${fixed(stats.edgeDb, 0)}`, `${fixed(stats.brightHz, 0)} Hz`,
    `limit ${fixed(Math.max(0, file.limited))}`, loop, state === 'same' ? '' : state,
    file.problems.length ? `<-- ${file.problems.join(', ')}` : '',
  ].join('  ').trimEnd());
}

console.log('file, length, peak dBFS, RMS dBFS (target), DC offset, first/last sample dBFS, RMS'
  + ' frequency, dB taken off the peaks, loop seam (step/bend against the rest of the loop)');
const files = [];
for (const entry of [...ui, ...map, ...battle, ...joust, ...siege, ...raid, ...stings]) {
  for (let n = 0; n < (entry.variants ?? 1); n++) {
    if (`sfx_${entry.id}`.includes(only)) files.push(renderEffect(entry, n));
  }
}
for (const entry of [...calm, ...fight, ...ventures]) {
  if (`music_${entry.track}_${entry.layer}`.includes(only)) files.push(renderLayer(entry));
}

let bytes = 0;
let failed = 0;
let stale = 0;
let reimport = false;
const lengths = new Map();
for (const file of files) {
  const state = store(file);
  if (file.track) {
    const length = lengths.get(file.track) ?? file.pcm.length;
    lengths.set(file.track, length);
    if (length !== file.pcm.length) file.problems.push('length');
  }
  report(file, state);
  bytes += 44 + file.pcm.length * 2;
  failed += file.problems.length ? 1 : 0;
  stale += state === 'same' ? 0 : 1;
  reimport = setCompression(file, file.track ? COMPRESS.music : COMPRESS.sfx) || reimport;
}
const megabytes = (bytes / 1048576).toFixed(1);
const verb = checkOnly ? 'would change' : 'written';
console.log(`${files.length} files, ${megabytes} MB of WAV, ${stale} ${verb}, ${failed} with problems`);
if (reimport) console.log('import settings changed: run "godot --headless --import" again');
process.exit(failed ? 1 : 0);
