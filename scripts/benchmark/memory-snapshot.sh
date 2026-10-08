#!/usr/bin/env bash
# Append a container-memory snapshot of the running benchmark container(s) to a CSV.
# Usage: scripts/benchmark/memory-snapshot.sh <label> [csv-file]
#   label    e.g. falkordb-S-loaded (target-scale-checkpoint; checkpoints: empty, loaded, after-query)
#   csv-file defaults to scripts/benchmark/memory.csv (git-ignored)
set -euo pipefail

label="${1:?usage: $0 <label> [csv-file]}"
csv="${2:-$(dirname "$0")/memory.csv}"
containers=$(docker ps --filter "name=^falkorst-bench-" --format '{{.Names}}')

if [ -z "$containers" ]; then
  echo "no running falkorst-bench-* container" >&2
  exit 1
fi

[ -f "$csv" ] || echo "timestamp,label,container,mem_usage,mem_percent" > "$csv"
for container in $containers; do
  docker stats --no-stream --format "{{.MemUsage}},{{.MemPerc}}" "$container" |
    sed "s|^|$(date -u +%Y-%m-%dT%H:%M:%SZ),${label},${container},|" | tee -a "$csv"
done
