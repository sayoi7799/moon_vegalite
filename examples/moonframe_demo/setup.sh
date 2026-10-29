#!/usr/bin/env bash
# MoonFrame 0.7.0 and its dependencies (NyaCSV, quickcheck) were published for an
# older MoonBit toolchain. Two things stop them from building today:
#   1. they ship the old moon.mod.json, which `moon fmt` migrates to moon.mod;
#   2. NyaCSV has three inline tests that use the removed Buffer API, which are
#      dropped here (they test NyaCSV itself, not anything this demo uses).
# The dependencies are fetched in rounds (one only after the previous manifest
# loads), so repeat until the project checks. Run once; safe to repeat.
set -u
cd "$(dirname "$0")"
moon update

drop_buffer_tests() {
  f=".mooncakes/moonbit-community/NyaCSV/nyacsv.mbt"
  [ -f "$f" ] || return 0
  awk 'function flush() {
         if (!(blk ~ /\ntest / && blk ~ /@buffer\.new\(\)/)) printf "%s", blk
         blk = ""
       }
       /^\/\/\/\|/ { flush() }
       { blk = blk $0 "\n" }
       END { flush() }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

for round in 1 2 3 4 5 6; do
  drop_buffer_tests
  if moon check >/dev/null 2>&1; then
    echo "ready"
    exit 0
  fi
  for dir in .mooncakes/*/*; do
    if [ -f "$dir/moon.mod.json" ]; then
      echo "migrating $dir"
      (cd "$dir" && moon fmt >/dev/null 2>&1)
    fi
  done
done
moon check
