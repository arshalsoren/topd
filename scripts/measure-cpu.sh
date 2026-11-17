#!/usr/bin/env bash
# Average CPU utilization of the running topd process over a window.
# Usage: scripts/measure-cpu.sh [seconds]   (default 30)
# Run it with the popover open to measure CPU while the popover is showing.
set -euo pipefail

seconds="${1:-30}"
pid="$(pgrep -x topd | head -n 1 || true)"
if [ -z "$pid" ]; then
    echo "topd is not running. Start it with ./run.sh first." >&2
    exit 1
fi

samples=0
total=0
peak=0
for _ in $(seq 1 "$seconds"); do
    value="$(ps -o %cpu= -p "$pid" | tr -d ' ')"
    total="$(awk -v t="$total" -v v="$value" 'BEGIN { printf "%.4f", t + v }')"
    peak="$(awk -v p="$peak" -v v="$value" 'BEGIN { print (v > p ? v : p) }')"
    samples=$((samples + 1))
    sleep 1
done

awk -v t="$total" -v n="$samples" -v p="$peak" -v s="$seconds" -v pid="$pid" 'BEGIN {
    printf "topd pid %s: average CPU %.2f%% over %d s (peak sample %.2f%%)\n", pid, t / n, s, p
}'
