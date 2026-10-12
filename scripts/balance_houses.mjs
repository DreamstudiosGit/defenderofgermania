// Means of each house's final state over a balance run's games (scripts/balance.mjs details).
// node scripts/balance_houses.mjs <summary.json>
import { readFileSync } from 'node:fs';

const { results } = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const sums = {};
for (const game of results) {
  for (const [house, values] of Object.entries(game.houses || {})) {
    sums[house] ??= { games: 0 };
    sums[house].games += 1;
    for (const [key, value] of Object.entries(values)) {
      sums[house][key] = (sums[house][key] || 0) + Number(value);
    }
  }
}
for (const [house, values] of Object.entries(sums)) {
  const means = Object.entries(values).filter(([k]) => k !== 'games').map(([k, v]) => `${k} ${(v / values.games).toFixed(2)}`);
  console.log(`${house.padEnd(14)} ${means.join('  ')}`);
}
