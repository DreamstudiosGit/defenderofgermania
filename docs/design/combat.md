# Combat

Ported from the GDD sections "Militär & Einheiten" and "Schlacht-Modul". Unit stats and constants live in `data/combat.json`; recruiting costs and upkeep in `data/economy.json`.

## Units
Rock-paper-scissors: spearmen beat knights, knights beat crossbowmen, crossbowmen beat spearmen. A company ("Rotte") is 30 men, shown as 6–12 figures. Damage per hit = attack − armor, at least 1.

Command groups: infantry (levy, spearmen, brabanters), archers (crossbowmen), cavalry (knights, leader), siege (trebuchets).

## Battle contract
`BattleSetup` (two `BattleSide`s, terrain, defender wall level, winter flag) goes into a resolver, a `BattleResult` comes out: winner, remaining health share per company in setup order, captured leaders, duration. Auto-resolve and the real-time battle are both resolvers; the campaign applies the result to the armies.

## Auto-resolve
Every battle can be auto-resolved; AI against AI always is.
- Strength `K = (Σ companies w · HP/HPmax + leader w) · (1 + 0.05 · leadership) · (0.5 + morale/200) · G · (1 + R)`.
- w = auto-resolve value of the unit; morale = average unit morale + 5 per leadership point (with leader) + side modifiers (−10 while the house's leader is captured); attackers in winter ×0.75.
- G (defender only) = 1 + 0.25 · wall level in a castle, 1.15 on hills, else 1.
- R = +10 % per (own unit type, enemy unit type) pair the own type is strong against, at most +30 %.
- A human side counts 10 % less, so playing battles yourself pays off.
- `P(attacker wins) = K_A^1.5 / (K_A^1.5 + K_B^1.5)`.
- Losses spread evenly over all companies: loser 40–70 % of its HP, winner 30 % · K_loser/K_winner, clamped to 5–70 %.
- An empty defender loses without a fight.

## Battle module (prototype P1)
Real-time battle from the GDD "Schlacht-Modul" as a graybox: simulation in `src/systems/combat/battle_*.gd`, presentation in `src/render/battle/` (main scene `battle_main.tscn`), HUD and menus in `src/ui/battle/`. All constants and the default armies (Welfen vs. Staufer, each 2 spearmen, 2 crossbowmen, 2 knights and a leader with leadership 3) are in the `battle` section of `data/combat.json`.

### Simulation
- Fixed 30 Hz tick, deterministic: the state is packed arrays (`BattleState`), each side sends one `BattleInput` per tick, devices never reach the simulation. No chance in combat (pillar "skill over dice"); the seed only jitters figure positions. Same setup, seed and inputs give the same `BattleResult` and `BattleState.checksum()`.
- Field 300 × 180 m, attacker left, defender right; 15 s deployment inside the own 80 m zone, then at most 240 s of fight.
- A company is a squad of its unit's `figures` in formation. Figures follow their formation slots, push each other apart and meet in melee through a 3 m bucket grid of figures; companies stop when they touch an enemy.
- The player commands one group; the other groups keep their last order (a running charge or march finishes) and otherwise hold and fight back. Siege has no formations of its own yet and uses the infantry's.

### Attacks
- Infantry charges the nearest enemy within ±60° of its facing (else the nearest enemy) until contact; a charge ends when the target flees or dies.
- Archers: a company holds 3 volleys (the bolt marks) and reloads one per `reload` seconds. Line fires one full volley per attack command; staggered fires half volleys on its own, reloading in half the time. A volley hits the target within ±30° of the facing and in range: `max(1, 14 − armor × 0.5)` per company.
- Cavalry charges straight ahead (or straight at a right-clicked enemy) for up to 100 m, accelerating at 4 m/s² to its charge speed. Impact on the first enemy touched: `max(1, melee × formation impact × charge multiplier − armor) × 3 s × min(1, run / 30 m)`; knights' charge multiplier (×2) needs at least 5 m/s. Then normal melee.
- Melee per second: `max(1, melee − armor)`, spearmen ×2.5 against cavalry (knights and leader); hedgehogs take half damage from cavalry.

### Formations
| Group | Formation 1 | Formation 2 |
|---|---|---|
| Infantry | Line (2 ranks) | Hedgehog: ring, cannot move, half damage from cavalry, no flank |
| Archers | Line: full volley on command, reload per volley | Staggered: half volley, fires on its own, half reload time |
| Cavalry | Wedge: impact ×2 | Line: impact ×1, front arc ±90° instead of ±60° |

### Morale and victory
- Start = unit morale + 5 × leadership + the side's `morale_bonus`; current = start − 0.5 per % HP lost + shocks + leader aura (+15 within 30 m).
- Shocks: entering melee from outside the target's front arc −15 (once per engagement); captured leader (HP 0) −20 for every company of the side.
- Below 20 a company flees to its own edge and leaves the field there. Rally (leader) brings fleeing companies within 30 m back with at least 40 morale; the 45 s cooldown only starts when someone was rallied.
- A side loses when none of its companies still fights; a lone leader does not hold the field. After 240 s the higher `AutoResolve.strengths()` of the companies still fighting wins (current health, no human malus, no chance); a tie keeps the defender on the field.
- Result: health share per company in setup order (fled companies keep theirs), captured leaders, duration in seconds including deployment.

### Controls
| Action | Controller | Mouse and keyboard |
|---|---|---|
| Switch group | LT / RT (also LB / RB) | Q / E or 1–4 |
| Move | left stick (also D-pad) | WASD (also arrow keys) or right-click the ground |
| Attack | A | Space or right-click an enemy |
| Change formation | B | F |
| Rally (leader) | Y | R |
| Zoom (2 levels) | right stick | mouse wheel (also Page Up / Down) |
| Back to the menu | Start | Esc |

The start menu assigns keyboard and mouse, controller 1, controller 2 or the computer to each side (couch duel: two controllers or keyboard plus controller). Input actions are registered at runtime per device (`BattleInputMap`), not in `project.godot`. A fresh push of the stick overrides any order but a running cavalry charge; a held stick does not cancel an attack given while holding it.

### Not in P1
Terrain effects and cover, siege weapons, light by season, dust and tumbling figures (only a 0.5 s slow motion on charge impacts), the illuminated end banner and prestige.
