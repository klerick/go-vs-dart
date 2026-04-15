#!/usr/bin/env bash
set -euo pipefail

# Local benchmark: runs k6 against all (or selected) services via docker-compose ports.
# Usage:
#   ./scripts/bench-local.sh                    # all services, default 50 VUS, 1 round
#   ./scripts/bench-local.sh 100                # all services, 100 VUS
#   ./scripts/bench-local.sh 50 go-service      # single service, 50 VUS
#   ./scripts/bench-local.sh 50 go-service axum-service   # selected services
#
# Environment:
#   ROUNDS=3        — run each service N times, report median (default: 1)
#   NO_WARMUP=1     — skip warm-up phase
#   NO_PG_RESTART=1 — skip Postgres restart between services

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BENCH_SCRIPT="$PROJECT_DIR/bench/k6-bench.js"
WARMUP_SCRIPT="$PROJECT_DIR/bench/k6-warmup.js"
RESULTS_DIR="$PROJECT_DIR/results/local"

VUS="${1:-50}"
shift 2>/dev/null || true

ROUNDS="${ROUNDS:-1}"
NO_WARMUP="${NO_WARMUP:-0}"
NO_PG_RESTART="${NO_PG_RESTART:-0}"

declare -A ALL_SERVICES=(
  [go-service]=8081
  [dart-service]=8082
  [axum-service]=8083
  [node-service]=8084
  [bun-service]=8085
  [deno-service]=8086
  [dotnet-service]=8087
  [nestjs-service]=8088
  [actix-service]=8089
)

