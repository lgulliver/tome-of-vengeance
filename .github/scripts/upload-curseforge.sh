#!/usr/bin/env bash
# Requires CF_API_TOKEN, CF_PROJECT_ID, VERSION, STABILITY, DIST_DIR, NOTES_FILE.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/build-release.sh"

site=https://wow.curseforge.com
versions=$(curl -fsS -H "x-api-token: $CF_API_TOKEN" "$site/api/game/wow/versions")
jq -e 'type == "array"' <<< "$versions" > /dev/null
failed=0
while IFS='|' read -r flavour suffix interfaces type_id; do
  game_versions='[]'
  missing=0
  for interface in $interfaces; do
    printf -v patch '%d.%d.%d' "$((interface / 10000))" "$((interface / 100 % 100))" "$((interface % 100))"
    # Exact apiVersion prevents collisions between Forever and Classic Era.
    # Classic type IDs are discovered from live records, never guessed from digit count.
    matches=$(jq -c --arg interface "$interface" --arg patch "$patch" --arg type "$type_id" '
      [.[] | select((.apiVersion | tostring) == $interface and .name == $patch)
        | select(if $type == "auto" then .gameVersionTypeID != 517 and .gameVersionTypeID != 88568
          else (.gameVersionTypeID | tostring) == $type end)]' <<< "$versions")
    if [[ $(jq 'length' <<< "$matches") != 1 ]]; then
      echo "warning: CurseForge has no unique $flavour game version $patch (interface $interface); skipping flavour" >&2
      missing=1
      break
    fi
    id=$(jq -r '.[0].id' <<< "$matches")
    game_versions=$(jq -c --argjson id "$id" '. + [$id] | unique' <<< "$game_versions")
  done
  [[ "$missing" == 0 ]] || continue
  archive="$DIST_DIR/TomeOfVengeance-${VERSION}${suffix}.zip"
  metadata=$(jq -n --arg name "$VERSION ($flavour)" --arg release "$STABILITY" \
    --argjson gameVersions "$game_versions" --rawfile changelog "$NOTES_FILE" \
    '{displayName: $name, releaseType: $release, gameVersions: $gameVersions,
      changelogType: "markdown", changelog: $changelog}')
  echo "Uploading $archive ($flavour, $STABILITY)"
  if ! curl -fsS -H "x-api-token: $CF_API_TOKEN" -F "metadata=$metadata" \
    -F "file=@$archive" "$site/api/projects/$CF_PROJECT_ID/upload-file"; then
    echo "warning: CurseForge upload failed for $flavour; continuing other flavours" >&2
    failed=1
  fi
  echo
done < <(flavours)
exit "$failed"
