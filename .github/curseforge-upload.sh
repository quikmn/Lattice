#!/usr/bin/env bash
# Upload the packaged zip to CurseForge, tagged with the WoW Forever version that matches the .toc's Interface line.
# Usage: curseforge-upload.sh <project id> <zip> <toc>. Needs CF_API_KEY (a CurseForge API token); skips without it.
# Everything comes from the repo or the API, nothing is typed by hand:
#   game version  the API's game version whose apiVersion is the .toc Interface (16001), under "WoW Forever"
#   changelog     this tag's CHANGELOG.md section (release-notes.sh)
#   release type  alpha/beta when the tag says so, else curseforge/curseforge.json "releaseType" (default release)
#   relations     curseforge/curseforge.json "relations": [{"slug": "...", "type": "requiredDependency"}, ...]
# Shared copy: D:\Development_Projects\wowaddons\release.
set -euo pipefail
project="$1"; zip="$2"; toc="$3"
CF_API_KEY="$(printf %s "${CF_API_KEY:-}" | tr -d ' \r\n')"
if [ -z "${CF_API_KEY:-}" ]; then
  echo "::warning::No CF_API_KEY secret: not uploading to CurseForge."
  exit 0
fi
api="https://wow.curseforge.com/api"
tag="${GITHUB_REF_NAME:-}"

cfg="{}"
for f in curseforge/curseforge.json curseforge.json; do
  if [ -f "$f" ]; then cfg="$(tr -d '\r' < "$f")"; break; fi
done
jq -e . >/dev/null <<<"$cfg" || { echo "::error::curseforge.json is not valid JSON."; exit 1; }

# Interface 16001 -> 1.60.1
iface="$(sed -n 's/^## Interface: *\([0-9]*\).*/\1/p' "$toc" | tr -d '\r' | head -1)"
version="$((iface / 10000)).$((iface % 10000 / 100)).$((iface % 100))"

types="$(curl -fsS -H "X-Api-Token: $CF_API_KEY" "$api/game/version-types")"
versions="$(curl -fsS -H "X-Api-Token: $CF_API_KEY" "$api/game/versions")"
# prefer the version under a "Forever" game version type whose apiVersion is the Interface number, then by name
forever_types="$(jq -c '[.[] | select((.name + " " + .slug) | test("forever"; "i")) | .id]' <<<"$types")"
id="$(jq --arg v "$version" --arg i "$iface" --argjson t "$forever_types" '
  ([.[] | select((.gameVersionTypeID as $g | $t | index($g)) and ((.apiVersion // "") | tostring) == $i)] +
   [.[] | select(.name == $v and (.gameVersionTypeID as $g | $t | index($g)))] +
   [.[] | select(.name == $v)]) | first | .id // empty' <<<"$versions")"
if [ -z "$id" ]; then
  echo "::error::CurseForge has no game version $version (Interface $iface)."
  exit 1
fi
echo "CurseForge game version $version -> id $id"

case "$(printf %s "$tag" | tr 'A-Z' 'a-z')" in
  *alpha*) release_type=alpha ;;
  *beta*) release_type=beta ;;
  *) release_type="$(jq -r '.releaseType // "release"' <<<"$cfg")" ;;
esac
case "$release_type" in alpha|beta|release) ;; *) echo "::error::releaseType '$release_type' must be alpha, beta or release."; exit 1 ;; esac

relations="$(jq -c '[.relations[]? | {slug, type}]' <<<"$cfg")"
bad="$(jq -r '.[] | select((.slug // "") == "" or (.type | IN("embeddedLibrary","incompatible","optionalDependency","requiredDependency","tool") | not)) | "\(.slug) \(.type)"' <<<"$relations")"
if [ -n "$bad" ]; then
  echo "::error::curseforge.json relations need a slug and a type (embeddedLibrary, incompatible, optionalDependency, requiredDependency, tool): $bad"
  exit 1
fi
[ "$relations" = "[]" ] || echo "Relations: $relations"

# changelog: this version's section of CHANGELOG.md (falls back to commit subjects)
changelog="$(bash "$(dirname "$0")/release-notes.sh" "$tag")"

name="$(basename "$zip" .zip)"
meta="$(jq -n --arg c "$changelog" --arg n "$name" --argjson g "[$id]" --arg r "$release_type" --argjson rel "$relations" \
  '{changelog: $c, changelogType: "markdown", displayName: $n, gameVersions: $g, releaseType: $r}
   + (if ($rel | length) > 0 then {relations: {projects: $rel}} else {} end)')"
if [ -n "${CF_DRY_RUN:-}" ]; then
  echo "CF_DRY_RUN: would upload $zip to project $project with:"
  printf '%s\n' "$meta"
  exit 0
fi
out="$(curl -sS -w '
%{http_code}' -H "X-Api-Token: $CF_API_KEY" --form-string "metadata=$meta" -F "file=@$zip" "$api/projects/$project/upload-file")"
code="${out##*$'
'}"
echo "${out%$'
'*}"
if [ "$code" != "200" ]; then
  echo "::error::CurseForge upload failed (HTTP $code)."
  exit 1
fi
echo "Uploaded $name to CurseForge project $project ($release_type)"
