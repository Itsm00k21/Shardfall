#!/usr/bin/env bash
# Layer-2 Studio smoke test for Shardfall.
# Usage: ops/studio-smoke/studio_run.sh [--no-pull] [--timeout SECS] [--ref GITREF]
#   --ref tests an older commit (exported with git archive; the checkout is untouched).
# Builds an instrumented copy of the place, opens it in Roblox Studio with a
# tiny plugin that starts Play mode via StudioTestService, and collects the
# SMOKE| lines that the in-game scripts print. Nothing in src/ is modified.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$REPO/ops/studio-smoke"
cd "$REPO" || exit 1   # rokit resolves rojo/lune from rokit.toml here
AUDIT="$HOME/ShardfallAudit"
PLUGINS="$HOME/Documents/Roblox/Plugins"
STUDIO="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
LOGDIR="$HOME/Library/Logs/Roblox"
export PATH="$HOME/.rokit/bin:$PATH"
PULL=1; TIMEOUT=600; REF=""
while [ $# -gt 0 ]; do case "$1" in --no-pull) PULL=0;; --timeout) TIMEOUT="$2"; shift;; --ref) REF="$2"; PULL=0; shift;; esac; shift; done

mkdir -p "$AUDIT" "$PLUGINS"
if [ $PULL = 1 ]; then
  (cd "$REPO" && git fetch -q origin cursor/live-build-9721 && git merge --ff-only -q origin/cursor/live-build-9721) || echo "warn: fast-forward failed, testing current checkout"
fi
RUN="$(date +%Y%m%d_%H%M%S)"
SRC="$REPO"
if [ -n "$REF" ]; then
  SHA="$(cd "$REPO" && git rev-parse --short "$REF")" || exit 2
  SRC="$AUDIT/ref_$SHA"; rm -rf "$SRC"; mkdir -p "$SRC"
  (cd "$REPO" && git archive "$SHA" src default.project.json) | tar -x -C "$SRC" || exit 2
else
  SHA="$(cd "$REPO" && git rev-parse --short HEAD)"
fi
BUILD="$AUDIT/smoke_build"
PLACE="$AUDIT/smoke_${RUN}.rbxl"
RAW="$AUDIT/studio_smoke_${RUN}.log"
echo "run=$RUN sha=$SHA"

lune run "$HERE/instrument.luau" "$SRC" "$BUILD" "$RUN" "$HERE" || exit 2
lune run "$HERE/compile_check.luau" "$BUILD/src" "$BUILD" || exit 2
(cd "$REPO" && rojo build "$BUILD/smoke.project.json" -o "$PLACE") || exit 3
(cd "$HERE/plugin" && rojo build plugin.project.json -o "$PLUGINS/StudioSmoke.rbxm") || exit 4

START_EPOCH=$(date +%s)
touch "$AUDIT/.smoke_start_$RUN"
"$STUDIO" -task EditFile -localPlaceFile "$PLACE" >/dev/null 2>&1 &
SPID=$!
echo "studio pid=$SPID place=$PLACE"

found=""
while [ $(( $(date +%s) - START_EPOCH )) -lt "$TIMEOUT" ]; do
  sleep 5
  for f in $(find "$LOGDIR" -maxdepth 1 -name '*Studio*_last.log' -newer "$AUDIT/.smoke_start_$RUN" 2>/dev/null) $(ls -t "$LOGDIR"/*Studio*_last.log | head -3); do
    if grep -q "SMOKE|$RUN|plugin|RESULT" "$f" 2>/dev/null; then found="$f"; break 2; fi
  done
done
LOGS=$(grep -l "SMOKE|$RUN|" "$LOGDIR"/*Studio*_last.log 2>/dev/null)
: > "$RAW"
for f in $LOGS; do
  echo "# from $f" >> "$RAW"
  grep -a "SMOKE|$RUN|" "$f" | sed -E 's/^([^,]+),[^]]*\] /\1 /' >> "$RAW"
  # engine-side errors for the same window (script errors with stacks)
  awk -v s="$(date -u -r "$START_EPOCH" +%Y-%m-%dT%H:%M:%S)" '$0 >= s' "$f" | grep -aE "FLog::CreatorError|Info: Script '" | grep -v "SMOKE|" | sed -E 's/^([^,]+),[^]]*\] /\1 ENGINE /' >> "$RAW"
done
if [ -n "$found" ]; then echo "finished: $found"; else echo "TIMEOUT after ${TIMEOUT}s (no plugin RESULT line)"; fi

# Clean up: our Studio process (only the one this script started) and the plugin.
if kill -0 "$SPID" 2>/dev/null; then kill "$SPID" 2>/dev/null; sleep 3; kill -9 "$SPID" 2>/dev/null; fi
rm -f "$PLUGINS/StudioSmoke.rbxm" "$AUDIT/.smoke_start_$RUN"
echo "raw log: $RAW"
grep -cE "\|(PASS|FAIL|WARN|REPRO)" "$RAW" | sed 's/^/result lines: /'
grep -E "\|(FAIL|REPRO|WARN)" "$RAW" | head -40
[ -n "$found" ] || exit 5
