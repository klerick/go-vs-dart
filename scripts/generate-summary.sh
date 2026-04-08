#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/generate-summary.sh <service-name>
# Reads results/benchmarks/<service-name>/<cpu>/summary.csv and recovery.csv
# Generates results/benchmarks/<service-name>/summary.md with median across runs

SERVICE="${1:?Usage: generate-summary.sh <service-name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SVC_DIR="$PROJECT_DIR/results/benchmarks/$SERVICE"

if [ ! -d "$SVC_DIR" ]; then
  echo "Error: $SVC_DIR not found"
  exit 1
fi

OUT="$SVC_DIR/summary.md"

# Find available CPU profiles (subdirs with summary.csv)
PROFILES=()
for d in "$SVC_DIR"/*/; do
  [ -f "$d/summary.csv" ] && PROFILES+=("$(basename "$d")")
done

if [ ${#PROFILES[@]} -eq 0 ]; then
  echo "Error: no profile data in $SVC_DIR"
  exit 1
fi

# Sort profiles: 1000m, 250m, 100m
SORTED_PROFILES=()
for p in 1000m 250m 100m; do
  for x in "${PROFILES[@]}"; do
    [ "$x" = "$p" ] && SORTED_PROFILES+=("$p")
  done
done

# Python helper for median calculation
python3 - "$SVC_DIR" "$OUT" "${SORTED_PROFILES[@]}" <<'PY'
import csv
import sys
import re
import os
from statistics import median

svc_dir = sys.argv[1]
out_file = sys.argv[2]
profiles = sys.argv[3:]
service = os.path.basename(svc_dir)

def parse_mem(s):
    """Parse '37Mi' -> 37 (int)"""
    if not s or s == 'N/A':
        return None
    m = re.match(r'(\d+)', s)
    return int(m.group(1)) if m else None

def parse_cpu(s):
    """Parse '647m' or '1' -> int (millicores)"""
    if not s or s == 'N/A':
        return None
    if s.endswith('m'):
        return int(s[:-1])
    if s.endswith('k'):
        return int(s[:-1]) * 1_000_000
    try:
        return int(float(s) * 1000)
    except ValueError:
        return None

def median_int(values):
    valid = [v for v in values if v is not None]
    return int(median(valid)) if valid else None

def median_float(values):
    valid = [v for v in values if v is not None]
    return round(median(valid), 1) if valid else None

# Collect data per profile
data = {}
for profile in profiles:
    csv_path = os.path.join(svc_dir, profile, 'summary.csv')
    rec_path = os.path.join(svc_dir, profile, 'recovery.csv')

    rows = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    # Group by VUS
    vus_groups = {}
    for r in rows:
        vus = int(r['vus'])
        if vus not in vus_groups:
            vus_groups[vus] = []
        vus_groups[vus].append(r)

    # Calculate medians
    vus_medians = {}
    for vus, runs in vus_groups.items():
        vus_medians[vus] = {
            'rps': median_int([float(r['rps']) for r in runs]),
            'avg': median_float([float(r['avg_ms']) for r in runs]),
            'p95': median_float([float(r['p95_ms']) for r in runs]),
            'max': median_float([float(r['max_ms']) for r in runs]),
            'mem_peak': median_int([parse_mem(r['mem_peak']) for r in runs]),
            'cpu_peak': median_int([parse_cpu(r['cpu_peak']) for r in runs]),
        }

    # Recovery data
    recovery = {}
    if os.path.exists(rec_path):
        with open(rec_path) as f:
            reader = csv.DictReader(f)
            rec_rows = list(reader)
        if rec_rows:
            recovery = {
                'after_500vus': median_int([parse_mem(r['mem_after_500vus']) for r in rec_rows]),
                'mem_60s': median_int([parse_mem(r['mem_60s']) for r in rec_rows]),
                'mem_120s': median_int([parse_mem(r['mem_120s']) for r in rec_rows]),
                'mem_180s': median_int([parse_mem(r['mem_180s']) for r in rec_rows]),
                'mem_240s': median_int([parse_mem(r['mem_240s']) for r in rec_rows]),
                'mem_300s': median_int([parse_mem(r['mem_300s']) for r in rec_rows]),
                'restarts': max(int(r.get('restarts', 0) or 0) for r in rec_rows),
            }

    # Idle memory: take mem_before of run 1, vus 10 (first row)
    idle = parse_mem(rows[0]['mem_before']) if rows else None

    data[profile] = {
        'vus': vus_medians,
        'recovery': recovery,
        'idle': idle,
    }

# Generate markdown
with open(out_file, 'w') as f:
    f.write(f"# {service} — Benchmark Summary\n\n")
    f.write("> Median across 3 runs. See raw CSV files in each profile directory.\n\n")

    # RPS table
    f.write("## RPS (median, higher = better)\n\n")
    f.write("| VUS | " + " | ".join(profiles) + " |\n")
    f.write("|-----|" + "---|" * len(profiles) + "\n")
    for vus in [10, 50, 100, 500]:
        row = [f"| {vus}"]
        for p in profiles:
            v = data[p]['vus'].get(vus, {}).get('rps')
            row.append(f" {v if v is not None else '-'} ")
        f.write("|".join(row) + "|\n")

    # Latency p95
    f.write("\n## Latency p95 (median ms, lower = better)\n\n")
    f.write("| VUS | " + " | ".join(profiles) + " |\n")
    f.write("|-----|" + "---|" * len(profiles) + "\n")
    for vus in [10, 50, 100, 500]:
        row = [f"| {vus}"]
        for p in profiles:
            v = data[p]['vus'].get(vus, {}).get('p95')
            row.append(f" {v if v is not None else '-'} ")
        f.write("|".join(row) + "|\n")

    # Memory peak
    f.write("\n## Memory Peak (median Mi)\n\n")
    f.write("| VUS | " + " | ".join(profiles) + " |\n")
    f.write("|-----|" + "---|" * len(profiles) + "\n")
    for vus in [10, 50, 100, 500]:
        row = [f"| {vus}"]
        for p in profiles:
            v = data[p]['vus'].get(vus, {}).get('mem_peak')
            row.append(f" {v if v is not None else '-'}Mi ")
        f.write("|".join(row) + "|\n")

    # CPU usage
    f.write("\n## CPU Usage (median, millicores)\n\n")
    f.write("| VUS | " + " | ".join(profiles) + " |\n")
    f.write("|-----|" + "---|" * len(profiles) + "\n")
    for vus in [10, 50, 100, 500]:
        row = [f"| {vus}"]
        for p in profiles:
            v = data[p]['vus'].get(vus, {}).get('cpu_peak')
            row.append(f" {v if v is not None else '-'}m ")
        f.write("|".join(row) + "|\n")

    # Idle memory
    f.write("\n## Idle Memory (after 60s stabilization)\n\n")
    f.write("| Profile | Memory |\n")
    f.write("|---------|--------|\n")
    for p in profiles:
        v = data[p]['idle']
        f.write(f"| {p} | {v if v is not None else '-'}Mi |\n")

    # Recovery
    f.write("\n## Memory Recovery after 500 VUS (median Mi)\n\n")
    f.write("| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |\n")
    f.write("|---------|------------|-----|------|------|------|------|----------|\n")
    for p in profiles:
        r = data[p]['recovery']
        if not r:
            continue
        f.write(f"| {p} | {r.get('after_500vus','-')}Mi | {r.get('mem_60s','-')}Mi | {r.get('mem_120s','-')}Mi | {r.get('mem_180s','-')}Mi | {r.get('mem_240s','-')}Mi | {r.get('mem_300s','-')}Mi | {r.get('restarts',0)} |\n")

print(f"Generated: {out_file}")
PY
