// Balance run (M7): plays games between four computer houses in parallel Godot processes
// (scripts/balance_run.gd) and sums up win shares per house, endings, the coronation round and
// bankruptcies against the GDD targets: each house 20–30 %, coronation in rounds 25–35 on
// average, bankruptcy in under 5 %.
// node scripts/balance.mjs [--games=1000] [--jobs=8] [--seed=1] [--difficulty=1]
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const fallback = join(homedir(), 'Tools', 'Godot', 'Godot_v4.7.2-stable_win64.exe');

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
  console.error('Godot not found: set GODOT, put godot on PATH, or install it at ' + fallback);
  process.exit(1);
}

function option(name, fallbackValue) {
  const arg = process.argv.find((a) => a.startsWith(`--${name}=`));
  return arg ? Number(arg.split('=')[1]) : fallbackValue;
}

const games = option('games', 1000);
const jobs = Math.max(1, Math.min(option('jobs', 8), games));
const firstSeed = option('seed', 1);
const difficulty = option('difficulty', 1);
const godot = findGodot();
const work = mkdtempSync(join(tmpdir(), 'thronstreit-balance-'));

function runJob(index, count, seed) {
  const out = join(work, `games_${index}.jsonl`);
  const args = ['--headless', '--path', projectDir, '--script', 'res://scripts/balance_run.gd', '--',
    `--games=${count}`, `--seed=${seed}`, `--difficulty=${difficulty}`, `--out=${out}`];
  return new Promise((resolve) => {
    const child = spawn(godot, args, { stdio: 'ignore', shell: /\.(cmd|bat)$/i.test(godot) });
    child.on('close', () => resolve(existsSync(out) ? readFileSync(out, 'utf8') : ''));
  });
}

const started = Date.now();
const per = Math.ceil(games / jobs);
const runs = [];
for (let i = 0; i < jobs; i++) {
  const count = Math.min(per, games - i * per);
  if (count > 0) runs.push(runJob(i, count, firstSeed + i * per));
}
const results = (await Promise.all(runs)).join('\n').split('\n').filter((l) => l.trim()).map((l) => JSON.parse(l));

const wins = {};
const endings = {};
const crowned = [];
let bankruptHouses = 0;
for (const game of results) {
  wins[game.winner || '(none)'] = (wins[game.winner || '(none)'] || 0) + 1;
  endings[game.ending] = (endings[game.ending] || 0) + 1;
  if (game.ending === 'coronation') crowned.push(game.round);
  bankruptHouses += game.bankrupt.length;
}
const n = results.length;
const share = (k) => `${((100 * k) / n).toFixed(1)} %`;
const mean = crowned.length ? (crowned.reduce((a, b) => a + b, 0) / crowned.length).toFixed(1) : '-';
const summary = {
  games: n,
  minutes: ((Date.now() - started) / 60000).toFixed(1),
  wins: Object.fromEntries(Object.entries(wins).map(([h, k]) => [h, share(k)])),
  endings: Object.fromEntries(Object.entries(endings).map(([e, k]) => [e, share(k)])),
  coronation_round_mean: mean,
  bankrupt_house_games: `${((100 * bankruptHouses) / (4 * n)).toFixed(1)} %`,
};
console.log(JSON.stringify(summary, null, 2));
writeFileSync(join(work, 'summary.json'), JSON.stringify({ summary, results }, null, 1));
console.log(`details: ${join(work, 'summary.json')}`);
