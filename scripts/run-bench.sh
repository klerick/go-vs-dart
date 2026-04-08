#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="bench"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"
BENCH_DIR="$PROJECT_DIR/bench"
RESULTS_DIR="$PROJECT_DIR/results"

mkdir -p "$RESULTS_DIR"

PROFILES=(
  "micro:100m:32Mi"
  "hobby:250m:64Mi"
  "prod:1000m:256Mi"
)

VUS_LEVELS=(10 50 100 500)

SERVICE_TARGET="${1:-both}"
PROFILE_TARGET="${2:-all}"

REPORT_FILE="$RESULTS_DIR/report.md"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

wait_for_ready() {
  local deploy=$1
  log "Waiting for $deploy to be ready..."
  if ! kubectl -n "$NAMESPACE" rollout status deployment/"$deploy" --timeout=120s 2>&1; then
    log "WARNING: $deploy not ready, checking pod status..."
    kubectl -n "$NAMESPACE" get pods -l app="$deploy" 2>&1
    return 1
  fi
}

patch_resources() {
  local deploy=$1 cpu=$2 mem=$3
  log "Patching $deploy: cpu=$cpu mem=$mem"
  kubectl -n "$NAMESPACE" patch deployment "$deploy" --type=json -p="[
    {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/cpu\", \"value\": \"$cpu\"},
    {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/limits/cpu\", \"value\": \"$cpu\"},
    {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/memory\", \"value\": \"$mem\"},
    {\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/limits/memory\", \"value\": \"$mem\"}
  ]" 2>&1
}

start_monitor() {
  local service=$1 profile=$2 vus=$3
  local metrics_file="$RESULTS_DIR/${service}_${profile}_vus${vus}_metrics.csv"
  echo "timestamp,pod,cpu,memory" > "$metrics_file"
  (
    while true; do
      kubectl -n "$NAMESPACE" top pods --no-headers 2>/dev/null | while read -r pod cpu mem; do
        echo "$(date +%s),$pod,$cpu,$mem" >> "$metrics_file"
      done
      sleep 5
    done
  ) &
  echo $!
}

run_k6() {
  local service=$1 profile=$2 vus=$3 base_url=$4
  local summary_file="$RESULTS_DIR/${service}_${profile}_vus${vus}_summary.json"
  local log_file="$RESULTS_DIR/${service}_${profile}_vus${vus}.log"
  log ">>> k6: service=$service profile=$profile vus=$vus"

  # Start resource monitoring
  local monitor_pid
  monitor_pid=$(start_monitor "$service" "$profile" "$vus")

  # Run k6
  k6 run \
    --summary-export="$summary_file" \
    -e BASE_URL="$base_url" \
    -e VUS="$vus" \
    "$BENCH_DIR/k6-bench.js" \
    > "$log_file" 2>&1

  local k6_exit=$?

  # Stop monitoring
  kill "$monitor_pid" 2>/dev/null
  wait "$monitor_pid" 2>/dev/null

  # Extract key metrics from summary
  if [ $k6_exit -eq 0 ] && [ -f "$summary_file" ]; then
    local rps avg p95 max_lat
    rps=$(python3 -c "import json; d=json.load(open('$summary_file')); print(f\"{d['metrics']['http_reqs']['values']['rate']:.0f}\")" 2>/dev/null || echo "N/A")
    avg=$(python3 -c "import json; d=json.load(open('$summary_file')); print(f\"{d['metrics']['http_req_duration']['values']['avg']:.1f}\")" 2>/dev/null || echo "N/A")
    p95=$(python3 -c "import json; d=json.load(open('$summary_file')); print(f\"{d['metrics']['http_req_duration']['values']['p(95)']:.1f}\")" 2>/dev/null || echo "N/A")
    max_lat=$(python3 -c "import json; d=json.load(open('$summary_file')); print(f\"{d['metrics']['http_req_duration']['values']['max']:.1f}\")" 2>/dev/null || echo "N/A")
    local fail_rate
    fail_rate=$(python3 -c "import json; d=json.load(open('$summary_file')); print(f\"{d['metrics']['http_req_failed']['values']['rate']*100:.1f}%\")" 2>/dev/null || echo "N/A")

    # Get resource usage
    local res_cpu res_mem
    res_cpu=$(kubectl -n "$NAMESPACE" top pods --no-headers 2>/dev/null | grep "$service" | awk '{print $2}' || echo "N/A")
    res_mem=$(kubectl -n "$NAMESPACE" top pods --no-headers 2>/dev/null | grep "$service" | awk '{print $3}' || echo "N/A")

    log "  RPS=$rps  avg=${avg}ms  p95=${p95}ms  max=${max_lat}ms  fail=$fail_rate  CPU=$res_cpu  MEM=$res_mem"

    # Append to report
    echo "| $service | $profile | $vus | $rps | ${avg}ms | ${p95}ms | ${max_lat}ms | $fail_rate | $res_cpu | $res_mem |" >> "$REPORT_FILE"
  else
    log "  FAILED or no summary (exit=$k6_exit)"
    local pod_status
    pod_status=$(kubectl -n "$NAMESPACE" get pods -l app="$service" --no-headers 2>/dev/null | awk '{print $3}')
    local restarts
    restarts=$(kubectl -n "$NAMESPACE" get pods -l app="$service" --no-headers 2>/dev/null | awk '{print $4}')
    log "  Pod status: $pod_status  Restarts: $restarts"
    echo "| $service | $profile | $vus | FAIL | - | - | - | - | $pod_status | restarts=$restarts |" >> "$REPORT_FILE"
  fi
}

get_service_url() {
  local svc=$1
  local local_port
  if [ "$svc" = "go-service" ]; then
    local_port=9090
  else
    local_port=9091
  fi
  pkill -f "port-forward.*svc/$svc" 2>/dev/null || true
  sleep 1
  kubectl -n "$NAMESPACE" port-forward "svc/$svc" "$local_port:8080" > /dev/null 2>&1 &
  sleep 3
  echo "http://localhost:$local_port"
}

cleanup_portforward() {
  pkill -f "port-forward.*svc/go-service" 2>/dev/null || true
  pkill -f "port-forward.*svc/dart-service" 2>/dev/null || true
}
trap cleanup_portforward EXIT

reset_orders() {
  log "Resetting orders to 100k..."
  kubectl -n "$NAMESPACE" delete job reset-data --ignore-not-found 2>/dev/null
  kubectl apply -f "$K8S_DIR/reset-job.yaml" 2>/dev/null
  if ! kubectl -n "$NAMESPACE" wait --for=condition=complete job/reset-data --timeout=120s 2>/dev/null; then
    log "WARNING: reset job may have failed"
  fi
  kubectl -n "$NAMESPACE" delete job reset-data --ignore-not-found 2>/dev/null
  log "Orders reset complete."
}

# Init report
cat > "$REPORT_FILE" <<'EOF'
# Go vs Dart Benchmark Results

## Environment
- Cluster: RPi5 (ARM64), Talos k8s
- Services on: rpi5-app-0
- Postgres + Redis on: vm-worker-0
- Data: 100k orders, 100 products, 100 users
- Traffic mix: 50% GET single, 30% GET list, 20% POST create
- k6 ramp: 10s up → 30s sustain → 10s down

## Results

| Service | Profile | VUS | RPS | avg | p95 | max | fail% | CPU | Memory |
|---------|---------|-----|-----|-----|-----|-----|-------|-----|--------|
EOF

log "Starting full benchmark run..."

for profile_str in "${PROFILES[@]}"; do
  IFS=: read -r profile cpu mem <<< "$profile_str"

  if [ "$PROFILE_TARGET" != "all" ] && [ "$PROFILE_TARGET" != "$profile" ]; then
    continue
  fi

  log "========== Profile: $profile (cpu=$cpu mem=$mem) =========="

  services=()
  if [ "$SERVICE_TARGET" = "both" ] || [ "$SERVICE_TARGET" = "go" ]; then
    services+=("go-service")
  fi
  if [ "$SERVICE_TARGET" = "both" ] || [ "$SERVICE_TARGET" = "dart" ]; then
    services+=("dart-service")
  fi

  for svc in "${services[@]}"; do
    patch_resources "$svc" "$cpu" "$mem"
    if ! wait_for_ready "$svc"; then
      log "SKIPPING $svc on $profile - not ready"
      continue
    fi
    sleep 5

    base_url=$(get_service_url "$svc")

    # Health check with retries
    healthy=false
    for i in 1 2 3 4 5; do
      if curl -sf "$base_url/health" > /dev/null 2>&1; then
        healthy=true
        break
      fi
      sleep 2
    done

    if [ "$healthy" != "true" ]; then
      log "ERROR: $svc health check failed at $base_url"
      cleanup_portforward
      echo "| $svc | $profile | ALL | HEALTH_FAIL | - | - | - | - | - | - |" >> "$REPORT_FILE"
      continue
    fi

    for vus in "${VUS_LEVELS[@]}"; do
      reset_orders
      sleep 2
      run_k6 "$svc" "$profile" "$vus" "$base_url"
      sleep 3
    done

    cleanup_portforward
  done
done

# Restore prod limits
log "Restoring prod limits..."
for svc in go-service dart-service; do
  patch_resources "$svc" "1000m" "256Mi" 2>/dev/null
done

log "All benchmarks complete!"
log "Report: $REPORT_FILE"
cat "$REPORT_FILE"
