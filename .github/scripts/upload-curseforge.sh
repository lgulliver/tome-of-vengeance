#!/usr/bin/env bash
# Requires CF_API_TOKEN, CF_PROJECT_ID, VERSION, STABILITY, DIST_DIR, NOTES_FILE.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/build-release.sh"

RETAIL_TYPE=517
FOREVER_TYPE=88568

# Prints the CurseForge game version ID for one TOC interface, or nothing when there is no
# unique match. Matches on the patch name (120100 -> 12.1.0) and version type; "auto" means
# any type except Retail and Forever, so Classic type IDs never have to be guessed. CurseForge
# often leaves apiVersion empty, so it only breaks a tie when it is present.
match_version() {
  local versions=$1 interface=$2 type=$3 patch
  printf -v patch '%d.%d.%d' "$((interface / 10000))" "$((interface / 100 % 100))" "$((interface % 100))"
  jq -r --arg interface "$interface" --arg patch "$patch" --arg type "$type" \
    --argjson retail "$RETAIL_TYPE" --argjson forever "$FOREVER_TYPE" '
    [.[] | select(.name == $patch)
      | select(if $type == "auto" then .gameVersionTypeID != $retail and .gameVersionTypeID != $forever
        else (.gameVersionTypeID | tostring) == $type end)] as $named
    | ([$named[] | select((.apiVersion // "" | tostring) == $interface)]) as $exact
    | if ($exact | length) == 1 then $exact[0].id
      elif ($named | length) == 1 then $named[0].id
      else empty end' <<< "$versions"
}

# Prints a JSON array of the version IDs found for a flavour's interfaces. Interfaces CurseForge
# doesn't list yet (e.g. a patch released this week) are skipped with a warning.
flavour_versions() {
  local versions=$1 interfaces=$2 type=$3 ids='[]' interface id
  for interface in $interfaces; do
    id=$(match_version "$versions" "$interface" "$type")
    if [[ -n "$id" ]]; then
      ids=$(jq -c --argjson id "$id" '. + [$id] | unique' <<< "$ids")
    else
      echo "warning: no unique CurseForge game version for interface $interface (type $type)" >&2
    fi
  done
  echo "$ids"
}

upload() {
  local site=https://wow.curseforge.com versions failed=0
  local flavour suffix interfaces type_id game_versions archive metadata
  versions=$(curl -fsS -H "x-api-token: $CF_API_TOKEN" "$site/api/game/wow/versions")
  jq -e 'type == "array"' <<< "$versions" > /dev/null
  while IFS='|' read -r flavour suffix interfaces type_id; do
    game_versions=$(flavour_versions "$versions" "$interfaces" "$type_id")
    if [[ "$game_versions" == '[]' ]]; then
      echo "error: no CurseForge game version for $flavour; not uploaded" >&2
      failed=1
      continue
    fi
    archive="$DIST_DIR/TomeOfVengeance-${VERSION}${suffix}.zip"
    metadata=$(jq -n --arg name "$VERSION ($flavour)" --arg release "$STABILITY" \
      --argjson gameVersions "$game_versions" --rawfile changelog "$NOTES_FILE" \
      '{displayName: $name, releaseType: $release, gameVersions: $gameVersions,
        changelogType: "markdown", changelog: $changelog}')
    echo "Uploading $archive ($flavour, $STABILITY, game versions $game_versions)"
    if ! curl -fsS -H "x-api-token: $CF_API_TOKEN" -F "metadata=$metadata" \
      -F "file=@$archive" "$site/api/projects/$CF_PROJECT_ID/upload-file"; then
      echo "error: CurseForge upload failed for $flavour; continuing other flavours" >&2
      failed=1
    fi
    echo
  done < <(flavours)
  return "$failed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  upload
fi
