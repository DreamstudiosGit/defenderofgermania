import { spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const checks = [
  'godot --headless --import',
  'gdlint .',
  'godot --headless --script res://scripts/typecheck.gd',
  'godot --headless -s addons/gut/gut_cmdln.gd',
];
const defaultBranch = process.env.DEFAULT_BRANCH ?? 'main';

const message = process.argv[2];
if (!message) {
  console.error('usage: node scripts/ship.mjs "<type>(<system>): <summary>"');
  process.exit(1);
}

function exec(command, args, options = {}) {
  const result = args
    ? spawnSync(command, args, { encoding: 'utf8', ...options })
    : spawnSync(command, { encoding: 'utf8', shell: true, ...options });
  const output = [result.stdout, result.stderr, result.error?.message].filter(Boolean).join('\n');
  return { ok: result.status === 0, output };
}

function errorExcerpt(output) {
  const lines = output.split(/\r?\n/);
  const keep = new Set();
  lines.forEach((line, i) => {
    if (/error|fail/i.test(line)) {
      for (let j = i; j <= i + 3 && j < lines.length; j++) keep.add(j);
    }
  });
  const picked = [...keep].slice(0, 60).map((i) => lines[i]);
  return (picked.length ? picked : lines.slice(-30)).join('\n');
}

function step(label, command, args, options) {
  const { ok, output } = exec(command, args, options);
  if (!ok) {
    console.log(`FAILED: ${label}\n${errorExcerpt(output)}`);
    process.exit(1);
  }
  console.log(`ok: ${label}`);
}

const status = exec('git', ['status', '--porcelain']);
if (!status.ok) {
  console.log(status.output);
  process.exit(1);
}
if (!status.output.trim()) {
  console.log('nothing to ship');
  process.exit(0);
}

for (const key of ['user.name', 'user.email']) {
  if (!exec('git', ['config', key]).output.trim()) {
    console.log(`FAILED: git ${key} is not set (git config ${key} "...")`);
    process.exit(1);
  }
}

const env = { ...process.env, CI: 'true' };
for (const check of checks) step(check, check, null, { env });

mkdirSync('docs', { recursive: true });
if (!existsSync('docs/done.md')) writeFileSync('docs/done.md', '# Done\n\n');
// Only the subject line; a rerun after a failed commit or push must not log it twice.
const entry = `- ${new Date().toLocaleDateString('sv-SE')} ${message.split('\n')[0]}\n`;
if (!readFileSync('docs/done.md', 'utf8').includes(entry)) appendFileSync('docs/done.md', entry);

step('git add', 'git', ['add', '-A']);
step('git commit', 'git', ['commit', '-m', message]);

const branch = exec('git', ['branch', '--show-current']).output.trim();
step(`git push ${branch}`, 'git', ['push', '-u', 'origin', branch]);

if (branch !== defaultBranch) {
  if (exec('gh', ['pr', 'view']).ok) {
    console.log('PR already open');
  } else {
    const pr = exec('gh', ['pr', 'create', '--fill']);
    console.log(pr.ok ? pr.output.trim() : `PR not created: ${pr.output.trim()}`);
  }
}
