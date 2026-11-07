#!/usr/bin/env bash
set -euo pipefail

RETAIL_INTERFACES="120100 120105 120107"
FOREVER_INTERFACES="16001"
CLASSIC_ERA_INTERFACES="11509"
CLASSIC_TBC_INTERFACES="20506"
CLASSIC_MISTS_INTERFACES="50504"

# Shared by packaging and uploads: flavour, asset suffix, exact interfaces, known CF type.
flavours() {
  printf '%s|%s|%s|%s\n' \
    retail '' "$RETAIL_INTERFACES" 517 \
    forever -forever "$FOREVER_INTERFACES" 88568 \
    classic-era -classic "$CLASSIC_ERA_INTERFACES" auto \
    classic-tbc -bc "$CLASSIC_TBC_INTERFACES" auto \
    classic-mists -mists "$CLASSIC_MISTS_INTERFACES" auto
}

build() {
  local version="${GITHUB_REF_NAME#v}"
  local toc=TomeOfVengeance/TomeOfVengeance.toc
  local toc_version interfaces flavour suffix targets type_id interface
  [[ "$GITHUB_REF_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9][A-Za-z0-9.-]*)?$ ]] || {
    echo "Invalid release tag: $GITHUB_REF_NAME" >&2
    return 1
  }
  toc_version=$(sed -n 's/^## Version: *//p' "$toc" | tr -d '\r')
  if [[ "$toc_version" != "${version%%-*}" ]]; then
    echo "Tag $GITHUB_REF_NAME does not match TOC version $toc_version" >&2
    return 1
  fi
  interfaces=$(sed -n 's/^## Interface: *//p' "$toc" | tr -d '\r ' | tr ',' '\n')
  while IFS='|' read -r flavour suffix targets type_id; do
    for interface in $targets; do
      if ! grep -qxF "$interface" <<< "$interfaces"; then
        echo "Missing $flavour interface $interface in $toc" >&2
        return 1
      fi
    done
  done < <(flavours)
  # Reject unclassified interfaces rather than silently omitting a new client.
  for interface in $interfaces; do
    if ! flavours | cut -d '|' -f 3 | tr ' ' '\n' | grep -qxF "$interface"; then
      echo "Unclassified TOC interface $interface" >&2
      return 1
    fi
  done

  local dist="${DIST_DIR:-dist}" stage stability=release
  mkdir -p "$dist"
  dist=$(cd "$dist" && pwd)
  stage=$(mktemp -d)
  trap 'rm -rf "$stage"' EXIT
  cp -R TomeOfVengeance "$stage/TomeOfVengeance"
  cp LICENSE "$stage/TomeOfVengeance/LICENSE"
  case "$version" in *-*) stability=beta ;; esac
  : > "$dist/packages.tsv"
  while IFS='|' read -r flavour suffix targets type_id; do
    local archive="$dist/TomeOfVengeance-${version}${suffix}.zip"
    rm -f "$archive"
    (cd "$stage" && zip -qr "$archive" TomeOfVengeance)
    printf '%s\t%s\n' "$flavour" "$archive" >> "$dist/packages.tsv"
    echo "$archive"
  done < <(flavours)
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
      echo "VERSION=$version"
      echo "STABILITY=$stability"
      echo "DIST_DIR=$dist"
      echo "NOTES_FILE=$dist/notes.md"
    } >> "$GITHUB_ENV"
  fi
  rm -rf "$stage"
  trap - EXIT
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  build
fi