# Build target list
if [ $# -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=(go-service dart-service axum-service node-service bun-service deno-service dotnet-service nestjs-service actix-service)
fi

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SUMMARY="$RESULTS_DIR/summary_${TIMESTAMP}.csv"
echo "service,round,vus,rps,avg_ms,p95_ms,p99_ms,max_ms,fail_pct" > "$SUMMARY"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

restart_postgres() {
  if [ "$NO_PG_RESTART" = "1" ]; then
    return
  fi
  log "  Restarting Postgres for clean buffer pool..."
  docker compose restart postgres > /dev/null 2>&1
  # Wait for Postgres to accept connections
  local retries=0
  while ! docker compose exec -T postgres pg_isready -U bench > /dev/null 2>&1; do
    retries=$((retries + 1))
    if [ $retries -ge 30 ]; then
      log "  WARNING: Postgres not ready after 30s"
      break
    fi
    sleep 1
  done
  sleep 2
  log "  Postgres ready"
}

reset_data() {
  log "  Resetting orders table + flushing Redis order cache..."
  docker compose exec -T postgres psql -U bench -d bench -c "
    TRUNCATE orders RESTART IDENTITY;
    INSERT INTO orders (user_id, product_id, quantity, total, created_at)
    SELECT
      (random() * 99 + 1)::int,
      (random() * 99 + 1)::int,
      (random() * 4 + 1)::int,
      (random() * 500 + 1)::numeric(10,2),
      NOW() - (random() * interval '90 days')
    FROM generate_series(1, 100000);
    ANALYZE orders;
  " > /dev/null 2>&1
  # Flush order_cache:* keys left by previous service (user:* keys are preserved)
  docker compose exec -T redis redis-cli --scan --pattern 'order_cache:*' | \
    xargs -r docker compose exec -T redis redis-cli DEL > /dev/null 2>&1 || true
  log "  Data reset complete"
}

run_warmup() {
  local base_url="$1"
  if [ "$NO_WARMUP" = "1" ]; then
    return
  fi
  log "  Warm-up: 10 VUS x 10s (results discarded)..."
  k6 run --quiet \
    -e BASE_URL="$base_url" \
    "$WARMUP_SCRIPT" > /dev/null 2>&1 || true
  sleep 2
  log "  Warm-up complete"
}

run_bench() {
  local svc="$1" port="$2" vus="$3" round="$4"
  local base_url="http://localhost:$port"
  local json_out="$RESULTS_DIR/${svc}_vus${vus}_r${round}_${TIMESTAMP}.json"

  # Health check
  if ! curl -sf --max-time 3 "$base_url/health" > /dev/null 2>&1; then
    log "  SKIP $svc — not reachable on port $port"
    echo "$svc,$round,$vus,0,0,0,0,0,100" >> "$SUMMARY"
    return
  fi

  log "  Running k6: $svc @ $vus VUS (round $round)..."
  k6 run --quiet \
    --summary-export="$json_out" \
    -e BASE_URL="$base_url" \
    -e VUS="$vus" \
    "$BENCH_SCRIPT" > "$RESULTS_DIR/${svc}_vus${vus}_r${round}_${TIMESTAMP}.log" 2>&1 || true

  if [ ! -f "$json_out" ]; then
    log "  FAIL $svc — no k6 output"
    echo "$svc,$round,$vus,0,0,0,0,0,100" >> "$SUMMARY"
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

  echo "$svc,$round,$vus,$rps,$avg,$p95,$p99,$maxl,$fail" >> "$SUMMARY"
  log "  $svc [r$round]: RPS=$rps  avg=${avg}ms  p95=${p95}ms  p99=${p99}ms  max=${maxl}ms  fail=${fail}%"
}

log "========================================="
log "Local benchmark — VUS=$VUS  ROUNDS=$ROUNDS"
log "Services: ${TARGETS[*]}"
log "Warm-up: $([ "$NO_WARMUP" = "1" ] && echo "OFF" || echo "10 VUS x 10s")"
log "PG restart: $([ "$NO_PG_RESTART" = "1" ] && echo "OFF" || echo "between services")"
log "========================================="

for svc in "${TARGETS[@]}"; do
  port="${ALL_SERVICES[$svc]:-}"
  if [ -z "$port" ]; then
    log "Unknown service: $svc — skipping"
    continue
  fi

  log ""
  log "── $svc (localhost:$port) ──"

  # Restart Postgres for clean buffer pool
  restart_postgres

  # Stop all app services, start only the one under test
  log "  Isolating $svc..."
  for other in "${!ALL_SERVICES[@]}"; do
    docker compose stop "$other" > /dev/null 2>&1 || true
  done
  docker compose up -d "$svc" > /dev/null 2>&1
  sleep 3

  reset_data
  sleep 3

  # Warm up Postgres buffer pool + connection pools + runtime JIT
  run_warmup "http://localhost:$port"

  for round in $(seq 1 "$ROUNDS"); do
    if [ "$ROUNDS" -gt 1 ]; then
      log ""
      log "  --- Round $round/$ROUNDS ---"
      # Reset data between rounds (but no PG restart — already warm)
      reset_data
      sleep 2
    fi
    run_bench "$svc" "$port" "$VUS" "$round"
  done
done

log ""
log "========================================="
log "Results: $SUMMARY"
log "========================================="

# Print table
echo ""
if [ "$ROUNDS" -gt 1 ]; then
  # Multi-round: show all rounds + median RPS per service
  printf "%-16s %5s %5s %7s %8s %8s %8s %8s %7s\n" "SERVICE" "ROUND" "VUS" "RPS" "AVG(ms)" "P95(ms)" "P99(ms)" "MAX(ms)" "FAIL%"
  printf "%-16s %5s %5s %7s %8s %8s %8s %8s %7s\n" "────────────────" "─────" "─────" "───────" "────────" "────────" "────────" "────────" "───────"
  tail -n +2 "$SUMMARY" | while IFS=, read -r svc round vus rps avg p95 p99 maxl fail; do
    printf "%-16s %5s %5s %7s %8s %8s %8s %8s %6s%%\n" "$svc" "$round" "$vus" "$rps" "$avg" "$p95" "$p99" "$maxl" "$fail"
  done

  echo ""
  echo "── Median RPS by service ──"
  printf "%-16s %7s\n" "SERVICE" "MEDIAN"
  printf "%-16s %7s\n" "────────────────" "───────"
  for svc in "${TARGETS[@]}"; do
    median=$(tail -n +2 "$SUMMARY" | grep "^$svc," | cut -d, -f4 | sort -n | awk '{ a[NR]=$1 } END { if (NR%2==1) print a[(NR+1)/2]; else printf "%.0f\n", (a[NR/2]+a[NR/2+1])/2 }')
    printf "%-16s %7s\n" "$svc" "${median:-0}"
  done
else
  # Single round: compact table sorted by RPS
  printf "%-16s %5s %7s %8s %8s %8s %8s %7s\n" "SERVICE" "VUS" "RPS" "AVG(ms)" "P95(ms)" "P99(ms)" "MAX(ms)" "FAIL%"
  printf "%-16s %5s %7s %8s %8s %8s %8s %7s\n" "────────────────" "─────" "───────" "────────" "────────" "────────" "────────" "───────"
  tail -n +2 "$SUMMARY" | sort -t, -k4 -rn | while IFS=, read -r svc round vus rps avg p95 p99 maxl fail; do
    printf "%-16s %5s %7s %8s %8s %8s %8s %6s%%\n" "$svc" "$vus" "$rps" "$avg" "$p95" "$p99" "$maxl" "$fail"
  done
fi
echo ""
