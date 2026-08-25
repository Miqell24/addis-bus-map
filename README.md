# Addis Ababa Public Transport — interactive map

Interactive, poster-grade map of the public transport of **Addis Ababa**: the
Anbessa and Sheger city buses, the minibus taxis of the sub-city associations
and the two Light Rail lines — 447 lines / 9 465 km drawn along the real street
and track geometry.

## Live

**https://miqell24.github.io/addis-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8158 (`npm run serve`).

One bundle, three networks:

| category | source | lines | drawn |
|---|---|---|---|
| formal buses (navy) | route_type 3, Anbessa `AB…` + Sheger `SH…`, `A/B/C/D…` | 194 | 5 345 km |
| minibus taxis (amber) | route_type 3, `(Minibus)` in the long name | 251 | 4 056 km |
| Light Rail | route_type 0, E–W green / S–N blue | 2 | 64 km |

Where a roadway carries both a bus and a minibus route it is drawn once, navy,
with the amber dashed over it — 1 871 of the 3 101 runs are shared like that,
550 are minibus-only and 680 bus-only. The two Light Rail lines share the
central viaduct; that stretch is purple, the family's "several rail lines here"
colour, not the red it keeps for trams.

## Where the data comes from

**AddisMapTransit** surveyed the city's transport into OpenStreetMap between
2022 and 2024 with funding from the **DT4A Innovation Challenge**, and extracts
the GTFS from OSM. **DigitalTransport4Africa** mirrors it on GitLab; this map
reads `Addis Ababa GTFS_2026/et-addisababa_2026.zip` from there. Licence: ODbL,
like OSM itself.

The same dataset appears on **mobilitydatabase.org** as feed `tld-6782`, but
that is a December-2024 snapshot of the older *2023* file — same data, one
refresh behind — so the DT4A repository is the source used here.

Because the shapes ARE OpenStreetMap geometry, the match is exact where a shape
is whole: mean error 0.54 m across 891 line-directions, worst 10.6 m.

Build quirks worth knowing:

* **133 of the 891 shapes are truncated stubs.** Where the OSM relation carries
  only its first few ways, the extracted shape comes out short — AB010/0 is
  ten points and 200 m for an 11 km route, C15/1 and AB009/0 are empty in all
  but name. A complete shape can never be shorter than the straight line
  through its own stops, and the feed's healthy reps sit at 1.0–1.3 of it, so
  anything under 0.95 is discarded and that rep matches on its **stop
  sequence** instead (the path this family already uses for shapeless feeds).
  Before the rule, those lines were drawn as a 200 m stub with a 12 km
  "terminal repair" tacked on; after it, 22 terminal repairs remain and the
  largest is 764 m.
* **Line keys are the operators' own, with one normalisation.** The minibus
  names carry a redundant `Tx`/`TX` token and a space before the number
  (`Tx ADK 002`, `TX Kolfe 023`, `Lafto 044`) — up to twelve characters for an
  association and a number, on streets that gather two dozen of them. The token
  goes, the space closes: `ADK002`, `Kolfe023`, `Lafto044`. The eight plain
  `TX###` names and every bus name stay as they are. 447 names in, 447 keys
  out, no collision. (`Kolfa042` and `Kolfe042` are two different routes in the
  feed and stay two keys — the spellings are not merged.)
* **There are no timetables here.** The feed is frequency-based, one trip per
  route and direction; what it describes is where the routes go and where they
  stop, which is exactly what this map draws.
* Street names come from OSM. 5 128 of the 5 294 named ways in the extract are
  already Latin; of the 158 written in Ethiopic, the 70 that carry a `name:en`
  are labelled with it, because the base map's glyph set has no Ethiopic and
  they would otherwise render as empty boxes. The rest keep their own name.

## Two views

The panel's **Corridors / Lines** switch redraws the same data two ways.
*Corridors* is one stroke per roadway, the whole network in its category
colours. *Lines* draws every line on its own — up to four coloured strands side
by side, anything busier as one grey trunk with its numbers beside it
(`npm run lines`, checked by `npm run audit`). 42 % of the 3 101 roadway runs
carry four lines or fewer and are drawn strand by strand; the widest trunk
gathers 68. No network diagram for this city yet.

## Pipeline

`npm run download` fetches the GTFS, OSM roadways and rails (Overpass, bbox
8.70–9.36 N / 38.30–39.22 E — the Sheger buses reach Aleltu, Debre Zeit and
Teji, 40–50 km out) and MapLibre GL. `npm run build` map-matches every line
(HMM/Viterbi on the OSM graphs) and writes GeoJSON to `data/out/`;
`npm run lines` adds the line-by-line view, `npm run audit` checks it.
`npm run serve` hosts the map at http://localhost:8158.

Data: GTFS by AddisMapTransit / DigitalTransport4Africa (ODbL) · base map
© OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
