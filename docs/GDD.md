# THRONSTREIT 1198 – Game Design Document

Oct 10, 2026 · @Michael

Dieses GDD beschreibt das Spiel; der Weg dorthin steht im Produktionsplan, die Übergabe an Codex im Codex-Setup.

## Vision & Überblick

THRONSTREIT 1198 ist ein rundenbasiertes Strategiespiel mit Echtzeit-Schlachten und Action-Minispielen: Defender of the Crown trifft North & South, mit dem Wirtschaftsherz von Kaiser – im Deutschland des Thronstreits. Tagline: *Zwei Könige. Eine Krone. Dein Haus entscheidet.*

| Eckdaten | Festlegung |
| --- | --- |
| Genre | Runden-Strategie + Echtzeit-Schlachten + Arcade-Minispiele |
| Plattformen | Steam (Windows, macOS, Linux), Steam Deck ab Launch; Switch 2 und Konsolen später über Porting-Partner |
| Engine | Godot 4, Figuren und Gelände in 3D aus Blender |
| Spieler | 1 gegen KI; 2–4 im Hot-Seat; Schlachten im Couch-Duell 1 gegen 1 |
| Partielänge | 60–120 Minuten, maximal 48 Runden (12 Jahre) |
| Preisrahmen | 19,99–24,99 € |
| Altersziel | USK/PEGI 12: Comic-Gewalt, kein Blut |

**Design-Säulen** – jedes Feature muss mindestens eine bedienen, sonst fliegt es:

1. **Ein Abend, ein Reich.** Eine Partie passt in einen Abend, eine Runde dauert 1–3 Minuten.
2. **Können statt Würfel.** Tjost, Schlacht und Belagerung belohnen Timing und Taktik; Zufall gibt es nur bei Ernten und Ereignissen.
3. **Sichtbarer Fortschritt.** Jede Investition ist zu sehen: Burgen wachsen, Banner wehen, Armeen werden prächtiger.
4. **Lesbare Wirtschaft.** Vier Ressourcen, jede Formel im Tooltip ausgerechnet.
5. **Augenzwinkern mit Respekt.** Humor wie North & South, Geschichte als liebevolle Kulisse.

**Zielgruppen:** die Amiga- und C64-Generation (40–55) mit Nostalgie für die Vorbilder; Strategie-Fans (20–40) aus dem Umfeld von Manor Lords, Kingdom Two Crowns und Thronefall; Couch-Spieler, die zu zweit an einem Bildschirm spielen.

**USPs:** unverbrauchtes Setting (Deutschland 1198), drei Genres in einer Partie, der Signatur-Look „Codex Manesse wird lebendig“, Hot-Seat und Couch-Duell.

