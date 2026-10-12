# Produktionsplan

Sieben Phasen, sechs Tore: Eine Phase endet erst, wenn ihr Tor erfüllt ist – sonst wird umgebaut oder gestrichen. Annahme: 2–4 Personen plus KI-Agenten, rund 13–18 Monate bis Version 1.0; allein grob doppelt so lang.

*[Zeichnung: Roadmap · 7 Phasen, 6 Tore – nur im Claude-Doc: https://claude.ai/artifact/W3cmYnemZstFuwPXhRe9NY]*

Tor 2 ist das wichtigste: Dort wird ein Modul umgebaut oder gestrichen, solange es noch billig ist.

## Arbeitsweise

- **Wochenrhythmus:** Montag ExecPlans für die Woche, täglich Build und Tests, Freitag Playtest auf PC und Steam Deck plus Art-Review.
- **Definition of Done je Aufgabe:** Tests, Daten-Lint und Determinismus-Check grün; keine neuen Warnungen; STATUS.md aktualisiert; bei sichtbaren Änderungen ein Screenshot oder GIF.
- **Arbeitsteilung:** Codex implementiert nach ExecPlan – Simulation, Werkzeuge, Tests, UI-Gerüst, Datenpipelines. Claude prüft Design und Code, wertet Balancing-Läufe aus und schreibt Texte. Menschen verantworten Spielgefühl, Art Direction, Playtests und die Entscheidungen an den Toren.
- **Versionen:** Jede Phase endet mit einem getaggten Build; die Godot-Version wird je Phase eingefroren.

## Phase 0 – Fundament (3–4 Wochen)

Ziel: ein testbares Projektfundament und eine bewiesene Asset-Pipeline, noch ohne Gameplay.

- [ ] Repo mit Godot 4.x, Git LFS, Ordnerstruktur, AGENTS.md, .agent/PLANS.md und docs/ (GDD, ROADMAP, STATUS, BUGS)
- [ ] Alle Datendateien aus dem GDD mit Schemas und Daten-Lint
- [ ] Wirtschaftsformeln als reine Funktionen, das Rechenbeispiel als Golden-Test
- [ ] SimRng und Determinismus-Check
- [ ] CI mit headless Tests und Exporten für Windows, macOS und Linux
- [ ] Pipeline-Test: Ritter aus Blender mit 3 Animationen per Retargeting in Godot, Pferd mit Galopp, 200 VAT-Figuren auf dem Steam Deck
- [ ] Drei Style Frames (Karte, Schlacht, Burg Stufe 3) und Test des Toon- und Kontur-Shaders
- [ ] Pferde-Animationspaket gekauft und geprüft

**Tor 1:** CI grün; Ritter und Pferd animiert in Godot; 200 VAT-Figuren mit mindestens 60 fps auf dem Steam Deck; Style Frames abgenommen.

## Phase 1 – Prototypen (6–8 Wochen)

Ziel: für jedes riskante Modul in Graybox klären, ob es Spaß macht – in der Reihenfolge des Risikos.

| Prototyp | Frage | Umfang | Kill-Kriterium |
| --- | --- | --- | --- |
| P1 Schlacht | Fühlt sich das Befehlen von Gruppen aus der Vogelperspektive taktisch an? | 3 Einheitentypen, freies Feld, Formationen, Moral, 1 Gelände, Couch-Duell | Tester spielen keine zweite Runde freiwillig |
| P2 Wirtschaft | Erzeugt die Kornspannung echte Entscheidungen? | nur UI: 10 Jahre in 15 Minuten, 2 Provinzen, Ereignisse | Steuer und Ration werden einmal eingestellt und nie wieder |
| P3 Tjost | Ist der Tjost lesbar und fair ohne Würfel? | Ego-Sicht, Anritt, Zielen, Timing, Haltung | Treffer wirken wie Zufall |
| P4 Belagerung | Macht Blidenbeschuss mit Physik Spaß? | Bausatzmauer, Gegengewicht, Winkel, Wind | Ergebnis wirkt willkürlich oder dauert zu lange |

Burgüberfall und Kaufmannszug kommen erst in Phase 3 – sie variieren bekannte Mechaniken.

- [ ] P1 bis P4 gebaut, je ein Playtest mit mindestens 5 Testern
- [ ] Fragebogen: Spaß 1–5, Verständnis, „würde nochmal spielen“
- [ ] Entscheidungsprotokoll je Prototyp: behalten, umbauen oder streichen

**Tor 2:** Jeder Prototyp erreicht im Mittel mindestens 4 von 5. Liegt einer darunter, wird er einmal umgebaut und neu getestet, danach vereinfacht oder gestrichen.

## Phase 2 – Vertical Slice (10–12 Wochen)

Ziel: 20–30 Minuten, die sich wie das fertige Spiel anfühlen.

- **Karte:** Rhein-Region mit Aachen, Köln, Trier, Mainz, Pfalz am Rhein und Speyer & Trifels. Sonderaufstellung: Welfen (Spieler) starten in Köln, Staufer (KI) in Speyer & Trifels; Krönung mit 3 der 4 rheinischen Stimmen.
- **Systeme:** alle Rundenphasen, vollständige Wirtschaft, Gebäude, Burgstufen 1–3, Wahlfürstengunst, Krönung, Schlacht (Offenes Feld und Furt), Tjost, einfache Utility-KI, Speichern.
- **Qualität:** finale Art im Ausschnitt (Karte, Burg 1–3, Spieß, Armbrust, Ritter mit Pferd), Musikentwurf für Karte und Schlacht, Prolog als Skriptentwurf.

* [ ] Slice spielbar vom Start bis zur Krönung oder Niederlage
* [ ] Balance-Runner mit 1.000 Slice-Partien
* [ ] 10 externe Playtests ausgewertet
* [ ] Trailer-Aufnahmen und Capsule-Art

**Tor 3:** 20–30 Minuten in Zielqualität; Playtest-Note mindestens 4 von 5; Steam-Seite live; Trailer veröffentlicht.

## Phase 3 – Produktion bis Alpha (6–8 Monate)

Ziel: alle Systeme und Inhalte, gebaut in Monatsmeilensteinen auf dem Fundament des Slices. Jeden Monat ein Playtest, jede Woche ein Balance-Lauf.

| Monat | Meilenstein | Inhalt |
| --- | --- | --- |
| 1 | Reich komplett | 31 Provinzen, 4 Häuser, alle Gebäude, Burgstufen 1–5, Zierde, Provinzburgen |
| 2 | Heer komplett | alle Einheitentypen und Anführer, 8 Schlachtfelder, Pferde, VAT-Massen, Auto-Resolve |
| 3 | Abenteuer | Belagerung mit Sturm, Burgüberfall, Kaufmannszug als Streichkandidat |
| 4 | Politik | Wahlfürsten, Huldigung, Kirchenbann, Diplomatie, Heiratspolitik, alle Ereignisse |
| 5 | Gegner und Mitspieler | KI-Persönlichkeiten, Schwierigkeitsgrade, Hot-Seat, Couch-Duell, Team-Variante |
| 6 | Demo | Prolog plus 8 Runden auf voller Karte, Deutsch und Englisch, Steam Next Fest |
| 7–8 | Puffer und Feinschliff | Story-Tafeln, Musik, Chronik, Komfortfunktionen |

**Tor 4:** Feature complete – alle Systeme spielbar, Platzhalter-Grafik erlaubt, Demo veröffentlicht.

## Phase 4 – Beta (2–3 Monate)

- [ ] Content complete: alle Tafeln, Musik, Sprachaufnahmen, 30 Ereignisse
- [ ] Balancing mit wöchentlich 1.000 KI-Partien gegen die Zielwerte aus dem GDD
- [ ] Leistungsbudgets auf dem Steam Deck erreicht
- [ ] Barrierefreiheit und Optionen vollständig
- [ ] Errungenschaften, Cloud-Saves, Steam-Integration
- [ ] Externe Beta mit mindestens 50 Testern über Discord

**Tor 5:** Content complete; keine A-Fehler; Schlachten mit mindestens 40 fps auf dem Steam Deck.

## Phase 5 – Launch (4 Wochen)

- [ ] Release Candidates mit QA-Checkliste: neue Partie, Laden, Hot-Seat, jedes Minispiel, Controller, Steam Deck
- [ ] Steam-Deck-Prüfung beantragt
- [ ] Launch-Trailer, Presskit, Keys für Presse und Creator
- [ ] Day-1-Patch geplant, Hotfix-Bereitschaft für die ersten zwei Wochen

**Tor 6:** Release Candidate ohne offene A- und B-Fehler freigegeben.

## Phase 6 – Nach dem Launch

- In den ersten 4 Wochen wöchentliche Hotfixes, danach monatliche Updates.
- Asynchrones Online-Spiel, das nur Befehle und Seed überträgt.
- Konsolenport über einen Porting-Partner.
- Erweiterungen: Romzug mit Kaiserkrönung, Kreuzzug, Hanse mit Seehandel.

## Marketing parallel

| Zeitpunkt | Maßnahme |
| --- | --- |
| ab Phase 1 | Devlog, Discord, kurze GIFs aus Prototypen (Ritteransturm, Mauereinsturz) |
| Tor 3 | Steam-Seite mit Capsule-Art und Trailer; Wunschlisten sammeln |
| Phase 3, Monat 6 | Demo zum Steam Next Fest, Vorschauen bei Creatorn |
| Phase 4 | Beta-Keys für die Community, Presse-Vorschau |
| Phase 5 | Launch-Trailer, Startrabatt, Keys für Streamer |
