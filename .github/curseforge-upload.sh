#!/usr/bin/env bash
# Upload the packaged zip to CurseForge, tagged with the WoW Forever version that matches the .toc's Interface line.
# Usage: curseforge-upload.sh <project id> <zip> <toc>. Needs CF_API_KEY (a CurseForge API token); skips without it.
set -euo pipefail
project="$1"; zip="$2"; toc="$3"
CF_API_KEY="$(printf %s "${CF_API_KEY:-}" | tr -d " 
")"
if [ -z "${CF_API_KEY:-}" ]; then
  echo "::warning::No CF_API_KEY secret: not uploading to CurseForge."
  exit 0
fi
api="https://wow.curseforge.com/api"

# Interface 16001 -> 1.60.1
iface="$(sed -n 's/^## Interface: *\([0-9]*\).*/\1/p' "$toc" | tr -d '\r' | head -1)"
version="$((iface / 10000)).$((iface % 10000 / 100)).$((iface % 100))"

types="$(curl -fsS -H "X-Api-Token: $CF_API_KEY" "$api/game/version-types")"
versions="$(curl -fsS -H "X-Api-Token: $CF_API_KEY" "$api/game/versions")"
# prefer the version under a "Forever" game version type; fall back to any version with that name
forever_types="$(jq -c '[.[] | select((.name + " " + .slug) | test("forever"; "i")) | .id]' <<<"$types")"
id="$(jq --arg v "$version" --argjson t "$forever_types" \
  '([.[] | select(.name == $v and (.gameVersionTypeID as $g | $t | index($g)))] + [.[] | select(.name == $v)]) | first | .id // empty' <<<"$versions")"
if [ -z "$id" ]; then
  echo "::error::CurseForge has no game version $version (Interface $iface)."
  exit 1
fi
echo "CurseForge game version $version -> id $id"

# changelog: commit subjects since the previous tag
tag="${GITHUB_REF_NAME}"
prev="$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)"
if [ -n "$prev" ]; then
  changelog="$(git log --no-merges --format='- %s' "$prev..$tag" | grep -v -E '^- v?[0-9]+\.[0-9]+\.[0-9]+$' || true)"
else
  changelog="- First release"
fi
[ -n "$changelog" ] || changelog="- Small fixes"

name="$(basename "$zip" .zip)"
meta="$(jq -n --arg c "$changelog" --arg n "$name" --argjson g "[$id]" \
  '{changelog: $c, changelogType: "markdown", displayName: $n, gameVersions: $g, releaseType: "release"}')"
curl -fsS -H "X-Api-Token: $CF_API_KEY" -F "metadata=$meta" -F "file=@$zip" "$api/projects/$project/upload-file"
echo
echo "Uploaded $name to CurseForge project $project"
