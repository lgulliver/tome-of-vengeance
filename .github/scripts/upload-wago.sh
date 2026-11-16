#!/usr/bin/env bash
# Requires WAGO_API_TOKEN, WAGO_PROJECT_ID, VERSION, STABILITY, DIST_DIR, NOTES_FILE.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/build-release.sh"

# Wago's game key for each flavour in build-release.sh.
wago_game() {
  case $1 in
    retail) echo retail ;;
    forever) echo forever ;;
    classic-era) echo classic ;;
    classic-tbc) echo bc ;;
    classic-mists) echo mop ;;
    *) return 1 ;;
  esac
}

# Prints a JSON array of the patches (120100 -> 12.1.0) Wago lists for one game. Interfaces
# Wago doesn't list yet are skipped with a warning.
game_patches() {
  local patches=$1 interfaces=$2 game=$3 found='[]' interface patch
  for interface in $interfaces; do
    printf -v patch '%d.%d.%d' "$((interface / 10000))" "$((interface / 100 % 100))" "$((interface % 100))"
    if jq -e --arg game "$game" --arg patch "$patch" '.[$game] // [] | index($patch)' <<< "$patches" > /dev/null; then
      found=$(jq -c --arg patch "$patch" '. + [$patch] | unique' <<< "$found")
    else
      echo "warning: Wago lists no $game patch $patch (interface $interface)" >&2
    fi
  done
  echo "$found"
}

# Prints the upload metadata: one supported_<game>_patches array per flavour Wago lists.
# Every flavour's zip is identical, so one upload covers all of them.
wago_metadata() {
  local patches=$1 support='{}' failed=0 flavour suffix interfaces type_id game found stability
  while IFS='|' read -r flavour suffix interfaces type_id; do
    game=$(wago_game "$flavour") || { echo "error: no Wago game for $flavour" >&2; failed=1; continue; }
    found=$(game_patches "$patches" "$interfaces" "$game")
    if [[ "$found" == '[]' ]]; then
      echo "error: no Wago patch for $flavour; it will be missing from the upload" >&2
      failed=1
      continue
    fi
    support=$(jq -c --arg key "supported_${game}_patches" --argjson found "$found" \
      '. + {($key): $found}' <<< "$support")
  done < <(flavours)
  [[ "$support" != '{}' ]] || return 1
  stability=$STABILITY
  [[ "$stability" == release ]] && stability=stable
  jq -n --arg label "$VERSION" --arg stability "$stability" --argjson support "$support" \
    --rawfile changelog "$NOTES_FILE" \
    '{label: $label, stability: $stability, changelog: $changelog} + $support'
  return "$failed"
}

upload() {
  local site=https://addons.wago.io patches metadata failed=0 archive result
  patches=$(curl -fsS "$site/api/data/game" | jq -c '.patches')
  jq -e 'type == "object"' <<< "$patches" > /dev/null
  metadata=$(wago_metadata "$patches") || failed=1
  if [[ -z "$metadata" ]]; then
    echo "error: no Wago patches found; not uploaded" >&2
    return 1
  fi
  archive="$DIST_DIR/TomeOfVengeance-${VERSION}.zip"
  echo "Uploading $archive to Wago: $(jq -c 'del(.changelog)' <<< "$metadata")"
  result=$(curl -sS -w '\n%{http_code}' -H "authorization: Bearer $WAGO_API_TOKEN" \
    -H "accept: application/json" -F "metadata=$metadata" -F "file=@$archive" \
    "$site/api/projects/$WAGO_PROJECT_ID/version")
  echo "${result%$'\n'*}"
  case ${result##*$'\n'} in
    200 | 201) ;;
    *)
      echo "error: Wago upload failed (HTTP ${result##*$'\n'})" >&2
      return 1
      ;;
  esac
  return "$failed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  upload
fi
