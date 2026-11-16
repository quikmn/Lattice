#!/usr/bin/env bash
# Release notes for a tag, for players: the CHANGELOG.md section headed with that version ("## v1.2.0 (2026-11-16)",
# "## 1.2.0" and "## [v1.2.0](...)" all work). Without one, the commit subjects since the previous tag.
# Usage: release-notes.sh <tag>   (prints markdown). Shared copy: D:\Development_Projects\wowaddons\release.
set -euo pipefail
tag="$1"; ver="${tag#v}"
notes=""
if [ -f CHANGELOG.md ]; then
  notes="$(tr -d '\r' < CHANGELOG.md | awk -v v="$ver" '
    /^## / {
      if (on) exit
      h = $0; sub(/^## +\[?v?/, "", h); split(h, a, /[] (]/)
      if (a[1] == v) { on = 1; next }
    }
    on { lines[++n] = $0 }
    END {
      s = 1; while (s <= n && lines[s] ~ /^[ \t]*$/) s++
      e = n; while (e >= s && lines[e] ~ /^[ \t]*$/) e--
      for (i = s; i <= e; i++) print lines[i]
    }')"
fi
if [ -z "$notes" ]; then
  prev="$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)"
  if [ -n "$prev" ]; then
    notes="$(git log --no-merges --format='- %s' "$prev..$tag" | grep -v -E '^- v?[0-9]+\.[0-9]+\.[0-9]+$' || true)"
  else
    notes="- First release"
  fi
fi
[ -n "$notes" ] || notes="- Small fixes"
printf '%s\n' "$notes"
