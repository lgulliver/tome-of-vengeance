#!/usr/bin/env bash
# Tests the Wago patch matching in upload-wago.sh against a fixture shaped like the
# .patches object of https://addons.wago.io/api/data/game. Run from the repo root.
set -euo pipefail
source .github/scripts/upload-wago.sh

patches='{
  "retail": ["12.0.7", "12.1.0", "12.1.5", "12.1.7"],
  "forever": ["1.60.1"],
  "classic": ["1.15.9"],
  "bc": ["2.5.6"],
  "mop": ["5.5.4"],
  "wotlk": ["3.80.2"]
}'
notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
echo "Notes" > "$notes"

passed=0 failed=0
check() {
  local name=$1 expected=$2 actual=$3
  if [[ "$actual" == "$expected" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL $name: expected '$expected', got '$actual'"
  fi
}

check "retail patches" '["12.1.0","12.1.5","12.1.7"]' "$(game_patches "$patches" "120100 120105 120107" retail)"
check "forever patch" '["1.60.1"]' "$(game_patches "$patches" 16001 forever)"
check "unlisted patch skipped" '["5.5.4"]' "$(game_patches "$patches" "50504 50505" mop)"
check "unknown game gives empty" '[]' "$(game_patches "$patches" 11509 nope)" 2> /dev/null
check "tbc maps to bc" bc "$(wago_game classic-tbc)"
check "mists maps to mop" mop "$(wago_game classic-mists)"

metadata=$(VERSION=0.1.3 STABILITY=release NOTES_FILE=$notes wago_metadata "$patches")
check "release is stable" stable "$(jq -r .stability <<< "$metadata")"
check "label is the version" 0.1.3 "$(jq -r .label <<< "$metadata")"
check "every flavour supported" \
  '{"supported_bc_patches":["2.5.6"],"supported_classic_patches":["1.15.9"],"supported_forever_patches":["1.60.1"],"supported_mop_patches":["5.5.4"],"supported_retail_patches":["12.1.0","12.1.5","12.1.7"]}' \
  "$(jq -cS 'with_entries(select(.key | startswith("supported_")))' <<< "$metadata")"
check "beta stays beta" beta \
  "$(VERSION=0.1.3-beta.1 STABILITY=beta NOTES_FILE=$notes wago_metadata "$patches" | jq -r .stability)"

if VERSION=0.1.3 STABILITY=release NOTES_FILE=$notes \
  wago_metadata "$(jq -c 'del(.forever)' <<< "$patches")" > /dev/null 2>&1; then
  check "missing flavour fails" 1 0
else
  check "missing flavour fails" 1 1
fi

echo "$passed passed, $failed failed"
[[ "$failed" == 0 ]]
