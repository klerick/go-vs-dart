#!/usr/bin/env bash
set -euo pipefail

# Local benchmark: runs k6 against all (or selected) services via docker-compose ports.
# Usage:
#   ./scripts/bench-local.sh                    # all services, default 50 VUS
#   ./scripts/bench-local.sh 100                # all services, 100 VUS
#   ./scripts/bench-local.sh 50 go-service      # single service, 50 VUS
#   ./scripts/bench-local.sh 50 go-service axum-service   # selected services

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BENCH_SCRIPT="$PROJECT_DIR/bench/k6-bench.js"
RESULTS_DIR="$PROJECT_DIR/results/local"

VUS="${1:-50}"
shift 2>/dev/null || true

declare -A ALL_SERVICES=(
  [go-service]=8081
  [dart-service]=8082
  [axum-service]=8083
  [node-service]=8084
  [bun-service]=8085
  [deno-service]=8086
  [dotnet-service]=8087
  [nestjs-service]=8088
)

# Build target list
if [ $# -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=(go-service dart-service axum-service node-service bun-service deno-service dotnet-service nestjs-service)
fi

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SUMMARY="$RESULTS_DIR/summary_${TIMESTAMP}.csv"
echo "service,vus,rps,avg_ms,p95_ms,p99_ms,max_ms,fail_pct" > "$SUMMARY"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

run_bench() {
  local svc="$1" port="$2" vus="$3"
  local base_url="http://localhost:$port"
  local json_out="$RESULTS_DIR/${svc}_vus${vus}_${TIMESTAMP}.json"

  # Health check
  if ! curl -sf --max-time 3 "$base_url/health" > /dev/null 2>&1; then
    log "  SKIP $svc — not reachable on port $port"
    echo "$svc,$vus,0,0,0,0,0,100" >> "$SUMMARY"
    return
  fi

  log "  Running k6: $svc @ $vus VUS ..."
  k6 run --quiet \
    --summary-export="$json_out" \
    -e BASE_URL="$base_url" \
    -e VUS="$vus" \
    "$BENCH_SCRIPT" > "$RESULTS_DIR/${svc}_vus${vus}_${TIMESTAMP}.log" 2>&1 || true

  if [ ! -f "$json_out" ]; then
    log "  FAIL $svc — no k6 output"
    echo "$svc,$vus,0,0,0,0,0,100" >> "$SUMMARY"
    return
  fi

  # Extract metrics
  local rps avg p95 p99 maxl fail
  rps=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_reqs']['rate']:.0f}\")" 2>/dev/null || echo "0")
  avg=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_req_duration']['avg']:.2f}\")" 2>/dev/null || echo "0")
  p95=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_req_duration']['p(95)']:.2f}\")" 2>/dev/null || echo "0")
  p99=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_req_duration']['p(99)']:.2f}\")" 2>/dev/null || echo "0")
  maxl=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_req_duration']['max']:.2f}\")" 2>/dev/null || echo "0")
  fail=$(python3 -c "import json; d=json.load(open('$json_out')); print(f\"{d['metrics']['http_req_failed']['rate']*100:.1f}\")" 2>/dev/null || echo "0")

  echo "$svc,$vus,$rps,$avg,$p95,$p99,$maxl,$fail" >> "$SUMMARY"
  log "  $svc: RPS=$rps  avg=${avg}ms  p95=${p95}ms  p99=${p99}ms  max=${maxl}ms  fail=${fail}%"
}

log "========================================="
log "Local benchmark — VUS=$VUS"
log "Services: ${TARGETS[*]}"
log "========================================="

for svc in "${TARGETS[@]}"; do
  port="${ALL_SERVICES[$svc]:-}"
  if [ -z "$port" ]; then
    log "Unknown service: $svc — skipping"
    continue
  fi

  log ""
  log "── $svc (localhost:$port) ──"
  run_bench "$svc" "$port" "$VUS"
done

log ""
log "========================================="
log "Results: $SUMMARY"
log "========================================="

# Print table
echo ""
printf "%-16s %5s %7s %8s %8s %8s %8s %7s\n" "SERVICE" "VUS" "RPS" "AVG(ms)" "P95(ms)" "P99(ms)" "MAX(ms)" "FAIL%"
printf "%-16s %5s %7s %8s %8s %8s %8s %7s\n" "────────────────" "─────" "───────" "────────" "────────" "────────" "────────" "───────"
tail -n +2 "$SUMMARY" | sort -t, -k3 -rn | while IFS=, read -r svc vus rps avg p95 p99 maxl fail; do
  printf "%-16s %5s %7s %8s %8s %8s %8s %6s%%\n" "$svc" "$vus" "$rps" "$avg" "$p95" "$p99" "$maxl" "$fail"
done
echo ""
