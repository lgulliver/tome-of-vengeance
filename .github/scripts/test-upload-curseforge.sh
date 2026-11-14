#!/usr/bin/env bash
# Tests the CurseForge game version matching in upload-curseforge.sh against a fixture
# shaped like https://wow.curseforge.com/api/game/wow/versions. Run from the repo root.
set -euo pipefail
source .github/scripts/upload-curseforge.sh

versions='[
  {"id": 1, "gameVersionTypeID": 517,   "name": "12.1.0", "slug": "12-1-0"},
  {"id": 2, "gameVersionTypeID": 517,   "name": "12.1.5", "slug": "12-1-5", "apiVersion": null},
  {"id": 3, "gameVersionTypeID": 88568, "name": "1.60.1", "slug": "1-60-1"},
  {"id": 4, "gameVersionTypeID": 67408, "name": "1.15.9", "slug": "1-15-9"},
  {"id": 5, "gameVersionTypeID": 73713, "name": "2.5.6",  "slug": "2-5-6"},
  {"id": 6, "gameVersionTypeID": 77522, "name": "5.5.4",  "slug": "5-5-4"},
  {"id": 7, "gameVersionTypeID": 517,   "name": "1.15.9", "slug": "1-15-9-retail-typo"},
  {"id": 8, "gameVersionTypeID": 67408, "name": "2.5.6",  "slug": "2-5-6", "apiVersion": "11509"},
  {"id": 9, "gameVersionTypeID": 73713, "name": "2.5.6",  "slug": "2-5-6-b", "apiVersion": "20506"}
]'

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

check "retail by name and type, no apiVersion" 1 "$(match_version "$versions" 120100 517)"
check "forever by name and type" 3 "$(match_version "$versions" 16001 88568)"
check "auto skips retail and forever types" 4 "$(match_version "$versions" 11509 auto)"
check "apiVersion breaks a tie when present" 9 "$(match_version "$versions" 20506 auto)"
check "auto mists" 6 "$(match_version "$versions" 50504 auto)"
check "unknown patch gives nothing" "" "$(match_version "$versions" 120107 517)"
check "flavour keeps the versions that exist" '[1,2]' "$(flavour_versions "$versions" "120100 120105 120107" 517)"
check "flavour with none gives empty" '[]' "$(flavour_versions "$versions" "99999" 517)"

echo "$passed passed, $failed failed"
[[ "$failed" == 0 ]]
