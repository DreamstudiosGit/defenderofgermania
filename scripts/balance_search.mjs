// Balance search (M7): hill climbing over the AI's data values. Each step perturbs a few values
// of a copy of data/ai.json, plays the same seeds (scripts/balance.mjs) and keeps the change if
// the distance to the GDD targets shrinks — each house 20–30 %, coronation the main way and on
// average in rounds 25–35, bankruptcy under 5 %. data/ai.json itself is never written; the best
// file and the log land in a temp folder.
// node scripts/balance_search.mjs [--steps=30] [--games=160] [--jobs=8]
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, appendFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const option = (name, value) => {
  const arg = process.argv.find((a) => a.startsWith(`--${name}=`));
  return arg ? Number(arg.split('=')[1]) : value;
};
const steps = option('steps', 30);
const games = option('games', 160);
const jobs = option('jobs', 8);
const work = mkdtempSync(join(tmpdir(), 'thronstreit-search-'));
const logFile = join(work, 'search.log');

// Tunable values: path in ai.json and range.
const space = [
  ['values.pillar', 300, 2500], ['values.pillar_urgency_rounds', 10, 60], ['values.vote', 80, 700],
  ['values.province', 20, 200], ['values.prestige', 1, 20], ['values.favour', 0.5, 10],
  ['opportunity.attack_ratio', 1.2, 2.2], ['opportunity.storm_ratio', 1.2, 3.0],
  ['security.threat_ratio', 0.5, 1.6], ['security.home_weight', 1, 5],
  ['security.far_share', 0.05, 1.0], ['security.guarding_share', 0.1, 1.0],
  ['supply.gold_reserve', 20, 200], ['goals.payback_rounds', 4, 30], ['goals.save_factor', 1.0, 2.5],
  ['goals.min_utility', 0.02, 1.0], ['army.max_share_of_income', 0.2, 0.9],
];
for (const personality of ['merchant', 'builder', 'conqueror', 'diplomat']) {
  for (const category of ['economy', 'military', 'castle', 'court', 'favour', 'adventure']) {
    space.push([`personalities.${personality}.weights.${category}`, 0.3, 2.5]);
  }
}

const get = (obj, path) => path.split('.').reduce((o, k) => o[k], obj);
const set = (obj, path, value) => {
  const keys = path.split('.');
  const last = keys.pop();
  keys.reduce((o, k) => o[k], obj)[last] = value;
};
const percent = (text) => Number(String(text).replace('%', '').trim());

function evaluate(config, label) {
  const file = join(work, `${label}.json`);
  writeFileSync(file, JSON.stringify(config, null, 2));
  const run = spawnSync('node', [join(projectDir, 'scripts', 'balance.mjs'), `--games=${games}`, `--jobs=${jobs}`,
    '--seed=1', `--ai=${file}`], { encoding: 'utf8', maxBuffer: 1 << 26 });
  const text = run.stdout;
  const summary = JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1));
  let penalty = 0;
  for (const house of ['welfen', 'wettiner', 'staufer', 'wittelsbacher']) {
    const share = percent(summary.wins[house] ?? '0');
    penalty += Math.max(0, Math.abs(share - 25) - 5) ** 2;
  }
  const crowned = percent(summary.endings.coronation ?? '0');
  penalty += Math.max(0, 50 - crowned) ** 2 / 4;
  const round = Number(summary.coronation_round_mean);
  penalty += Number.isFinite(round) ? (Math.max(0, Math.abs(round - 30) - 5) ** 2) * 2 : 400;
  penalty += Math.max(0, percent(summary.bankrupt_house_games) - 5) ** 2 * 3;
  return { penalty, summary };
}

let best = JSON.parse(readFileSync(join(projectDir, 'data', 'ai.json'), 'utf8'));
let bestScore = evaluate(best, 'base');
appendFileSync(logFile, `base ${bestScore.penalty.toFixed(1)} ${JSON.stringify(bestScore.summary)}\n`);
console.log(`base penalty ${bestScore.penalty.toFixed(1)}`);
for (let step = 1; step <= steps; step++) {
  const candidate = structuredClone(best);
  const changed = [];
  for (let i = 0; i < 3; i++) {
    const [path, low, high] = space[Math.floor(Math.random() * space.length)];
    const factor = Math.exp((Math.random() * 2 - 1) * 0.35);
    const value = Math.min(high, Math.max(low, get(candidate, path) * factor));
    set(candidate, path, Math.round(value * 100) / 100);
    changed.push(`${path}=${Math.round(value * 100) / 100}`);
  }
  const score = evaluate(candidate, `step${step}`);
  const better = score.penalty < bestScore.penalty;
  appendFileSync(logFile, `${step} ${better ? 'KEEP' : 'drop'} ${score.penalty.toFixed(1)} ${changed.join(' ')} ${JSON.stringify(score.summary)}\n`);
  console.log(`step ${step}: ${score.penalty.toFixed(1)} (best ${bestScore.penalty.toFixed(1)}) ${better ? 'KEEP' : 'drop'} ${changed.join(' ')}`);
  if (better) {
    best = candidate;
    bestScore = score;
    writeFileSync(join(work, 'best_ai.json'), JSON.stringify(best, null, 2));
  }
}
console.log(`best penalty ${bestScore.penalty.toFixed(1)}: ${join(work, 'best_ai.json')}`);
console.log(JSON.stringify(bestScore.summary, null, 2));
