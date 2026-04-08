#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/generate-comparison.sh <name>_vs_<name>[_vs_<name>...]
# Example: ./scripts/generate-comparison.sh go_vs_node_vs_dart-redis310
# Reads results/benchmarks/<service>/<cpu>/summary.csv for each service
# Generates results/comparisons/<name>_vs_<name>...md

NAME="${1:?Usage: generate-comparison.sh <svc1>_vs_<svc2>[_vs_...]}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPARISONS_DIR="$PROJECT_DIR/results/comparisons"
mkdir -p "$COMPARISONS_DIR"

OUT="$COMPARISONS_DIR/$NAME.md"

# Parse names
IFS='_' read -ra PARTS <<< "$NAME"
SERVICES=()
i=0
while [ $i -lt ${#PARTS[@]} ]; do
  if [ "${PARTS[$i]}" = "vs" ]; then
    i=$((i+1))
    continue
  fi
  SERVICES+=("${PARTS[$i]}")
  i=$((i+1))
done

if [ ${#SERVICES[@]} -lt 2 ]; then
  echo "Error: need at least 2 services (got: ${SERVICES[*]})"
  exit 1
fi

# Verify all exist
for svc in "${SERVICES[@]}"; do
  if [ ! -d "$PROJECT_DIR/results/benchmarks/$svc" ]; then
    echo "Error: results/benchmarks/$svc not found"
    exit 1
  fi
done

python3 - "$PROJECT_DIR" "$OUT" "${SERVICES[@]}" <<'PY'
import csv
import sys
import re
import os
from statistics import median

project_dir = sys.argv[1]
out_file = sys.argv[2]
services = sys.argv[3:]
benchmarks_dir = os.path.join(project_dir, 'results', 'benchmarks')

def parse_mem(s):
    if not s or s == 'N/A': return None
    m = re.match(r'(\d+)', s)
    return int(m.group(1)) if m else None

def parse_cpu(s):
    if not s or s == 'N/A': return None
    if s.endswith('m'): return int(s[:-1])
    if s.endswith('k'): return int(s[:-1]) * 1_000_000
    try: return int(float(s) * 1000)
    except ValueError: return None

def median_int(values):
    valid = [v for v in values if v is not None]
    return int(median(valid)) if valid else None

def median_float(values):
    valid = [v for v in values if v is not None]
    return round(median(valid), 1) if valid else None

# Collect data: data[service][profile][vus] = {rps, p95, mem_peak, ...}
data = {}
for svc in services:
    svc_dir = os.path.join(benchmarks_dir, svc)
    profiles = {}
    for prof in ['1000m', '250m', '100m']:
        csv_path = os.path.join(svc_dir, prof, 'summary.csv')
        rec_path = os.path.join(svc_dir, prof, 'recovery.csv')
        if not os.path.exists(csv_path):
            continue

        rows = []
        with open(csv_path) as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        vus_groups = {}
        for r in rows:
            v = int(r['vus'])
            vus_groups.setdefault(v, []).append(r)

        vus_data = {}
        for vus, runs in vus_groups.items():
            vus_data[vus] = {
                'rps': median_int([float(r['rps']) for r in runs]),
                'p95': median_float([float(r['p95_ms']) for r in runs]),
                'mem_peak': median_int([parse_mem(r['mem_peak']) for r in runs]),
                'cpu_peak': median_int([parse_cpu(r['cpu_peak']) for r in runs]),
            }

        recovery = {}
        if os.path.exists(rec_path):
            with open(rec_path) as f:
                rec_rows = list(csv.DictReader(f))
            if rec_rows:
                recovery = {
                    'after': median_int([parse_mem(r['mem_after_500vus']) for r in rec_rows]),
                    'mem_60s': median_int([parse_mem(r['mem_60s']) for r in rec_rows]),
                    'mem_300s': median_int([parse_mem(r['mem_300s']) for r in rec_rows]),
                    'restarts': max(int(r.get('restarts', 0) or 0) for r in rec_rows),
                }

        idle = parse_mem(rows[0]['mem_before']) if rows else None
        profiles[prof] = {'vus': vus_data, 'recovery': recovery, 'idle': idle}
    data[svc] = profiles

with open(out_file, 'w') as f:
    title = ' vs '.join(services)
    f.write(f"# {title}\n\n")
    f.write("> Median across 3 runs. Higher RPS / lower latency / lower memory = better.\n\n")

    for prof in ['1000m', '250m', '100m']:
        # Skip if none of services have this profile
        if not any(prof in data[svc] for svc in services):
            continue

        f.write(f"## {prof} CPU\n\n")

        # RPS
        f.write("### RPS\n\n")
        f.write("| VUS | " + " | ".join(services) + " |\n")
        f.write("|-----|" + "---|" * len(services) + "\n")
        for vus in [10, 50, 100, 500]:
            row = [f"| {vus}"]
            best_rps = max((data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('rps') or 0) for svc in services)
            for svc in services:
                v = data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('rps')
                if v is None:
                    row.append(" - ")
                elif v == best_rps and best_rps > 0:
                    row.append(f" **{v}** ")
                else:
                    row.append(f" {v} ")
            f.write("|".join(row) + "|\n")

        # Latency p95
        f.write("\n### Latency p95 (ms)\n\n")
        f.write("| VUS | " + " | ".join(services) + " |\n")
        f.write("|-----|" + "---|" * len(services) + "\n")
        for vus in [10, 50, 100, 500]:
            row = [f"| {vus}"]
            for svc in services:
                v = data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('p95')
                row.append(f" {v if v is not None else '-'} ")
            f.write("|".join(row) + "|\n")

        # Memory peak
        f.write("\n### Memory Peak (Mi)\n\n")
        f.write("| VUS | " + " | ".join(services) + " |\n")
        f.write("|-----|" + "---|" * len(services) + "\n")
        for vus in [10, 50, 100, 500]:
            row = [f"| {vus}"]
            valid = [(data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('mem_peak')) for svc in services]
            valid = [v for v in valid if v is not None]
            best_mem = min(valid) if valid else None
            for svc in services:
                v = data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('mem_peak')
                if v is None:
                    row.append(" - ")
                elif v == best_mem:
                    row.append(f" **{v}Mi** ")
                else:
                    row.append(f" {v}Mi ")
            f.write("|".join(row) + "|\n")

        # CPU usage
        f.write("\n### CPU usage (millicores)\n\n")
        f.write("| VUS | " + " | ".join(services) + " |\n")
        f.write("|-----|" + "---|" * len(services) + "\n")
        for vus in [10, 50, 100, 500]:
            row = [f"| {vus}"]
            for svc in services:
                v = data[svc].get(prof, {}).get('vus', {}).get(vus, {}).get('cpu_peak')
                row.append(f" {v if v is not None else '-'}m ")
            f.write("|".join(row) + "|\n")

        # CPU efficiency: RPS per 100m CPU at 500 VUS
        f.write("\n### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)\n\n")
        f.write("| Service | RPS | CPU used | RPS / 100m CPU |\n")
        f.write("|---------|-----|----------|----------------|\n")
        eff_rows = []
        for svc in services:
            v = data[svc].get(prof, {}).get('vus', {}).get(500, {})
            rps = v.get('rps')
            cpu = v.get('cpu_peak')
            if rps and cpu and cpu > 0:
                eff = round(rps / cpu * 100, 1)
                eff_rows.append((svc, rps, cpu, eff))
            else:
                eff_rows.append((svc, rps, cpu, None))
        # Find best
        best_eff = max((r[3] for r in eff_rows if r[3] is not None), default=None)
        for svc, rps, cpu, eff in eff_rows:
            rps_str = str(rps) if rps is not None else '-'
            cpu_str = f"{cpu}m" if cpu is not None else '-'
            if eff is None:
                eff_str = '-'
            elif eff == best_eff:
                eff_str = f"**{eff}**"
            else:
                eff_str = str(eff)
            f.write(f"| {svc} | {rps_str} | {cpu_str} | {eff_str} |\n")

        # Idle + Recovery
        f.write("\n### Memory: idle / peak / recovery (500 VUS)\n\n")
        f.write("> **Returned**: how much of the allocated memory above idle was released back. Formula: `(peak - after_300s) / (peak - idle)`. 100% = back to baseline, 0% = nothing released.\n\n")
        f.write("| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |\n")
        f.write("|---------|------|------|-----------|------------|----------|----------|\n")
        for svc in services:
            d = data[svc].get(prof, {})
            idle = d.get('idle')
            peak = d.get('vus', {}).get(500, {}).get('mem_peak')
            rec = d.get('recovery', {})
            after_60 = rec.get('mem_60s')
            after_300 = rec.get('mem_300s')
            restarts = rec.get('restarts', 0)
            returned = ''
            if peak is not None and after_300 is not None and idle is not None:
                allocated = peak - idle
                if allocated > 0:
                    released = peak - after_300
                    pct = round(released / allocated * 100)
                    returned = f"{pct}%"
                else:
                    returned = "-"
            f.write(f"| {svc} | {idle or '-'}Mi | {peak or '-'}Mi | {after_60 or '-'}Mi | {after_300 or '-'}Mi | {returned or '-'} | {restarts} |\n")

        f.write("\n---\n\n")

print(f"Generated: {out_file}")
PY
