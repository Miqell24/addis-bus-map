#!/usr/bin/env bash
# Downloads input data: the AddisMap/DT4A GTFS, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# Addis Ababa: ONE bundle, three networks. AddisMapTransit surveyed the city's
# transport into OpenStreetMap between 2022 and 2024 with DT4A Innovation
# Challenge funding and extracts the GTFS from OSM; DigitalTransport4Africa
# mirrors it on GitLab. The 2026 folder there is the current one — the copy on
# mobilitydatabase.org (feed tld-6782) is a December-2024 snapshot of the older
# 2023 file, same data, one refresh behind. Licence: ODbL, like OSM itself.
#
# et-addisababa_2026.zip carries all of it: Anbessa City Bus (AB…), Sheger Mass
# Transport (SH…, A/B/C/D…), the minibus taxi associations (251 routes, tagged
# "(Minibus)" in route_long_name) and the two Light Rail lines as route_type 0.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements — `grep -q '"elements"'` passes on a truncated response too
# (Brașov's roads arrived as a 65 kB fragment and silently skipped the city).
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# Overpass with patience: the public mirrors answer 504 ("server too busy") for
# minutes at a time, and a single pass over the endpoints then leaves the city
# without a road graph. Rounds with growing back-off, mirrors rotated inside each.
overpass () { # $1=outfile  $2=query  $3=minimum element count
  local out="$1" q="$2" floor="$3" round wait
  for round in 1 2 3 4 5 6 7 8; do
    for EP in "https://overpass-api.de/api/interpreter" \
              "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
              "https://overpass.kumi.systems/api/interpreter" \
              "https://overpass.private.coffee/api/interpreter"; do
      echo "-- round $round: $EP"
      if curl -fsS --max-time 900 -o "$out" --data-urlencode "data=$q" "$EP" && ok_json "$out" "$floor"; then
        return 0
      fi
      rm -f "$out"
    done
    wait=$((round * 45))
    echo "-- all mirrors busy, waiting ${wait}s"
    sleep "$wait"
  done
  echo "Overpass: all mirrors failed for $out" >&2
  return 1
}

# 1) GTFS — the combined 2026 bundle from the DT4A repository on GitLab
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== GTFS → data/gtfs =="
  curl -fL --retry 3 --max-time 600 -o data/gtfs.zip \
    "https://gitlab.com/digitaltransport/data/africa/addis-ababa/-/raw/master/Addis%20Ababa%20GTFS_2026/et-addisababa_2026.zip"
  unzip -o data/gtfs.zip -d data/gtfs
fi

# 2) OSM — roadways over the whole region. The Sheger buses run far out of town
#    (GTFS stops extent 8.74–9.31 N, 38.37–39.15 E: Debre Zeit/Bishoftu 41 km
#    south-east, Aleltu 49 km north-east, Teji 47 km south-west), so the extract
#    is 73 × 101 km with margin.
if [ ! -f data/osm/addis.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900][maxsize:1500000000];way(8.70,38.30,9.36,39.22)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  overpass data/osm/addis.json "$Q" 2000
fi

# 2b) OSM — rails for the Light Rail. The two LRT lines are railway=light_rail;
#     the Addis–Djibouti main line (railway=rail) rides along and is harmless —
#     Viterbi consistency keeps each line on its own connected network.
if [ ! -f data/osm/addis-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:600][maxsize:1000000000];way(8.70,38.30,9.36,39.22)["railway"~"^(light_rail|tram|rail|construction)$"];out geom;'
  overpass data/osm/addis-rail.json "$QT" 40
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs data/osm/addis.json data/osm/addis-rail.json 2>/dev/null || true