**Lehre aus dem offiziellen Remake:** *Defender of the Crown: The Legend Returns* erschien am 13.08.2026 und kam auf einen Metascore von 67 ([Notebookcheck](https://www.notebookcheck.com/Neues-Mittelalter-Strategie-RPG-startet-auf-Steam-mit-drei-Spielmodi-und-Launch-Rabatt.1369414.0.html)). Spieler bemängeln zufälliges Tjosten, dünnen Inhalt und fehlende Tutorials ([Vaporlens](https://vaporlens.app/app/4208140/defender_of_the_crown_the_legend_returns)). Unsere Antwort: Säule 2 für alle Minispiele, Wirtschaft und Burgausbau als Tiefe, ein spielbarer Prolog als Tutorial.

## Setting & Legitimität

Gekrönt wird, wer drei Säulen zugleich hält: Reichsinsignien, Krönungsort und Fürstenstimmen. Das Spiel beginnt 1198 mit der historischen Doppelwahl und läuft ab dann als alternative Geschichte.

**Rahmen:** 1198 wählen die Fürsten zwei Könige, den Staufer Philipp und den Welfen Otto IV.; Otto ist mit England verbündet, Philipp mit Frankreich ([Urkunden Philipps von Schwaben](https://isdistribution.com/?p=1415281)). Im Spiel bleiben beide Könige schwache Hintergrundfiguren. Vier Häuser nutzen das Machtvakuum, fürs Spiel zugespitzt auf Nord gegen Süd.

**Historischer Kern als Regel:** Otto wurde am richtigen Ort in Aachen gekrönt, aber mit nachgemachten Insignien; Philipp besaß die echten, konnte sich aber nur in Mainz krönen lassen ([ADB](https://de.wikisource.org/wiki/ADB:Philipp_von_Schwaben)). Daraus wird: Jedes fehlende „echte“ Element kostet eine zusätzliche Fürstenstimme.

| Insignien | Krönungsort | Nötige Stimmen | Krönender Erzbischof | Vorbild |
| --- | --- | --- | --- | --- |
| echt | Aachen | 4 von 7 | Köln | – |
| nachgemacht | Aachen | 5 von 7 | Köln | Otto IV. |
| echt | Mainz (Notkrönung) | 5 von 7 | Mainz | Philipp |
| nachgemacht | Mainz (Notkrönung) | 6 von 7 | Mainz | – |

- **Echte Insignien** liegen zu Spielbeginn auf Burg Trifels (Provinz Speyer & Trifels, Staufer). Wer die Provinz hält, hält die Insignien. Ein erfolgreicher Burgüberfall kann sie stehlen und in die eigene Stammburg bringen.
- **Nachgemachte Insignien** fertigt jedes Haus ab Burgstufe 3: 300 Taler, 2 Runden Bauzeit.
- **Krönungsort** zählt nur, wenn das Haus die Provinz (Aachen oder Mainz) zum Zeitpunkt der Krönung kontrolliert.
- **Krönender Erzbischof:** Seine Gunst gegenüber dem Haus muss mindestens 50 betragen, oder das Haus kontrolliert seine Provinz.
- **Krönung ausrufen** ist eine Aktion der Winterphase. Sind alle Bedingungen erfüllt, folgt die Krönungsszene als Buchmalerei-Tafel und die Partie ist gewonnen.

**Ton der Erzählung:** Ein Prolog („Der Kaiser ist tot“) führt ins Spiel ein; Story-Tafeln kommentieren große Momente mit trockenem Humor. Jedes Haus hat ein eigenes Krönungs- und ein Exil-Ende. Die sieben Wahlfürsten sind eine spielerische Vorwegnahme des späteren Kurfürstenkollegs; das sagt das Spiel auch offen im Glossar.

## Spielablauf

Eine Partie dauert höchstens 48 Runden; jede Runde ist eine Jahreszeit. Die Phasen 1–3 spielt jedes Haus nacheinander (Hot-Seat-tauglich), Phase 4 rechnet für alle gleichzeitig ab. Zielzeit pro Runde und Haus: rund 2 Minuten ohne Schlachten.

**Partieaufbau**

- Auswahl: Haus (oder zufällig), Gegner mit KI-Persönlichkeit und Schwierigkeit, Startvariante (historisch oder gemischte Startgunst), Seed.
- Startwerte je Haus: 200 Taler, 300 Scheffel Korn, Ansehen 20, Steuersatz 15 %, Ration 3, Stammburg Stufe 1, 3 Gönner-Karten.
- Startarmee in der Stammprovinz: 2× Aufgebot, 2× Spießträger, geführt vom Anführer.
- Zugreihenfolge: niedrigstes Ansehen zuerst (Aufholmechanik), Gleichstand nach Seed.

**Phasen einer Runde**

1. **Ereignis:** Eine Karte aus dem Ereignis-Pool wird gezogen; manche verlangen eine Entscheidung.
2. **Verwaltung:** Steuersatz, Ration, Kornhandel, Bauaufträge, Rekrutierung, Diplomatie.
3. **Feldzug:** Jede Armee zieht in eine Nachbarprovinz. Trifft sie auf eine feindliche Armee, folgt eine Schlacht; auf eine Burg ohne Armee, eine Belagerung. Zusätzlich höchstens ein Abenteuer pro Runde (Tjost, Burgüberfall oder Kaufmannszug).
4. **Abrechnung (global):** Einnahmen, Unterhalt, Kornverbrauch, Zufriedenheit, Ansehen; im Frühling die Volkszählung, im Herbst Ernte und neuer Kornpreis.

| Jahreszeit | Wirtschaft | Feldzug | Hof |
| --- | --- | --- | --- |
| Frühling | Volkszählung; Kornpreis am höchsten | normal | Turniere möglich |
| Sommer | – | Armeen ziehen 2 Provinzen, wenn die erste eigene ist | Turniere möglich |
| Herbst | Ernte; Kornpreis neu, am niedrigsten; Märkte ×1,25 | normal | – |
| Winter | Truppen außerhalb eigener Provinzen essen ×1,5 | Angriffe mit −25 % Moral | Hoftag: Krönung, Heirat, Verträge |

**Sieg**

1. **Krönung** nach der Regel im Abschnitt Setting – der Hauptweg.
2. **Unterwerfung:** Alle anderen Häuser haben ihre Stammburg verloren und sind ausgeschieden.
3. **Zeitablauf** nach Runde 48 („Der Papst entscheidet“): Es gewinnt die höchste Legitimität.

```latex
L = 30 \cdot I_{echt} + 10 \cdot I_{nach} + 20 \cdot O_{Aachen} + 10 \cdot O_{Mainz} + 10 \cdot S + 2 \cdot P + \frac{A}{5}
```

I = Insignien gehalten (0/1), O = Krönungsort kontrolliert (0/1), S = sichere Fürstenstimmen, P = Provinzen, A = Ansehen.

**Exil statt sofortiger Niederlage:** Verliert ein Haus seine Stammburg, behält es eine Armee und hat 4 Runden, eine Provinz mit Burg ab Stufe 2 zu erobern. Die wird neue Stammburg (eine Stufe niedriger). Sonst scheidet es aus, seine Provinzen werden neutral.

**Burgfrieden:** Häuser desselben Lagers starten verbündet. Ein Bündnisbruch kostet 10 Ansehen – bis ein Haus zwei der drei Säulen hält; dann endet der Burgfrieden für alle. In der Team-Variante (2 gegen 2) bleibt er bestehen: Wird ein Partner gekrönt, gewinnt das Lager, der andere wird Reichskanzler.

## Häuser & Anführer

Vier spielbare Häuser, je zwei pro Lager, starten mit gleich viel Volk (95–105) und unterscheiden sich durch einen Hausvorteil und ihre Lage. Die Staufer halten die echten Insignien, die Welfen die Gunst Kölns – das spiegelt die Lage von 1198.

| Haus | Lager | Stammburg | Startprovinzen | Hausvorteil | Farben | Schlachtruf |
| --- | --- | --- | --- | --- | --- | --- |
| Welfen | Nord | Dankwarderode (Braunschweig) | Braunschweig, Holstein & Lübeck | Kaufleute: Marktertrag ×1,5, Kornhandel-Spread halbiert | Rot / Gold | „Hie Welf!“ |
| Wettiner | Nord | Burgberg Meißen | Meißen, Thüringen | Silberberge: Bergwerke ×1,5 Ertrag, 30 % günstiger | Grün / Silber | „Hie Wettin!“ |
| Staufer | Süd | Hohenstaufen (Schwaben) | Schwaben, Speyer & Trifels | Ritterschaft: Ritter 25 % günstiger, Tjost-Zeitfenster +40 ms | Schwarz / Gold | „Hie Waiblingen!“ |
| Wittelsbacher | Süd | Kelheim (Bayern) | Bayern, Nürnberg | Diplomaten: Gunstgewinne ×1,5, Geschenke 25 % günstiger | Blau / Silber | „Hie Wittelsbach!“ |

Die Rufe „Hie Welf!“ und „Hie Waiblingen!“ sind die überlieferten Kampfrufe beider Lager; Farben und Rufe von Wettinern und Wittelsbachern sind spielerisch gewählt.

**Anführer:** Jedes Haus führt eine prozedural erzeugte Erbin oder ein Erbe – keine historische Person. Drei Werte von 1 bis 5, zusammen 9 Punkte, jeder mindestens 2; das Haus gibt einen Bonuspunkt vor (Welfen Führung, Wettiner Klinge, Staufer Lanze, Wittelsbacher frei wählbar).

| Wert | Wirkung je Punkt |
| --- | --- |
| Führung | Armeegröße max. 6 + Führung Rotten; Moral der Armee +5; Auto-Resolve-Kampfkraft +5 % |
| Lanze | Tjost-Zeitfenster ±(60 + 15 × Lanze) ms; Zielschwanken −10 % |
| Klinge | Schwertkampf-Schaden +10 %; Parierfenster +20 ms |

- **Steigerung:** Drei Siege in einer Disziplin heben den Wert um 1 (Maximum 5).
- **Gefangennahme:** Fällt der Anführer in Schlacht oder Burgüberfall, wird er gefangen. Lösegeld: 150 Taler + 50 × eigene Burgstufe. Bis dahin keine Abenteuer, Armeen ohne Anführer haben −10 Moral.
- **Erben:** Jedes Haus hält eine Heiratskarte (Erbin oder Erbe) für die Heiratspolitik; eine zweite gibt es ab Burgstufe 4.

**Gönner (das Robin-Hood-Element):** Das Nordlager ruft England, das Südlager Frankreich. Jedes Haus hat 3 Gönner-Karten, höchstens eine pro Runde. Jede Karte wählt bei Einsatz eine Wirkung:

- **Silber:** +200 Taler.
- **Söldner:** 4 Rotten Brabanzonen für eine Schlacht, ohne Unterhalt.
- **Gesandtschaft:** +15 Gunst bei einem Wahlfürsten nach Wahl.

## Reichskarte

31 Provinzen in drei Regionen: Jedes Haus startet mit zwei, sieben gehören Wahlfürsten, 16 sind neutral oder Kirchenland. Krönungsort, Notkrönung, Insignien und vier der sieben Stimmen liegen am Rhein – dort entscheidet sich die Partie.

*[Zeichnung: Provinzkarte · 31 Provinzen, 63 Nachbarschaften, Startaufstellung 1198 – nur im Claude-Doc: https://claude.ai/artifact/W3cmYnemZstFuwPXhRe9NY]*

Die Welfen müssen über die Fürstbistümer Osnabrück und Münster nach Köln und Aachen vorstoßen – wer dort angreift, riskiert den Bann, die Staufer Trifels halten; Wettiner und Wittelsbacher werben um Sachsen, Brandenburg und Böhmen.

### Provinzen

| ID | Provinz | Region | Start | Gelände | Volk | Merkmale | Nachbarn |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FRS | Friesland | Nord | neutral | Marsch | 35 | Hafen; Friesische Freiheit: Z\* +10, Steuer dort höchstens 15 % | BRM, MUN, BBT |
| BRM | Bremen | Nord | Kirche | Marsch | 40 | Erzbistum, Hafen | FRS, OSN, BSW, HOL |
| HOL | Holstein & Lübeck | Nord | Welfen | Ackerland | 45 | Hafen, Markt I (Lübeck) | BRM, BSW, BRB |
| MUN | Münster | Nord | Kirche | Ackerland | 45 | Fürstbistum, Markt I, Friedenskongress | FRS, OSN, KOE, HES |
| OSN | Osnabrück | Nord | Kirche | Hügelland | 35 | Fürstbistum, Friedenskongress, Startgunst Welfen 45 | BRM, BSW, MUN |
| BSW | Braunschweig | Nord | Welfen | Ackerland | 60 | Stammburg Dankwarderode, Mühle | BRM, HOL, OSN, HES, GOS, MAG |
| MAG | Magdeburg | Nord | Kirche | Ackerland | 50 | Erzbistum, Fluss (Elbe) | BSW, GOS, BRB, SXW, THU |
| BRB | Brandenburg | Nord | Wahlfürst | Heide | 35 | Markgraf | HOL, MAG, SXW |
| SXW | Sachsen-Wittenberg | Nord | Wahlfürst | Heide | 35 | Herzog, Fluss (Elbe) | BRB, MAG, MEI |
| GOS | Goslar & Harz | Mitte | neutral | Gebirge | 30 | Erz (Rammelsberg) | BSW, MAG, THU, HES |
| HES | Hessen | Mitte | neutral | Wald | 40 | – | MUN, BSW, GOS, THU, FRA, MAI, KOE |
| THU | Thüringen | Mitte | Wettiner | Hügelland | 50 | Wartburg (Ereignis) | GOS, MAG, MEI, FRA, HES |
| MEI | Meißen | Mitte | Wettiner | Hügelland | 50 | Stammburg, Erz (Freiberg), Fluss (Elbe) | SXW, THU, BOH, FRA |
| BOH | Böhmen | Mitte | Wahlfürst | Hügelland | 70 | König, Garnison 8 Rotten | MEI, NUE, BAY, OST |
| BBT | Brabant | Mitte | neutral | Ackerland | 55 | Tuchhandel, Markt I | FRS, AAC |
| AAC | Aachen | Mitte | neutral | Stadt | 25 | Krönungsort, Mauer 3 | BBT, KOE, TRI |
| KOE | Köln | Mitte | Wahlfürst | Ackerland | 60 | Erzbistum, Fluss (Rhein), Markt I | AAC, MUN, HES, TRI |
| TRI | Trier | Mitte | Wahlfürst | Hügelland | 40 | Erzbistum, Fluss (Mosel) | AAC, KOE, MAI, LOT, PFA |
| LOT | Lothringen | Mitte | neutral | Hügelland | 45 | Grenzland zu Frankreich | TRI, SPT, ELS |
| MAI | Mainz | Mitte | Wahlfürst | Ackerland | 50 | Erzbistum, Notkrönung, Fluss (Rhein) | TRI, HES, FRA, PFA |
| PFA | Pfalz am Rhein | Mitte | Wahlfürst | Hügelland | 45 | Pfalzgraf, Fluss (Rhein) | TRI, MAI, FRA, SPT |
| FRA | Franken | Mitte | Kirche | Ackerland | 55 | Bistümer Würzburg und Bamberg, Fluss (Main) | HES, THU, MEI, MAI, PFA, NUE, SWB |
| SPT | Speyer & Trifels | Süd | Staufer | Wald | 35 | Reichsinsignien, Burg Trifels Mauer 3 | PFA, LOT, ELS, SWB |
| ELS | Elsass | Süd | neutral | Ackerland | 55 | Startgunst Staufer 50, Fluss (Rhein) | LOT, SPT, BRG |
| BRG | Breisgau | Süd | neutral | Wald | 40 | Zähringer (Ereignis) | ELS, SWB, TIR |
| SWB | Schwaben | Süd | Staufer | Hügelland | 60 | Stammburg Hohenstaufen | SPT, BRG, FRA, NUE, BAY, TIR |
| NUE | Nürnberg | Süd | Wittelsbacher | Ackerland | 40 | Reichsburg, Mauer 2 | FRA, SWB, BAY, BOH |
| BAY | Bayern | Süd | Wittelsbacher | Ackerland | 60 | Stammburg Kelheim, Fluss (Donau) | SWB, NUE, BOH, OST, SAL, TIR |
| SAL | Salzburg | Süd | Kirche | Gebirge | 35 | Erzbistum, Salzhandel +20 T | BAY, OST, TIR |
| OST | Österreich | Süd | neutral | Ackerland | 60 | Herzog, Fluss (Donau) | BOH, BAY, SAL |
| TIR | Tirol | Süd | neutral | Gebirge | 25 | Pass (Brenner) | BRG, SWB, BAY, SAL |

Neutrale Provinzen und Wahlfürsten verteidigen sich mit ⌈Volk ÷ 20⌉ Rotten (Böhmen 8); Flüsse und Pässe erlauben Zollstationen. Die Nachbarschaft gilt immer in beide Richtungen.

### Gelände

| Gelände | Feldertrag (Scheffel je Volk und Jahr) | Schlachtfeld | Provinzen |
| --- | --- | --- | --- |
| Ackerland | 4,0 | Offenes Feld | 12 |
| Marsch | 3,5 | Sumpf | 2 |
| Hügelland | 3,0 | Anhöhe | 8 |
| Wald | 2,5 | Waldrand | 3 |
| Heide | 2,5 | Senken | 2 |
| Gebirge | 2,0 | Pass | 3 |
| Stadt | 1,0 | Vor den Toren | 1 |

## Wirtschaft

Die Wirtschaft kennt vier Ressourcen und zwei Hebel: Steuersatz und Ration. Wie bei Kaiser liegt die Spannung im Korn – geerntet wird nur im Herbst, gegessen jede Runde. Alle Werte sind Startwerte fürs Balancing.

| Ressource | Ebene | Bedeutung |
| --- | --- | --- |
| Taler (T) | Haus | Geld für Bauten, Truppen, Geschenke |
| Korn (Scheffel) | Haus | Vorrat; ernährt Volk und Truppen |
| Volk (V) | Provinz | 1 Volk = 100 Menschen; Basis für Steuer, Ernte, Rekruten |
| Zufriedenheit (Z) | Provinz | 0–100; steuert Steuereintreibung, Wachstum, Aufstände |
| Ansehen (A) | Haus | 0–100; Prestige für Fürstengunst, Heirat, Zufriedenheit |

**Hebel:** Steuersatz s ∈ {5, 10, 15, 20, 25, 30, 40} % für alle Provinzen; Ration r ∈ {2 Hunger, 3 Normal, 4 Üppig} Scheffel pro Volk und Jahr.

### Einnahmen pro Runde

```latex
\text{Steuer}_p = V_p \cdot s \cdot 3 \cdot \left(0{,}5 + \frac{Z_p}{200}\right)
```

```latex
\text{Markt}_p = V_p \cdot 0{,}3 \cdot m_p \cdot h \cdot f_{\text{Herbst}} \cdot \begin{cases} 1 & Z_p \ge 30 \\ 0{,}5 & Z_p < 30 \end{cases}
```

m = Marktstufe (0–2), h = 1,5 für Welfen sonst 1, f = 1,25 im Herbst sonst 1. Dazu feste Erträge: Bergwerk +30 T (Wettiner ×1,5), Zollstation +8 T an Flüssen und +15 T an Pässen, Salzhandel Salzburg +20 T.

**Unterhalt:** Summe aus Einheiten, Gebäuden und Burg (siehe Tabellen). Fällt der Talerstand unter 0, desertieren 10 % der Rotten jeder Armee (Söldner zuerst) und alle Provinzen verlieren 5 Zufriedenheit. Kredite gibt es nicht.

### Korn

```latex
\text{Ernte}_p = V_p \cdot F_p \cdot W_{\text{Region}} \cdot (1 + 0{,}25 \cdot \text{Mühle}_p) \cdot b_p
```

Nur im Herbst. F = Feldertrag nach Gelände (Tabelle im Abschnitt Reichskarte), b = 0,5 bei besetzter oder aufständischer Provinz. Das Wetter W wird je Region (Nord, Mitte, Süd) per Seed gezogen: 0,6 Missernte (10 %), 0,85 (20 %), 1,0 (40 %), 1,15 (20 %), 1,3 reiche Ernte (10 %).

```latex
\text{Bedarf} = \sum_p V_p \cdot \frac{r}{4} \; + \; \sum_{\text{Rotten}} k_u \cdot w
```

k = Korn-Unterhalt der Einheit, w = 1,5 im Winter außerhalb eigener Provinzen. Reicht das Korn nicht, gilt der Deckungsgrad D = Vorrat ÷ Bedarf (höchstens 1):

- Zufriedenheit jeder Provinz −30 × (1 − D)
- Volk jeder Provinz × (1 − 0,1 × (1 − D))
- Moral aller Rotten −20 × (1 − D), Ansehen −3

**Schwund** nach dem Verbrauch: Vorrat × (1 − q) mit q = max(0,02; 0,10 − 0,02 × Anzahl Kornspeicher).

### Kornmarkt

```latex
P_{\text{Herbst}} = 0{,}5 \cdot \frac{1}{\bar{W}} \cdot \varepsilon, \quad \varepsilon \sim U(0{,}9;\,1{,}1) \qquad P_t = P_{\text{Herbst}} \cdot (1 + 0{,}1 \cdot n)
```

P in Taler je Scheffel, W̄ = mittleres Wetter des Jahres, n = Runden seit dem Herbst. Kaufpreis = P × (1 + σ), Verkaufspreis = P × (1 − σ), σ = 0,2 (Welfen 0,1). Je 100 gekaufte Scheffel steigt P in dieser Runde um 2 %, je 100 verkaufte fällt er um 2 %; Grenzen 0,2 bis 2,0 Taler.

### Zufriedenheit und Aufstand

```latex
Z_p^{t+1} = Z_p + 0{,}25 \cdot (Z_p^{*} - Z_p)
```

```latex
Z_p^{*} = 60 - 1{,}5\,(s_{\%} - 10) + 10\,(r - 3) + 10 \cdot \text{Kloster}_p + 5 \cdot \text{Markt}_p + \frac{A}{10} + B_p - 15 \cdot \text{Besatzung}_p - 15 \cdot \text{Bann}
```

B = +5 je Burgstufe über 1 in der Stammprovinz; Besatzung = 1 für 4 Runden nach einer Eroberung; Ergebnis auf 0–100 begrenzt. Liegt Z am Rundenende unter 25, bricht mit (25 − Z) × 3 % Wahrscheinlichkeit ein Aufstand aus: keine Einnahmen, Rebellen mit ⌈V ÷ 15⌉ Rotten Aufgebot erscheinen. Ende durch Sieg oder Zugeständnis (2 Runden steuerfrei, +20 Z).

### Volk und Ansehen

Im Frühling (Volkszählung):

```latex
V_p^{t+1} = \min\!\left(K_p,\; V_p \cdot (1 + g_p)\right), \quad g_p = 0{,}03 \cdot \frac{Z_p - 40}{60} + 0{,}02\,(r - 3) + 0{,}01 \cdot \text{Kloster}_p - \text{Seuche}_p
```

Kapazität K = 1,5 × Startvolk + 5 × Burgstufe der Provinz + 10 × Marktstufe.

```latex
A^{t+1} = \min\!\left(100,\; 0{,}95 \cdot A + \Delta A\right)
```

ΔA = laufende Quellen (Burgstufe, Zierde, Klöster laut Gebäudetabelle) plus Einmalereignisse: Schlachtsieg +3, Turniersieg +5, Turnier ausgerichtet +5, Niederlage −3, Aufstand −2, Hunger −3, Überfall auf Kaufleute −3, Bündnisbruch −10, Bann −2 pro Runde. Durch den Verfall von 5 % pendelt sich Ansehen beim 20-Fachen der laufenden Quellen ein.

**Rekrutierung:** nur in Provinzen mit Burg; pro Jahr höchstens ⌊V ÷ 20⌋ Rotten je Provinz; jede Rotte kostet Volk (Einheitentabelle) und 2 Zufriedenheit.

### Steuersatz auf einen Blick

Gleichgewicht ohne Gebäude, Ration 3, Ansehen 20:

| Steuersatz | Ziel-Zufriedenheit | Steuer je 10 Volk | Volk pro Jahr | Folge |
| --- | --- | --- | --- | --- |
| 5 % | 70 | 1,3 T | +1,5 % | Wachstum, kaum Geld |
| 10 % | 62 | 2,4 T | +1,1 % | sicher |
| 15 % | 55 | 3,5 T | +0,7 % | Startwert, ausgewogen |
| 20 % | 47 | 4,4 T | +0,4 % | ertragreich, dünnes Polster |
| 25 % | 40 | 5,2 T | ±0 % | Stillstand |
| 30 % | 32 | 5,9 T | −0,4 % | Schrumpfen, Märkte gefährdet |
| 40 % | 17 | 7,0 T | −1,2 % | 24 % Aufstandsrisiko je Runde |

### Rechenbeispiel: Welfen im ersten Herbst

Braunschweig (V 60, Ackerland, Z 55, Mühle) und Holstein & Lübeck (V 45, Ackerland, Z 55, Markt 1), Steuersatz 15 %, Wetter 1,0:

1. Steuer Braunschweig: 60 × 0,15 × 3 × 0,775 = 20,9 → 21 T; Holstein: 15,7 → 16 T.
2. Markt Holstein: 45 × 0,3 × 1 × 1,5 × 1,25 = 25,3 → 25 T.
3. Unterhalt Startarmee: 2 × 1 T + 2 × 2 T = 6 T → Saldo +56 T.
4. Ernte Braunschweig: 60 × 4 × 1,0 × 1,25 = 300 Scheffel; Holstein: 45 × 4 = 180 Scheffel.
5. Jahresbedarf: (60 + 45) × 3 = 315 Scheffel Volk + 4 Rotten × 3 × 4 = 48 Scheffel Truppen = 363 Scheffel.
6. Überschuss 117 Scheffel, verkauft zu 0,5 × 0,9 = 0,45 T → rund 53 T. Bei einer Missernte (0,6) fehlen dagegen 75 Scheffel – genau die Kaiser-Spannung.

## Gebäude & Stammburg

Jede Provinz hat 2 Bauslots, die Stammprovinz 2 + 1 je Burgstufe über 1 (höchstens 6). Die Stammburg wächst in fünf sichtbaren Stufen von der Motte zur Kaiserpfalz; jede Stufe bringt Ansehen, Mauerschutz und Freischaltungen.

### Gebäude

| Gebäude | Kosten | Bauzeit (Runden) | Unterhalt / Runde | Wirkung | Voraussetzung |
| --- | --- | --- | --- | --- | --- |
| Mühle | 80 T | 1 | 2 T | Ernte der Provinz +25 % | – |
| Markt I | 100 T | 1 | 2 T | Marktertrag mit m = 1; Z\* +5 | – |
| Markt II | 250 T | 2 | 5 T | m = 2; Brabanzonen anwerbbar | Markt I, Stammburg 2 |
| Kornspeicher | 70 T | 1 | 1 T | Schwund −2 Prozentpunkte; Aushungern halbiert | – |
| Kloster | 150 T | 2 | 3 T | Z\* +10; Volk +1 %/Jahr; Ansehen +0,5; Seuchen halbiert | – |
| Bergwerk | 200 T | 2 | 5 T | +30 T je Runde | Erz in der Provinz |
| Zollstation | 60 T | 1 | 1 T | +8 T (Fluss) oder +15 T (Pass) | Fluss oder Pass |
| Turnierplatz | 120 T | 1 | 2 T | Turnier ausrichten: 80 T, Ansehen +5, Gunst +3 bei allen Wahlfürsten | Stammprovinz, Burg 3 |
| Bauhütte | 150 T | 2 | 3 T | Bliden baubar; Burgausbau −15 % | Stammprovinz, Burg 4 |

### Stammburg

| Stufe | Name | Kosten | Bauzeit | Unterhalt | Mauer | Ansehen / Runde | Schaltet frei |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Motte (Turmhügelburg) | Start | – | 0 T | 1 | +0,5 | Aufgebot, Spießträger |
| 2 | Steinerner Bergfried | 300 T | 2 | 5 T | 2 | +1 | Armbrustschützen, Markt II |
| 3 | Ringmauer & Torhaus | 600 T | 3 | 10 T | 3 | +1,5 | Ritter, Turnierplatz, nachgemachte Insignien |
| 4 | Palas & Kapelle | 1000 T | 3 | 15 T | 3 | +2,5 | Bauhütte, zweite Heiratskarte, Bann-Dauer halbiert |
| 5 | Kaiserpfalz | 1800 T | 4 | 25 T | 4 | +4 | Gunst +1 je Runde bei allen Wahlfürsten |

Optisch tauscht jede Stufe Bausatzteile aus; um die Burg wächst eine Siedlung, deren Häuserzahl dem Volk der Stammprovinz folgt. Der Ausbau läuft als Zeitraffer, während die Runde weitergeht.

### Zierde

Höchstens 5 Zierden je Stammburg, jede sichtbar in der Burgansicht.

| Zierde | Kosten | Wirkung |
| --- | --- | --- |
| Banner und Wimpel | 50 T | Ansehen +0,2 je Runde |
| Brunnen | 100 T | Z\* der Stammprovinz +3 |
| Rosengarten | 120 T | Ansehen +0,4 je Runde |
| Wandteppiche | 150 T | Ansehen +0,5 je Runde |
| Bleiglasfenster | 200 T | Ansehen +0,6 je Runde; ab Stufe 4 |

### Provinzburgen

| Stufe | Name | Kosten | Bauzeit | Unterhalt | Mauer | Garnison |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | offen | – | – | – | 0 | keine; keine Rekrutierung |
| 1 | Holzburg | 80 T | 1 | 2 T | 1 | 1 Rotte Aufgebot ohne Unterhalt |
| 2 | Steinburg | 250 T | 2 | 5 T | 2 | 2 Rotten |
| 3 | Festung | 500 T | 3 | 10 T | 3 | 3 Rotten; nur ab Stammburg 3 |

**Mauerwerte:** Mauer-Lebenspunkte = 400 × Stufe; Verteidiger erhalten Rüstung + Stufe. Beim Aushungern verliert die Garnison 15 % je Runde (mit Kornspeicher 7,5 %). Aachen und Burg Trifels starten mit Mauer 3, Nürnberg mit Mauer 2.

## Militär & Einheiten

Sechs Einheitentypen plus der Anführer, verbunden durch ein klares Schere-Stein-Papier: Spieß schlägt Ritter, Ritter schlagen Schützen, Schützen schlagen Spieß. Eine Rotte sind 30 Mann, dargestellt mit 12 Figuren.

### Kosten & Rolle

| Einheit | Kosten | Volk | Unterhalt (T / Korn) | Ab | Auto-Resolve-Wert | Rolle |
| --- | --- | --- | --- | --- | --- | --- |
| Aufgebot | 20 T | 0,5 | 1 / 3 | Burg 1 | 1 | Masse, Garnison |
| Spießträger | 40 T | 0,5 | 2 / 3 | Burg 1 | 2 | Reiterabwehr, Linie halten |
| Armbrustschützen | 50 T | 0,5 | 3 / 3 | Burg 2 | 2 | Fernkampf, Rüstung knacken |
| Ritter | 120 T (Staufer 90) | 0,3 | 8 / 6 | Burg 3 | 4 | Ansturm, Flanken |
| Brabanzonen | 90 T | – | 10 / 3 | Markt II oder Gönner | 3 | Söldner ohne Volksverlust |
| Blide | 150 T | 0,2 | 6 / 2 | Bauhütte | 1 | Belagerung, Flächenschaden |
| Anführer | – | – | – | 1 je Haus | 2 | Held, Moral-Aura |

### Kampfwerte

| Einheit | LP | Nahkampf / s | Fernkampf | Rüstung | Tempo (m/s) | Moral | Stark gegen | Schwach gegen |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Aufgebot | 300 | 6 | – | 1 | 2,0 | 40 | – | alle |
| Spießträger | 400 | 8, ×2,5 gegen Reiter | – | 3 | 1,8 | 60 | Ritter von vorn | Armbrust |
| Armbrustschützen | 250 | 4 | 14 je Schuss, 90 m, 4 s Nachladen, halbiert Rüstung | 1 | 1,8 | 50 | Spieß, Ritter auf Distanz | Ritter im Nahkampf |
| Ritter | 500 | 14, ×2 im Ansturm ab 5 m/s | – | 6 | 6,0 (Ansturm 8,0) | 80 | Schützen, Aufgebot | Spieß von vorn |
| Brabanzonen | 400 | 12 | – | 4 | 2,2 | 55 (−20 bei Soldverzug) | Aufgebot, Spieß | Ritter |
| Blide | 200 | – | 60 Fläche r 6 m, 250 m, 20 s Nachladen, ×4 gegen Mauern | 2 | 0,6 (aufgebaut 0) | 30 | Mauern, dichte Gruppen | alles im Nahkampf |
| Anführer | 300 | 16 | – | 7 | 6,0 | – | Aura +15 Moral im Umkreis 30 m | bei LP 0 gefangen |

Schaden je Treffer = Angriffswert − Rüstung, mindestens 1.

### Armeen auf der Karte

- **Größe:** mit Anführer bis 6 + Führung Rotten, unter einem Hauptmann bis 6.
- **Anzahl:** 1 + ⌊Stammburgstufe ÷ 2⌋ Armeen je Haus.
- **Bewegung:** eine Nachbarprovinz je Runde, im Sommer zwei, wenn die erste eigene ist.
- **Rückzug:** Der Verlierer weicht in eine eigene Nachbarprovinz aus. Gibt es keine, löst sich die Armee auf und ein Anführer gerät in Gefangenschaft.
- **Erholung:** +25 % LP je Runde in eigener Provinz, +10 % in fremder. Rotten unter 20 % LP lösen sich auf.

### Auto-Resolve

Jede Schlacht kann ausgewürfelt werden; KI gegen KI läuft immer so.

```latex
K = \Big(\sum_{\text{Rotten}} w_u \cdot \frac{LP}{LP_{\max}}\Big) \cdot (1 + 0{,}05 \cdot \text{Führung}) \cdot \Big(0{,}5 + \frac{\text{Moral}}{200}\Big) \cdot G \cdot R
```

```latex
P(\text{Sieg}_A) = \frac{K_A^{1{,}5}}{K_A^{1{,}5} + K_B^{1{,}5}}
```

- w = Auto-Resolve-Wert der Einheit; Moral = Durchschnitt der Armee.
- G = Gelände: Verteidiger auf Hügelland 1,15; in einer Burg 1 + 0,25 × Mauerstufe; sonst 1.
- R = Konterbonus: +10 % je Paarung im Vorteil (etwa Spieß gegen Ritter), höchstens +30 %.
- Der Spieler rechnet mit −10 %, damit sich Selberspielen lohnt.
- Verluste: Verlierer 40–70 % seiner LP, Sieger 30 % × K\_B ÷ K\_A (mindestens 5 %), verteilt über alle Rotten.

## Schlacht-Modul

Schlachten laufen in Echtzeit auf einem 3D-Schlachtfeld aus der schrägen Vogelperspektive: eine sonnige, stilisierte Landschaft mit Nadelbäumen, Büschen, Felsen und Lichtungen, darauf kleine Trupps aus Ritterfiguren, jede mit einem Ring in Hausfarbe am Boden. Am unteren Bildrand zeigt jede Seite ihre Truppengattungen als Wappenschilde. Eine Schlacht dauert 2–4 Minuten.

### Kamera und Schlachtfeld

- **Kamera:** schräg von oben, rund 60° geneigt, mit Blick über das ganze Gefecht; folgt dem Geschehen, zwei Zoomstufen, nicht drehbar.
- **Feld:** rund 300 × 180 m, in alle Richtungen frei begehbar. Der Angreifer startet links, der Verteidiger rechts.
- **Gelände:** kommt aus der Provinz (Tabelle unten). Bäume und Felsen sind Hindernisse und Deckung; Flüsse, Hügel und Sümpfe verändern Tempo und Reichweite.
- **Licht nach Jahreszeit:** Sommer warm und sonnig mit langen Schatten, Herbst golden, Winter verschneit, Frühling saftig grün.

### Truppen und Anzeige

- Jede Rotte steht als Trupp aus 6–12 Figuren in Formation. Unter jeder Figur liegt ein Ring in Hausfarbe, damit Freund und Feind auf einen Blick zu unterscheiden sind.
- Die Rotten einer Armee bilden bis zu vier Befehlsgruppen: **Fußvolk** (Aufgebot, Spießträger, Brabanzonen), **Schützen** (Armbrust), **Reiterei** (Ritter und Anführer) und **Gerät** (Bliden).
- Unten links stehen die Wappenschilde der eigenen Gruppen, unten rechts die des Gegners. Jeder Schild zeigt ein Symbol (Spieß, Armbrust, Pferdekopf, Blide), die Zahl der Rotten (×2) und bei Schützen drei Bolzen-Marken für die Salven bis zum Nachladen. Die aktive Gruppe leuchtet golden.

### Steuerung

Der Spieler steuert immer eine Gruppe direkt; die anderen halten ihre Position und wehren sich selbst.

| Aktion | Controller | Maus und Tastatur |
| --- | --- | --- |
| Gruppe wechseln | LT / RT | Q / E oder 1–4 |
| Bewegen | linker Stick | WASD oder Rechtsklick ins Gelände |
| Angriff | A | Leertaste oder Rechtsklick auf einen Gegner |
| Formation wechseln | B | F |
| Sammeln (Anführer) | Y | R |
| Zoom | rechter Stick | Mausrad |

**Angriff je Gruppe:** Fußvolk stürmt auf den nächsten Gegner in Blickrichtung. Schützen feuern eine Salve auf das Ziel im Zielkegel. Reiterei reitet einen Ansturm in gerader Linie, der erst nach 30 m Anlauf volle Wucht hat. Bliden zeigen einen Zielkreis, den der Spieler verschiebt.

### Formationen

| Gruppe | Formation 1 | Formation 2 |
| --- | --- | --- |
| Fußvolk | Linie: breite Front, normales Tempo | Igel: Spieße nach außen, steht still, doppelter Schutz gegen Reiter |
| Schützen | Linie: volle Salve, langes Nachladen | Gestaffelt: halbe Salve, dafür ununterbrochenes Feuer |
| Reiterei | Keil: Ansturm mit doppelter Wucht | Linie: breiter, schwerer zu flankieren, weniger Wucht |
| Gerät | aufgebaut: schießt, steht | abgebaut: fährt, schießt nicht |

### Moral und Sieg

- Start = Einheitenmoral + 5 × Führung des Anführers.
- −1 je 2 % LP-Verlust des Trupps; Angriff in Flanke oder Rücken −15 sofort; Anführer gefangen −20 für alle.
- Unter 20 flieht der Trupp zum eigenen Rand. „Sammeln“ holt fliehende Trupps im Umkreis von 30 m zurück, Abklingzeit 45 s.
- Sieg, wenn der Gegner flieht oder vernichtet ist. Nach 4 Minuten gewinnt die höhere Restkampfkraft (Auto-Resolve-Formel ohne Zufall); der Verlierer zieht ab.

### Gelände

| Provinzgelände | Schlachtfeld | Wirkung |
| --- | --- | --- |
| Ackerland | Wiese mit einzelnen Baumgruppen und Felsen | keine; ideal für Ritter |
| Hügelland | Anhöhe in der Feldmitte | oben: Fernkampf-Reichweite +15 %; Ansturm bergauf −30 % Tempo |
| Wald | Waldgürtel mit Schneisen | im Wald: Ritter −50 % Tempo, Schützen erleiden −30 % Schaden |
| Heide | Senken und Gestrüpp | Fernkampf-Reichweite −20 % |
| Marsch | Sumpfflächen und Priele | im Sumpf −40 % Tempo |
| Gebirge | Pass zwischen Felswänden | Engstelle in der Mitte, keine Umgehung |
| Stadt | vor den Toren | Mauer des Verteidigers am rechten Rand |
| Fluss (Merkmal) | Furt oder Brücke quer übers Feld | Furt −50 % Tempo; Brücke als einziger Übergang |

### Inszenierung

- Große Rufe in verspielter Schrift mitten im Bild: „Zum Angriff!“ beim Ansturm, „Haltet die Linie!“ beim Igel, „Rückzug!“ bei Flucht; dazu die Schlachtrufe der Häuser.
- 0,5 s Zeitlupe beim Aufprall eines Ansturms; Staubwolken, fliegende Helme, Figuren purzeln comichaft – kein Blut.
- Am Ende ein Buchmalerei-Banner mit Sieger, Verlusten, Gefangenen und Ansehen.

**Couch-Duell:** zwei Spieler an einem Bildschirm, jeder mit Controller und seiner Schildleiste – links der eine, rechts der andere.

**Größe:** bis rund 400 Figuren gleichzeitig auf dem Feld.

## Abenteuer-Module

Vier Minispiele bringen das Defender-of-the-Crown-Gefühl: Tjost, Belagerung, Burgüberfall und Kaufmannszug. Jedes dauert 1–3 Minuten, folgt der Säule „Können statt Würfel“ und hat einen Übungsmodus im Hauptmenü.

### Tjost

- **Auslöser:** selbst ausgerichtetes Turnier (Turnierplatz), Einladung per Ereignis, oder Lehenstjost gegen ein Nachbarhaus um eine Grenzprovinz (beide müssen zustimmen).
- **Ablauf:** 3 Durchgänge aus der Ego-Sicht durch den Helmschlitz.
  1. Anritt (3 s): Sporen im Takt geben Tempo; zu schnell lässt die Lanze stärker schwanken.
  2. Zielen (1,5 s): Lanzenspitze per Maus oder Stick auf den Gegner – Schildmitte 3 Punkte, Schildrand 1, Helm 5.
  3. Aufprall: Taste im Zeitfenster ±(60 + 15 × Lanze) ms drücken. Perfekt: Lanze bricht (+1 Punkt), Gegner-Haltung −40; normal −20.
- **Haltung:** Jeder Reiter hat 100 Haltung; unter 0 fällt er aus dem Sattel und verliert sofort. Schild ausrichten (zweiter Stick) halbiert den erlittenen Treffer.
- **Kein Zufall:** Die Lanze schwankt in einem sichtbaren, festen Muster aus dem Pferdetritt; die KI hat feste Fehlermuster je Schwierigkeit.
- **Lohn:** Turniersieg Ansehen +5, Preisgeld 100 T, Gunst +5 beim gastgebenden Fürsten; Lehenstjost: die Provinz wechselt den Besitzer (Z −10).

### Belagerung

Zieht eine Armee in eine Provinz mit Burg und ohne feindliche Armee, wählt sie eine von drei Optionen:

- **Aushungern:** Die Garnison verliert 15 % LP je Runde (mit Kornspeicher 7,5 %); der Angreifer zahlt Unterhalt ×1,25.
- **Blide:** das Minispiel, braucht mindestens eine Blide.
- **Sturm:** eine Schlacht vor der Mauer; die Mauer sperrt den Zugang, nur Tor oder Bresche führen hinein, Verteidiger erhalten Rüstung + Mauerstufe.

**Blide-Minispiel:** Seitenansicht auf eine Burg aus Bausatzteilen, die Mauer-LP verteilt auf die Teile. Der Spieler stellt Gegengewicht und Abwurfwinkel ein, sieht Wind und die ersten 20 % der Flugbahn. Schüsse = 3 + 2 × Bliden; ab Mauer 3 kostet Gegenfeuer jeden dritten Schuss.

| Geschoss | Wirkung |
| --- | --- |
| Stein | 240 Schaden am getroffenen Teil; Teile stürzen physikalisch und treffen Nachbarteile |
| Brandtopf | Garnison −8 % LP je Treffer; Holzteile brennen ab |

Fällt ein Mauer- oder Torsegment auf 0, entsteht eine Bresche: Der Sturm folgt sofort, ohne Mauerbonus an dieser Stelle. Ohne Bresche geht die Belagerung in der nächsten Runde weiter. Eine eroberte Burg verliert eine Stufe, die Provinz steht 4 Runden unter Besatzung.

### Burgüberfall

- **Auslöser:** Anführer in oder neben einer feindlichen Burg; höchstens einer je Runde.
- **Ziele:** Schatzkammer (20 % der gegnerischen Taler, höchstens 200), Kerker (Gefangene oder Geiseln befreien), Kornspeicher anzünden (gegnerisches Korn −30 %), Reichsinsignien (nur wo die echten liegen).
- **Steuerung:** Seitenansicht bei Fackellicht, der Anführer allein gegen 3–6 Wachen nacheinander. Hiebe oben, Mitte, unten; Parieren in passender Höhe im Fenster 150 + 20 × Klinge ms; Ausdauerbalken; Schleichwege sparen Kämpfe, kosten Zeit.
- **Zeitdruck:** 120 s; nach 60 s schlägt Alarm und Verstärkung rückt an.
- **Ausgang:** Erfolg Ansehen +3 (Insignien +10). Scheitern: Gefangenschaft oder Flucht mit Wunde (nächste Runde keine Aura). Ein Überfall auf Kirchenland riskiert zu 25 % den Bann.

### Kaufmannszug

- **Auslöser:** Ereignis in einer Provinz mit Fluss; Wahl zwischen Geleitschutz (+20 T, Ansehen +2, Gunst der Handelsstädte +5) und Überfall.
- **Überfall:** seitlich scrollend wie der Zugüberfall bei North & South. Anführer plus bis zu 2 Rotten müssen 5 Wagen stoppen, bevor sie nach 90 s das Stadttor erreichen – Kutscher vom Bock holen oder Zugpferde mit der Armbrust treffen; 2–4 Geleitsoldaten wehren sich.
- **Lohn und Preis:** 30–40 T je Wagen; Ansehen −3; Gunst Kölns −10.
- **Scope:** erster Streichkandidat, falls die Zeit knapp wird.

## Wahlfürsten, Diplomatie & Heiratspolitik

Sieben Wahlfürsten vergeben die Stimmen; jeder führt eine Gunstliste von 0 bis 100 je Haus. Er stimmt für das Haus mit der höchsten Gunst, wenn sie mindestens 60 beträgt; bei Gleichstand enthält er sich.

| Wahlfürst | Provinz | Kirche | Startgunst | Eigenheit |
| --- | --- | --- | --- | --- |
| Erzbischof von Köln | Köln | ja | Welfen 55, sonst 30 | krönt in Aachen |
| Erzbischof von Mainz | Mainz | ja | Staufer 45, sonst 30 | krönt bei Notkrönung |
| Erzbischof von Trier | Trier | ja | alle 30 | Zünglein an der Waage |
| Pfalzgraf bei Rhein | Pfalz am Rhein | nein | Welfen 40, Staufer 40, sonst 30 | Nachbar von Trifels |
| Herzog von Sachsen | Sachsen-Wittenberg | nein | Wettiner 45, sonst 30 | – |
| Markgraf von Brandenburg | Brandenburg | nein | Welfen 40, Wettiner 35, sonst 30 | – |
| König von Böhmen | Böhmen | nein | Wettiner 40, Wittelsbacher 40, sonst 30 | Ereignis „Böhmische Königswürde“ |

### Gunst gewinnen und verlieren

| Anlass | Änderung | Kosten oder Bedingung |
| --- | --- | --- |
| Jede Runde | + Ansehen ÷ 50, danach 1 Punkt Richtung 30 | – |
| Geschenk | +5 (Wittelsbacher +7,5) | 50 T; jedes weitere im selben Jahr beim selben Fürsten wirkt 1 Punkt schwächer |
| Gesandtschaft | +15 | eine Gönner-Karte |
| Turnier ausgerichtet | +3 bei allen | Turnierplatz, 80 T |
| Turniersieg bei ihm | +5 | – |
| Heirat in sein Haus | +25 einmalig | eine Heiratskarte |
| Schutz | +10 | feindliche Armee in seiner Nachbarprovinz geschlagen |
| Kaiserpfalz | +1 je Runde | Stammburg 5 |
| Krieg gegen ihn | −20 | – |
| Besetzung seiner Provinz | Stimme zählt erzwungen für den Besatzer; −10 bei allen übrigen Wahlfürsten; Ansehen −5 | bei Kirchenland 50 % Bann |

**Huldigung:** Auch die neutralen weltlichen Provinzen (etwa Brabant, Elsass, Österreich, Aachen) führen Gunstlisten mit Startwert 30 (Elsass für Staufer 50). Ab Gunst 80 bieten sie die Huldigung an und schließen sich für 100 T ohne Kampf an. Wahlfürsten- und Kirchenprovinzen huldigen nie.

### Kirchenbann

- **Auslöser:** Angriff auf eine Kirchenprovinz (Köln, Mainz, Trier, Bremen, Magdeburg, Münster, Osnabrück, Franken, Salzburg) zu 50 %; Überfall auf Kirchenland zu 25 %; Ereignis „Papstlegat“.
- **Wirkung:** Z\* −15 in allen Provinzen; Kirchen-Wahlfürsten stimmen nicht für das Haus; Ansehen −2 je Runde.
- **Ende:** Bußgang – 150 T, 10 Ansehen und eine Runde ohne Feldzug (mit Kapelle die Hälfte der Taler).

### Diplomatie zwischen Häusern

- **Zustände:** Krieg, Waffenstillstand (4 Runden), Frieden, Bündnis.
- **Bündnis:** geteilte Sicht, Durchzugsrecht, Armeen in derselben Provinz kämpfen gemeinsam. Bruch kostet 10 Ansehen, außer nach Ende des Burgfriedens.
- **Verträge** am Hoftag im Winter: Taler gegen Korn, Provinztausch, Lösegeld, Waffenstillstand. Die KI bewertet jeden Vorschlag nach Nutzen.

**Friedenskongress zu Münster und Osnabrück:** Die beiden Fürstbistümer führen Gunstlisten wie die Wahlfürsten. Wer eines von ihnen kontrolliert oder dort Gunst 60 hat, kann am Hoftag einen Kongress einberufen: Zwei verfeindete Häuser schließen 8 Runden Waffenstillstand, der Gastgeber erhält Ansehen +5 und +5 Gunst bei allen Wahlfürsten – ein Augenzwinkern zum Westfälischen Frieden von 1648. Zugleich liegen beide auf dem Weg der Welfen zum Rhein: Wer sie erobert statt umwirbt, riskiert den Bann.

### Heiratspolitik

Hochzeiten ersetzen die Prinzessinnenrettung des Vorbilds; Erbinnen und Erben sind gleichwertig spielbar.

- **Partner:** Wahlfürsten, neutrale Herzöge (Brabant, Österreich, Lothringen, Zähringer) oder andere Spielerhäuser.
- **Annahme durch die KI:** 30 % + Ansehen ÷ 2 + 5 × Burgstufe, −20 % bei Krieg mit einem Verbündeten des Partners.
- **Wirkung:** Wahlfürst +25 Gunst; neutraler Herzog Bündnis und Mitgift 100–300 T plus Erbanspruch (stirbt seine Linie, 5 % je Jahr, fällt die Provinz ans Haus); Spielerhaus: Bündnis für 8 Runden unbrechbar, Mitgift verhandelbar.
- **Inszenierung:** Hochzeitsfest als Story-Tafel.

## Ereignisse

Jedes Haus zieht pro Runde eine Karte aus einem nach Jahreszeit gefilterten, gewichteten Stapel; historische Ereignisse lösen zu festen Daten aus. Alle Ereignisse liegen als Daten vor (Bedingung, Gewicht, Wirkungen, Wahlmöglichkeiten), damit Designer ohne Code neue schreiben können.

| Ereignis | Wann | Wirkung | Wahl |
| --- | --- | --- | --- |
| Rattenplage | Herbst, Winter | Korn −20 % (mit Kornspeicher −10 %) | – |
| Missernte / reiche Ernte | Herbst, aus dem Wetterzug | Wetter 0,6 bzw. 1,3 in der Region | – |
| Seuche | 4 % je Provinz und Jahr | Volk −10 % in Provinz und Nachbarn, Z −10; Kloster halbiert | – |
| Strenger Winter | Winter | Kornbedarf +25 % | – |
| Hochwasser | Frühling, Flussprovinzen | kein Durchzug für 1 Runde; Ernte dort −20 % | – |
| Gaukler am Hof | jederzeit | Z der Stammprovinz +3 für 20 T | annehmen / ablehnen |
| Sängerkrieg auf der Wartburg | Sommer, Besitzer Thüringens | Ansehen +8 für 100 T | ausrichten / nicht |
| Raubritter | jederzeit | Haufen aus 3 Rotten Aufgebot nebenan; Sieg: Ansehen +3, 50 T | jagen / ignorieren (Z −5 in der Nachbarprovinz) |
| Kaufmannszug | Frühling, Sommer | Abenteuer Kaufmannszug | Geleit / Überfall |
| Turniereinladung | Frühling, Sommer | Tjost bei einem Wahlfürsten | teilnehmen / absagen |
| Fehdebrief | jederzeit | neutraler Graf greift mit 4 Rotten an | kämpfen / 80 T Sühne |
| Heiratsangebot | Winter | neutraler Herzog bietet eine Heirat an | annehmen / ablehnen |
| Geiselnahme | jederzeit | Verwandter in einer feindlichen Burg | Burgüberfall / 120 T Lösegeld / Ansehen −5 |
| Böhmische Königswürde | einmalig, sobald Böhmens Gunst 50 erreicht | Zusage der erblichen Königswürde: Stimme sicher, Ansehen −10 | zusagen / ablehnen |
| Der Zähringer verkauft seine Kandidatur | einmalig, Jahr 1–3 | Breisgau huldigt für 400 T | kaufen / ablehnen |
| Papstlegat | jeder Winter | Haus mit der höchsten Kirchengunst +10 bei Kirchen-Wahlfürsten; Haus mit der niedrigsten 25 % Bann | – |
| Kreuzzugsaufruf | einmalig, ab Jahr 4 | 2 Rotten Ritter für 8 Runden entsenden: Ansehen +10, Kirchengunst +10 | entsenden / nicht |
| Tod des Löwenherz | fest: Frühling, Jahr 2 | englische Gönner-Karten wirken nur noch zu 75 % | – |

## KI-Gegner & Multiplayer

Die KI ist eine Utility-KI mit vier Persönlichkeiten, die dieselben Regeln und denselben Nebel wie Menschen nutzt. Multiplayer startet als Hot-Seat und Couch-Duell; online kommt zunächst über Steam Remote Play Together, ohne eigenen Netzcode.

### Entscheidungsebenen der KI (jede Runde, in dieser Reihenfolge)

1. **Versorgung:** Kornprognose bis zur nächsten Ernte; bei Defizit kaufen oder Ration senken, bei Talernot Steuer anheben, solange Z\* über 35 bleibt.
2. **Sicherheit:** Bedrohungskarte aus feindlicher Kampfkraft in Nachbarprovinzen gegen eigene Garnisonen; bedrohte Stammprovinz hat Vorrang.
3. **Ziele:** Für jede der drei Säulen wird der günstigste nächste Schritt bewertet – Nutzen = Legitimitätsgewinn ÷ Kosten in Talern und Runden.
4. **Gelegenheit:** Angriff bei Kampfkraftverhältnis ab 1,4 inklusive Konterbonus; Belagerung, wenn Bliden da sind; Geschenk an den Wahlfürsten, der der Schwelle 60 am nächsten ist.

| Persönlichkeit | Standard für | Gewichtung |
| --- | --- | --- |
| Kaufmann | Welfen | Märkte, Kornhandel, Frieden |
| Baumeister | Wettiner | Burgausbau, Ansehen, Klöster |
| Eroberer | Staufer | Armeen, Belagerungen, Lehenstjost |
| Diplomat | Wittelsbacher | Geschenke, Heiraten, Huldigungen |

**Anti-Führer-Logik:** Hält ein Haus zwei Säulen, bewerten alle anderen Angriffe auf es höher. Das hält jede Partie bis zum Ende offen.

| Schwierigkeit | Einnahmen | Verhalten |
| --- | --- | --- |
| Knappe | −20 % | 30 % der Entscheidungen bewusst suboptimal |
| Ritter | normal | Standard |
| Fürst | +15 % | bessere Zielwahl, nutzt Konter konsequent |
| Kaiser | +30 % | bildet aktiv Koalitionen gegen den Führenden |

In Minispielen steuern Reaktionszeit und feste Fehlermuster die Schwierigkeit. Ein Debug-Overlay zeigt alle Nutzenwerte – Pflichtwerkzeug fürs Balancing.

### Multiplayer

- **Hot-Seat (2–4):** Züge nacheinander mit Übergabebildschirm, der fremde Informationen verdeckt. Treffen zwei menschliche Armeen aufeinander: Couch-Duell oder Auto-Resolve.
- **Couch-Duell:** auch als Schnellschlacht im Hauptmenü mit frei gewählten Armeen und Gelände.
- **Team-Variante 2 gegen 2:** Burgfrieden bleibt bestehen, das Lager gewinnt gemeinsam.
- **Online v1.0:** Steam Remote Play Together, also lokaler Multiplayer über das Netz.
- **Online nach Launch:** asynchrone Partien, bei denen die Spieler ihre Züge nacheinander abschicken.

## UI/UX & Onboarding

Jede Zahl erklärt sich selbst, und der Wettlauf um die drei Säulen ist immer sichtbar. Ein spielbarer Prolog von rund 20 Minuten ersetzt das fehlende Tutorial, an dem das Remake gescheitert ist.

**Prolog „Der Kaiser ist tot“** (4 Runden, überspringbar), lehrt in dieser Reihenfolge:

1. Steuersatz und Ration, dazu die Kornprognose
2. Ein Bauauftrag (Mühle) und der Burgausbau auf Stufe 2
3. Ein Feldzug mit einer leichten, geführten Schlacht
4. Ein Übungs-Tjost
5. Ein Geschenk an einen Wahlfürsten und die Krönungsregel

**HUD und Ansichten**

- **Säulenleiste** oben: für jedes Haus Insignien, Krönungsort und Stimmen x von 7.
- **Kornvogt:** Vorrat gegen Bedarf bis zur nächsten Ernte, dauerhaft sichtbar, mit Warnung zwei Runden vor dem Hunger.
- **Rechen-Tooltips:** Jeder Wert zeigt auf Hover oder Halten seine Rechnung, etwa „Steuer 21 = 60 × 15 % × 3 × 0,775“.
- **Berater:** Kämmerer (Taler, Korn), Marschall (Militär), Kanzler (Gunst), Baumeister (Burg) geben je höchstens einen Hinweis pro Runde.
- **Kartenmodi:** Besitz, Gunst, Ertrag, Kampfkraft, Zufriedenheit.
- **Chronik:** Zu Rundenbeginn fasst eine Pergamentseite die Änderungen zusammen; am Partieende entsteht eine illustrierte Chronik-Rolle, als Bild teilbar.

**Steuerung:** Controller ab Tag 1 (Steam Deck) mit Radialmenüs für Provinzaktionen; Maus und Tastatur gleichwertig; Schaltflächen mindestens 44 px für spätere Handheld- und Touch-Versionen.

**Barrierefreiheit:** Hausfarben zusätzlich mit Wappenmustern (farbenblind-sicher), skalierbarer Text, freie Tastenbelegung, Minispiel-Hilfen (breiteres Zeitfenster, Zeitlupe), Untertitel, keine Blitzeffekte über 3 pro Sekunde.

**Lesbarkeit:** Überschriften in einer Textura-Zierschrift, Fließtext in gut lesbarer Antiqua, keine Fraktur im Fließtext.

**Komfort:** Autosave jede Runde plus 3 manuelle Slots; „Weiterspielen“ im Hauptmenü. Sprachen zum Launch Deutsch und Englisch, Layouts mit 30 % Platzreserve für längere Übersetzungen.

## Art Direction & Audio

Leitbild: „Codex Manesse wird lebendig“ – stilisiertes Low-Poly-3D mit der Anmutung mittelalterlicher Buchmalerei. Jeder Screenshot soll ohne Logo als dieses Spiel erkennbar sein.

**Bildregeln**

- **Farbe:** Heraldische Tinkturen (Gold, Silber, Rot, Blau, Grün, Schwarz, Purpur) tragen Bedeutung – Häuser, Banner, UI. Gelände in gedämpften Erdtönen. Eine Palettentextur mit höchstens 12 Grundfarben.
- **Shading:** Toon-Shader mit 2–3 Lichtstufen; Tuschekonturen (Inverted Hull für Figuren, Kantenerkennung als Post-Effekt für die Umgebung); Pergamentkörnung und leichte Vignette; Blattgold-Glanz auf Kronen, Bannern und UI-Rahmen.
- **Figuren:** gedrungene Proportionen (Kopf zu Körper 1 : 5) und übergroße Helmzier je Haus wie im Codex Manesse – so bleiben Rotten aus der Entfernung lesbar. Budget 1.500–3.000 Dreiecke je Soldat, 6.000 je Held.
- **Animation:** knackig und leicht überzeichnet; Comic-Ausfälle statt Blut.

| Ansicht | Kamera und Stimmung |
| --- | --- |
| Reichskarte | Kriegstisch-Diorama im Kerzenlicht, geneigte Draufsicht, Armeen als bemalte Holzfiguren |
| Stammburg | Orbit-Kamera, Ausbau als Zeitraffer, Siedlung wächst mit |
| Schlacht | schräg von oben (rund 60°), stilisierte Landschaft mit Bäumen, Felsen und Lichtungen, Licht nach Jahreszeit |
| Tjost | Ego-Sicht mit Helmschlitz-Vignette, Publikum auf Tribünen |
| Burgüberfall | Seitenansicht bei Fackellicht |
| Belagerung | seitlich von der Blide aus, Burg im Bausatz |
| Story-Tafeln | rund 25 gemalte Buchmalerei-Tafeln mit Initialen und Textrahmen |

### Figuren aus Blender

Alle Figuren entstehen in Blender im selben Stil: stilisiertes Low-Poly, gedrungen, große Köpfe und übergroße Helmzier, klare Silhouetten, die auch aus der Vogelperspektive bei rund 30 Pixeln Höhe lesbar bleiben. Waffenröcke, Schilde und Schabracken tragen die Hausfarben.

| Figur | Aussehen | Bewegung |
| --- | --- | --- |
| Aufgebot | Bauern in Kittel und Gugel, mit Knüppel, Dreschflegel oder Sense, ohne Helm | trottet, schlägt wild um sich |
| Spießträger | gepolsterter Waffenrock, Eisenhut, langer Spieß, kleiner Rundschild mit Wappen | marschiert im Gleichschritt, senkt die Spieße |
| Armbrustschütze | Gambeson, Kettenhaube, Armbrust, großer Setzschild in Hausfarben auf dem Rücken | kniet zum Schuss, spannt mit dem Fuß im Bügel |
| Ritter | Kettenpanzer, Waffenrock und Dreiecksschild mit Wappen, Topfhelm mit Helmzier, Lanze und Schwert; Pferd mit Schabracke in Hausfarben | Trab, Galopp, Ansturm mit gesenkter Lanze |
| Brabanzone | zusammengewürfelte Rüstung, Streitaxt, graubraun ohne Hausfarben | breitbeinig, prügelnd |
| Blide | Holzgerüst mit Gegengewicht und Schlinge, vier Mann Bedienung | Mannschaft zieht, der Arm schwingt, der Stein fliegt |
| Anführer | wie ein Ritter, dazu Mantel, Goldreif auf dem Helm und eigenes Banner | wie Ritter; reckt beim Sammeln das Schwert |

**Helmzier je Haus** (spielerisch, für die Lesbarkeit): Welfen ein goldener Löwe, Staufer ein schwarzer Adler, Wettiner ein Hirschgeweih, Wittelsbacher blaue Flügel. Kirchentruppen tragen Weiß und Violett mit Kreuzbanner, neutrale Herren Erdtöne mit eigenem Wappen.

**Story-Tafeln und Konzeptkunst:** KI-gestützt mit einer eigenen Style-LoRA, trainiert auf gemeinfreien Buchmalereien, danach von Hand übermalt. Trainingsquellen und KI-Anteile werden dokumentiert; Steam verlangt eine Angabe zu KI-generierten Inhalten.

**Referenzen:** Codex Manesse (Bildsprache, Helmzier), Pentiment (Manuskript-Stil im Spiel), Bad North und Thronefall (Lesbarkeit kleiner Figuren).

**Abnahme vor der Produktion:** drei Style Frames – Reichskarte, Schlacht, Stammburg Stufe 3 – als verbindliche Grundlage für alle Assets.

**Audio**

- **Musik:** rund 12 Stücke mit Drehleier, Schalmei, Laute, Dudelsack und Rahmentrommel; in Schichten aufgebaut, damit die Karte ruhig und die Schlacht treibend klingt; ein Leitmotiv je Haus, ein Minnesang-Thema für die Tafeln.
- **Geräusche:** Foley für Rüstungen, Pferde, Bliden, einstürzendes Holz und Mauerwerk; Comic-Akzente wie der Helm-„Klong“.
- **Stimmen:** kurze Schlachtrufe, Berater-Einzeiler, ein Erzähler für Prolog und Tafeln auf Deutsch und Englisch.
- **Rechte:** KI-generierte Musik oder Stimmen nur mit eindeutigen kommerziellen Nutzungsrechten.

## Content-Umfang v1.0

Der Umfang ist bewusst eng gefasst: eine Karte, vier Häuser, sechs Einheitentypen – Tiefe kommt aus der Kombination, nicht aus der Menge.

| Bereich | Umfang |
| --- | --- |
| Provinzen | 31; historische Startaufstellung und eine gemischte Variante |
| Parteien | 4 spielbare Häuser, 7 Wahlfürsten, 6 weitere Kirchenfürsten, 10 neutrale Herren |
| Einheiten | 6 Typen plus Anführer; Häuser unterscheiden sich durch Farben und Helmzier, nicht durch eigene Modelle |
| Figuren | 1 humanoides Basismesh (weiblich und männlich), 6 Ausrüstungssätze, 4 Anführer-Helden, Pferd mit 2 Schabracken, Blide |
| Animationen | rund 40 Mensch, rund 10 Pferd |
| Burgbausatz | rund 60 Teile; 5 Stammburg- und 3 Provinzburgstufen; 5 Zierden; Zerstörungsvarianten |
| Schlachtfelder | 8 Presets nach Gelände plus Furt- und Brückenvariante |
| Abenteuer | Turnierplatz, Innenbausatz für Überfälle (rund 25 Teile), Straßen- und Wagenbausatz |
| Reichskarte | Diorama-Tisch mit Reliefkarte, 31 Provinzbanner, Armeefiguren |
| Ereignisse | 18 im GDD, Ziel 30 zum Launch |
| UI | rund 35 Bildschirme und Panels |
| Story-Tafeln | rund 25 |
| Audio | rund 12 Musikstücke, 200 Geräusche, 150 Sprachzeilen je Sprache |
| Sprachen | Deutsch, Englisch |

## Risiken & bewusst offen

Das größte Risiko ist der Umfang: sechs Spielmodi in einem Spiel. Deshalb hat jedes Modul ein Kill-Kriterium im Prototyp und es gibt eine feste Streichliste.

| Risiko | Wahrscheinlichkeit | Auswirkung | Gegenmaßnahme |
| --- | --- | --- | --- |
| Umfang übersteigt das Team | hoch | hoch | Graybox-Prototyp je Modul; Streichliste in dieser Reihenfolge: Kaufmannszug, Team-Variante, Überfall-Ziele außer Insignien |
| Schlacht macht keinen Spaß | mittel | hoch | Schlacht zuerst prototypen, wöchentliche Playtests, Kill-Entscheidung am Ende von Phase 1 |
| Pferdeanimationen | hoch | mittel | Pferdepaket in Phase 0 kaufen, berittene Figur im Pipeline-Test |
| Wirtschaft kippt | mittel | mittel | alle Werte in Daten, Balance-Runner ab dem Vertical Slice |
| KI zu schwach oder zu stark | mittel | mittel | Nutzen-Overlay, KI-gegen-KI-Statistiken, vier Schwierigkeitsstufen |
| Uneinheitlicher Look durch KI-Assets | mittel | mittel | Style Frames, Style-LoRA, Übermalen, wöchentliches Art-Review |
| Leistung auf dem Steam Deck | mittel | mittel | Budgets ab Phase 0, VAT für Massen, wöchentliche Deck-Builds |
| Missverständnisse um „Reich“ und Nationalgeschichte | niedrig | mittel | korrektes „Heiliges Römisches Reich“, Glossar, internationaler Titel, keine nationale Pathos-Sprache |

**Bewusst offen**

- Internationaler Titel neben THRONSTREIT 1198
- Prozedurale Kartenvarianten und Zahl der Provinzen je Variante
- Meta-Progression (freischaltbare Wappen, Burg-Skins, Häuser)
- DLC-Kandidaten: Romzug mit Kaiserkrönung, Kreuzzug, Hanse mit Seehandel
- Echtzeit-Online-Multiplayer
- Feinschliff der Konsolensteuerung

### Quellen

- [ADB: Philipp von Schwaben](https://de.wikisource.org/wiki/ADB:Philipp_von_Schwaben) – Krönungen 1198
- [Die Urkunden Philipps von Schwaben](https://isdistribution.com/?p=1415281) – Doppelwahl und Bündnisse
- [Notebookcheck zum DotC-Remake](https://www.notebookcheck.com/Neues-Mittelalter-Strategie-RPG-startet-auf-Steam-mit-drei-Spielmodi-und-Launch-Rabatt.1369414.0.html) – Release und Metascore
- [Vaporlens: Spielerstimmen zum DotC-Remake](https://vaporlens.app/app/4208140/defender_of_the_crown_the_legend_returns) – Kritikpunkte
