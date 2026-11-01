#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${TOOLS:-$ROOT/.tools}"
DOWNLOADS="$ROOT/.downloads"
OWN_LISTS="$ROOT/lists"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/build}"
CONVERTER_COMMIT="1cfdcaf042880a5e0027a8fc6f7ebf9ee667acc9"
SAFARI_VERSION="${SAFARI_VERSION:-18}"

SOURCES=(
  "easylist https://easylist.to/easylist/easylist.txt"
  "easyprivacy https://easylist.to/easylist/easyprivacy.txt"
  "easylistportuguese https://easylist-downloads.adblockplus.org/easylistportuguese.txt"
  "easylistspanish https://easylist-downloads.adblockplus.org/easylistspanish.txt"
  "easylistgermany https://easylist.to/easylistgermany/easylistgermany.txt"
  "annoyances https://secure.fanboy.co.nz/fanboy-annoyance.txt"
  "social https://easylist.to/easylist/fanboy-social.txt"
)

BLOCKERS=(
  "AdBlocker easylist easyprivacy easylistportuguese easylistspanish easylistgermany"
  "AnnoyancesBlocker annoyances-without-social annoyances-br"
)

build_converter() {
  local repo="$TOOLS/SafariConverterLib"
  if [[ ! -d "$repo" ]]; then
    git clone --quiet https://github.com/AdguardTeam/SafariConverterLib.git "$repo"
  fi
  git -C "$repo" fetch --quiet --depth 1 origin "$CONVERTER_COMMIT" 2>/dev/null || true
  git -C "$repo" checkout --quiet "$CONVERTER_COMMIT"
  (cd "$repo" && swift build -c release --product ConverterTool >/dev/null 2>&1) \
    || { echo "Failed to build SafariConverterLib" >&2; exit 1; }
  CONVERTER="$repo/.build/release/ConverterTool"
}

download_lists() {
  mkdir -p "$DOWNLOADS"
  for pair in "${SOURCES[@]}"; do
    set -- $pair
    curl -sSfL -o "$DOWNLOADS/$1.txt" "$2"
  done
}

remove_social_rules() {
  grep -vxF -f <(grep -v '^!' "$DOWNLOADS/social.txt") "$DOWNLOADS/annoyances.txt" > "$DOWNLOADS/annoyances-without-social.txt"
}

canonicalize() {
  python3 - "$1" <<'EOF'
import json, sys
path = sys.argv[1]
rules = json.load(open(path))
for rule in rules:
    for key in ("if-domain", "unless-domain"):
        if key in rule["trigger"]:
            rule["trigger"][key] = sorted(rule["trigger"][key])
    if "selector" in rule["action"]:
        rule["action"]["selector"] = ", ".join(sorted(rule["action"]["selector"].split(", ")))
key = lambda rule: json.dumps(rule, sort_keys=True)
ordered, segment = [], []
for rule in rules:
    if rule["action"]["type"] == "ignore-previous-rules":
        ordered += sorted(segment, key=key) + [rule]
        segment = []
    else:
        segment.append(rule)
ordered += sorted(segment, key=key)
json.dump(ordered, open(path, "w"), sort_keys=True, separators=(",", ":"))
EOF
}

convert() {
  local target="$1" input advanced
  shift
  mkdir -p "$OUTPUT_DIR/$target"
  input="$(mktemp)"
  advanced="$(mktemp)"
  for list in "$@"; do
    if [[ -f "$OWN_LISTS/$list.txt" ]]; then cat "$OWN_LISTS/$list.txt"; else cat "$DOWNLOADS/$list.txt"; fi >> "$input"
  done
  "$CONVERTER" convert -s "$SAFARI_VERSION" -a false --input-path "$input" \
    --safari-rules-json-path "$OUTPUT_DIR/$target/blockerList.json" --advanced-blocking-rules-path "$advanced" >/dev/null
  rm -f "$input" "$advanced"
  canonicalize "$OUTPUT_DIR/$target/blockerList.json"
  local count
  count="$(python3 -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$OUTPUT_DIR/$target/blockerList.json")"
  echo "$target: $count rules ($(du -h "$OUTPUT_DIR/$target/blockerList.json" | cut -f1))"
}

build_converter
[[ "${SKIP_DOWNLOAD:-0}" == 1 ]] || download_lists
remove_social_rules
for line in "${BLOCKERS[@]}"; do convert $line; done
