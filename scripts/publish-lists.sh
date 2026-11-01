#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/dist/lists}"
export OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/build}"
API_VERSION="v1"
TARGET="$OUT/$API_VERSION"

LISTS=(
  "adBlocker AdBlocker/blockerList.json"
  "annoyances AnnoyancesBlocker/blockerList.json"
  "aiOverviews AnnoyancesBlocker/aiOverviews.json"
)

[[ -n "${LISTS_SIGNING_KEY:-}" ]] || { echo "LISTS_SIGNING_KEY is not set" >&2; exit 1; }

"$ROOT/scripts/build-lists.sh"
swift "$ROOT/scripts/lists-tool.swift" validate $(for pair in "${LISTS[@]}"; do set -- $pair; echo "$OUTPUT_DIR/$2"; done)

rm -rf "$OUT"
mkdir -p "$TARGET/lists"

entries=()
for pair in "${LISTS[@]}"; do
  set -- $pair
  sha="$(shasum -a 256 "$OUTPUT_DIR/$2" | cut -d' ' -f1)"
  size="$(wc -c < "$OUTPUT_DIR/$2" | tr -d ' ')"
  file="lists/$1-${sha:0:16}.json"
  cp "$OUTPUT_DIR/$2" "$TARGET/$file"
  entries+=("$1 $file $sha $size")
done

python3 - "$TARGET/manifest.json" "${entries[@]}" <<'EOF'
import datetime, json, sys
lists = {}
for entry in sys.argv[2:]:
    name, file, sha, size = entry.split()
    lists[name] = {"file": file, "sha256": sha, "size": int(size)}
version = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(sys.argv[1], "w") as handle:
    json.dump({"version": version, "lists": lists}, handle, sort_keys=True)
EOF

swift "$ROOT/scripts/lists-tool.swift" sign "$TARGET/manifest.json"

cat > "$OUT/NOTICE.txt" <<'EOF'
Kyvyo content blocker lists, compiled for Safari.

Sources and licenses:
- EasyList and EasyPrivacy (https://easylist.to) - CC BY-SA 3.0 or GPL-3.0
- EasyList Portuguese (https://easylist-downloads.adblockplus.org/easylistportuguese.txt) - see its header
- EasyList Spanish (https://easylist-downloads.adblockplus.org/easylistspanish.txt) - see its header
- EasyList Germany (https://easylist.to/easylistgermany/easylistgermany.txt) - GPL-3.0 or CC BY-SA 3.0
- Fanboy's Annoyance List without social rules (https://secure.fanboy.co.nz) - CC BY 3.0
- Kyvyo's own rules (lists/annoyances-br.txt and lists/ai-overviews.txt)

Compiled with SafariConverterLib (https://github.com/AdguardTeam/SafariConverterLib), GPL-3.0, used as a build tool only.
EOF

cat > "$OUT/_headers" <<EOF
/$API_VERSION/manifest.*
  Cache-Control: no-cache
/$API_VERSION/lists/*
  Cache-Control: public, max-age=31536000, immutable
EOF

echo "Published to $OUT:"
ls -laR "$TARGET"
