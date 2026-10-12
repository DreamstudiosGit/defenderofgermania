# Defender of Germania Crown

Working title from the GDD: **THRONSTREIT 1198** (international title open). The binding GDD is `docs/GDD.md` (German; all numbers, formulas, tables and names in it are binding), the production plan `docs/ROADMAP.md`; both are exports of the Claude doc https://claude.ai/artifact/W3cmYnemZstFuwPXhRe9NY (2026-10-12), which also holds the two drawings. Milestones, their state and open design questions: `docs/STATUS.md`. Sections are ported to `docs/design/<system>.md` when their system is implemented; until then the GDD is the source, except where the scope below cuts a feature.

## Vision
Turn-based strategy with real-time battles: Defender of the Crown meets North & South, with the grain economy of Kaiser — set in the German throne dispute of 1198. Four houses (Welfen, Wettiner, Staufer, Wittelsbacher; north vs. south) race for the crown. A house is crowned when it holds three pillars at once: imperial regalia, coronation site and electors' votes. Tagline: *Two kings. One crown. Your house decides.*

## Core loop
One round is one season, at most 48 rounds (12 years). Each house plays phases 1–3 in turn, phase 4 settles all houses at once:
1. Event card
2. Administration — tax rate, ration, grain trade, buildings, recruiting
3. Campaign — each army moves one province; battles and sieges
4. Settlement — income, upkeep, grain, satisfaction, prestige; census in spring, harvest and new grain price in autumn

Victory: coronation (with the electors, M5), subjugation of all other houses, or highest legitimacy after round 48.

## Pillars
Every feature serves at least one, otherwise it is cut.
1. One evening, one realm — a game fits an evening, a round takes 1–3 minutes.
2. Skill over dice — battles reward timing and tactics; chance only in harvests and events.
3. Visible progress — castles grow, banners fly, armies get grander.
4. Readable economy — four resources, every formula shown in its tooltip.
5. A wink with respect — humour like North & South, history as a loving backdrop.

## Scope
- Platform: Steam (Windows, macOS, Linux) and Steam Deck; controller and mouse/keyboard as equals (ADR 0003).
- Modes: 1 vs. AI, hot-seat for 2–4 players, 1v1 couch battle; online v1.0 via Steam Remote Play Together, async online after launch.
- Map: 31 provinces in three regions, 63 connections; 4 houses, 7 electors, 6 church princes, 10 neutral lords.
- Minigames: joust, trebuchet siege, castle raid and merchant train (M6; the merchant train is the first to cut).
- Electors, favour, coronation, homage, patron cards, the ban and all 18 events (M5).
- Cut: diplomacy between houses — alliances, truces, treaties, marriages, the peace congress and the camp truce (owner decision 2026-10-12).
- Systems: `map`, `combat`, `economy`, `events`, `ai` (ADR 0005).
- Texts in German and English; low-poly 3D in the look "Codex Manesse comes alive".
- Saves must survive updates from the first public playtest on.
