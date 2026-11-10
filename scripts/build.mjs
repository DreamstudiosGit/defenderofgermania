// Release builds for Steam: node scripts/build.mjs [windows|linux|macos|all]
// Imports the project, exports the platform's preset (export_presets.cfg) into build/<platform>/,
// checks what went into the pack and writes version.txt. Exits 1 as soon as a step fails.
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pckFiles } from './pck_files.mjs';

const projectDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const fallback = join(homedir(), 'Tools', 'Godot', 'Godot_v4.7.2-stable_win64.exe');

const platforms = {
  windows: { preset: 'Windows', file: 'thronstreit.exe', pack: 'thronstreit.pck' },
  linux: { preset: 'Linux', file: 'thronstreit.x86_64', pack: 'thronstreit.pck' },
  // Godot writes a bare .app only on a Mac; everywhere else the bundle comes zipped, pack inside.
  macos: { preset: 'macOS', file: 'thronstreit.zip', pack: 'thronstreit.zip' },
};
// The editor loads the GUT plugin, whose update check fails without a network.
const editorNoise = /TLS handshake error|\[GUT\] Could not get version info/;
// What the presets' exclude filters keep out of a build.
const mustNotShip = /^(addons\/gut|scripts|docs|art-src|steam|\.github)\/|(^|\/)test_[^/]*\.gd|_preview\.(gd|tscn|scn)|^\.gutconfig\.json$/;

// The same lookup as run.mjs.
function findGodot() {
  if (process.env.GODOT) return process.env.GODOT;
  const lookup = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['godot'], { encoding: 'utf8' });
  if (lookup.status === 0) {
    const hits = lookup.stdout.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    // On Windows `where` also lists extensionless shims (for bash) that Node cannot start.
    const runnable = process.platform === 'win32' ? hits.filter((h) => /\.(exe|cmd|bat)$/i.test(h)) : hits;
    if (runnable.length > 0) return runnable[0];
  }
  if (existsSync(fallback)) return fallback;
  fail('Godot not found: set GODOT, put godot on PATH, or install it at ' + fallback);
}

function fail(message, log = '') {
  console.error(`FAILED: ${message}${log ? '\n' + log : ''}`);
  process.exit(1);
}

// Runs Godot in the project folder; returns its exit status, its output without colour codes
// and progress lines, and the errors among them.
function godot(args) {
  const options = { cwd: projectDir, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 };
  // A .cmd shim only starts through the shell, which takes one command line.
  const result = /\.(cmd|bat)$/i.test(godotPath)
    ? spawnSync(`"${godotPath}" ${args.join(' ')}`, { ...options, shell: true })
    : spawnSync(godotPath, args, options);
  if (result.error) fail(`cannot start ${godotPath}: ${result.error.message}`);
  const lines = `${result.stdout}\n${result.stderr}`
    .replace(/\x1b\[[0-9;]*m/g, '')
    .split(/\r?\n/)
    .filter((line) => line.trim() && !/^\[ *(\d+% |DONE )\]/.test(line));
  // Godot reports many failures only as an ERROR line and still exits 0.
  const errors = lines.filter((line) => /^(SCRIPT |USER )?ERROR:/.test(line) && !editorNoise.test(line));
  return { status: result.status, lines, errors };
}

// A value of the [application] section of project.godot.
function projectSetting(key) {
  const text = readFileSync(join(projectDir, 'project.godot'), 'utf8');
  const match = new RegExp(`^${key}="([^"]+)"`, 'm').exec(text);
  if (!match) fail(`project.godot has no ${key}`);
  return match[1];
}

// The game reads these as plain files (DataReader, LicenceTexts); only the presets' include
// filter puts them into the pack.
function plainFiles() {
  const names = (folder, pattern) =>
    readdirSync(join(projectDir, folder)).filter((name) => pattern.test(name)).map((name) => `${folder}/${name}`);
  return [...names('data', /\.json$/), ...names('assets/ui', /^font_.*_license\.txt$/)];
}

function checkPack(folder, pack) {
  const packed = pckFiles(join(projectDir, folder, pack));
  const wanted = plainFiles();
  const missing = wanted.filter((file) => !packed.includes(file));
  const unwanted = packed.filter((file) => mustNotShip.test(file));
  if (missing.length > 0) fail(`${folder}/${pack} lacks files the game reads`, missing.join('\n'));
  if (unwanted.length > 0) fail(`${folder}/${pack} holds files that must not ship`, unwanted.join('\n'));
  console.log(`ok: pack holds ${packed.length} files, all ${wanted.length} plain files, no tests or tools`);
}

function size(bytes) {
  const megabyte = 1024 * 1024;
  return bytes < megabyte ? `${Math.ceil(bytes / 1024)} KB` : `${(bytes / megabyte).toFixed(1)} MB`;
}

function build(name, version) {
  const { preset, file, pack } = platforms[name];
  const folder = `build/${name}`;
  rmSync(join(projectDir, folder), { recursive: true, force: true });
  mkdirSync(join(projectDir, folder), { recursive: true });
  const started = Date.now();
  const run = godot(['--headless', '--export-release', preset, `${folder}/${file}`]);
  const target = join(projectDir, folder, file);
  const built = existsSync(target) && statSync(target).size > 0;
  if (run.status !== 0 || run.errors.length > 0 || !built) {
    fail(`export ${preset} (exit code ${run.status}${built ? '' : `, no ${file}`})`, run.lines.join('\n'));
  }
  console.log(`ok: export ${preset} (${Math.round((Date.now() - started) / 1000)} s)`);
  for (const line of run.lines.filter((line) => line.startsWith('WARNING:'))) console.log(line);
  checkPack(folder, pack);
  writeFileSync(join(projectDir, folder, 'version.txt'), `${version}\n`);
  for (const entry of readdirSync(join(projectDir, folder)).sort()) {
    console.log(`${size(statSync(join(projectDir, folder, entry)).size).padStart(10)}  ${folder}/${entry}`);
  }
}

const wanted = process.argv[2] ?? 'all';
if (wanted !== 'all' && !Object.hasOwn(platforms, wanted)) {
  console.error('usage: node scripts/build.mjs [windows|linux|macos|all]');
  process.exit(1);
}
const godotPath = findGodot();
const version = projectSetting('config/version');
console.log(`${projectSetting('config/name')} ${version}: release build (${wanted})`);
const imported = godot(['--headless', '--import']);
if (imported.status !== 0) fail('import', imported.lines.join('\n'));
console.log('ok: import');
for (const name of wanted === 'all' ? Object.keys(platforms) : [wanted]) build(name, version);
