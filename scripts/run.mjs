import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
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

const args = ['--path', projectDir];
if (process.argv.includes('--editor')) args.push('--editor');
// The campaign (war table) and the adventures' practice modes until the main menu of milestone M8
// picks them; default: battle prototype.
const scenes = {
  '--campaign': 'res://src/render/campaign/campaign_main.tscn',
  '--joust': 'res://src/render/joust/joust_main.tscn',
  '--siege': 'res://src/render/siege/trebuchet_main.tscn',
  '--raid': 'res://src/render/raid/raid_main.tscn',
  '--merchant': 'res://src/render/merchant/merchant_main.tscn',
};
for (const [flag, scene] of Object.entries(scenes)) {
  if (process.argv.includes(flag)) args.push(scene);
}

const godot = findGodot();
spawn(godot, args, { detached: true, stdio: 'ignore', shell: /\.(cmd|bat)$/i.test(godot) }).unref();
