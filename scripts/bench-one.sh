#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/bench-one.sh <service-name> <image-tag> <results-dir> [cpu-limit]
SERVICE="${1:?Usage: bench-one.sh <service-name> <image-tag> <results-dir> [cpu-limit]}"
IMAGE="${2:?Missing image tag}"
RESULTS_BASE="${3:?Missing results dir}"
CPU_LIMIT="${4:-1000m}"
RESULTS_DIR="$RESULTS_BASE/$CPU_LIMIT"

NAMESPACE="bench"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"
BENCH_SCRIPT="$PROJECT_DIR/bench/k6-bench.js"

VUS_LEVELS=(10 50 100 500)
RUNS=3
REGISTRY="${REGISTRY:-your-registry.example.com/library}"

mkdir -p "$RESULTS_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

get_mem() {
  kubectl -n "$NAMESPACE" top pods --no-headers 2>/dev/null | grep "$SERVICE" | awk '{print $3}' | head -1
}

get_cpu() {
  kubectl -n "$NAMESPACE" top pods --no-headers 2>/dev/null | grep "$SERVICE" | awk '{print $2}' | head -1
}

get_restarts() {
  kubectl -n "$NAMESPACE" get pods --no-headers 2>&1 | grep "$SERVICE" | awk '{print $4}' | head -1
}

reset_data() {
  kubectl -n "$NAMESPACE" delete job reset-data --ignore-not-found >/dev/null 2>&1
  kubectl apply -f "$K8S_DIR/reset-job.yaml" >/dev/null 2>&1
  kubectl -n "$NAMESPACE" wait --for=condition=complete job/reset-data --timeout=120s >/dev/null 2>&1
}

# Determine port
case "$SERVICE" in
  go-service)    LOCAL_PORT=9090 ;;
  node-service)  LOCAL_PORT=9090 ;;
  dart-service)  LOCAL_PORT=9091 ;;
  bun-service)   LOCAL_PORT=9092 ;;
  deno-service)  LOCAL_PORT=9093 ;;
  dotnet-service) LOCAL_PORT=9094 ;;
  nestjs-service) LOCAL_PORT=9095 ;;
  axum-service)  LOCAL_PORT=9096 ;;
  actix-service) LOCAL_PORT=9097 ;;
  *)             LOCAL_PORT=9090 ;;
esac

log "========================================="
log "Benchmark: $SERVICE ($IMAGE) CPU=$CPU_LIMIT"
log "Results: $RESULTS_DIR"
log "========================================="

# Deploy
log "Deploying $SERVICE..."
kubectl -n "$NAMESPACE" scale deployment "$SERVICE" --replicas=0 2>/dev/null || true
sleep 3

kubectl -n "$NAMESPACE" patch deployment "$SERVICE" --type=json -p="[
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/image\",\"value\":\"$REGISTRY/$IMAGE\"},
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/requests/cpu\",\"value\":\"$CPU_LIMIT\"},
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/limits/cpu\",\"value\":\"$CPU_LIMIT\"},
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/requests/memory\",\"value\":\"256Mi\"},
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/resources/limits/memory\",\"value\":\"256Mi\"},
  {\"op\":\"replace\",\"path\":\"/spec/replicas\",\"value\":1}
]" 2>&1 | grep -v "would violate"

kubectl -n "$NAMESPACE" rollout status deployment/"$SERVICE" --timeout=120s 2>&1 | tail -1

# Wait for stabilization
log "Waiting 60s for runtime stabilization..."
sleep 60

mem_after_start=$(get_mem)
log "Memory after start + 60s stabilization: $mem_after_start"

# Port forward
pkill -f "port-forward.*svc/$SERVICE" 2>/dev/null || true
sleep 1
kubectl -n "$NAMESPACE" port-forward "svc/$SERVICE" "$LOCAL_PORT:8080" >/dev/null 2>&1 &
sleep 3

# Health check
if ! curl -sf "http://localhost:$LOCAL_PORT/health" > /dev/null 2>&1; then
  log "ERROR: Health check failed!"
  exit 1
fi
log "Health check OK"

# Write header
SUMMARY="$RESULTS_DIR/summary.csv"
echo "run,vus,rps,avg_ms,p95_ms,max_ms,mem_before,mem_peak,cpu_peak" > "$SUMMARY"

# Recovery file
RECOVERY="$RESULTS_DIR/recovery.csv"
echo "run,mem_after_500vus,mem_60s,mem_120s,mem_180s,mem_240s,mem_300s,restarts" > "$RECOVERY"

# Benchmark loop
for run in $(seq 1 $RUNS); do
  log ""
  log "===== RUN $run/$RUNS ====="

  for vus in "${VUS_LEVELS[@]}"; do
    log ""
    log "--- Run $run, $vus VUS ---"

    # Reset data
    reset_data

    # Measure memory before
    mem_before=$(get_mem)

    # Monitor during test
    mon_file="/tmp/bench_mon_${SERVICE}_${run}_${vus}.txt"
    > "$mon_file"
    (while true; do
      echo "$(date +%s) $(get_cpu) $(get_mem)" >> "$mon_file"
      sleep 5
    done) &
    MON_PID=$!

    # Run k6
    k6_summary="$RESULTS_DIR/run${run}_vus${vus}.json"
    k6 run --summary-export="$k6_summary" \
      -e BASE_URL="http://localhost:$LOCAL_PORT" \
      -e VUS="$vus" \
      "$BENCH_SCRIPT" > "$RESULTS_DIR/run${run}_vus${vus}.log" 2>&1

    # Stop monitor
    kill $MON_PID 2>/dev/null || true
    wait $MON_PID 2>/dev/null || true

    # Peak memory/cpu from monitor
    mem_peak=$(awk '{print $3}' "$mon_file" 2>/dev/null | sort -t'M' -k1 -rn | head -1) || mem_peak="N/A"
    cpu_peak=$(awk '{print $2}' "$mon_file" 2>/dev/null | sort -t'm' -k1 -rn | head -1) || cpu_peak="N/A"
    rm -f "$mon_file"

    # Extract k6 metrics
    rps=$(python3 -c "import json; d=json.load(open('$k6_summary')); print(f\"{d['metrics']['http_reqs']['rate']:.0f}\")" 2>/dev/null || echo "0")
    avg=$(python3 -c "import json; d=json.load(open('$k6_summary')); print(f\"{d['metrics']['http_req_duration']['avg']:.1f}\")" 2>/dev/null || echo "0")
    p95=$(python3 -c "import json; d=json.load(open('$k6_summary')); print(f\"{d['metrics']['http_req_duration']['p(95)']:.1f}\")" 2>/dev/null || echo "0")
    maxl=$(python3 -c "import json; d=json.load(open('$k6_summary')); print(f\"{d['metrics']['http_req_duration']['max']:.1f}\")" 2>/dev/null || echo "0")

    log "  RPS=$rps avg=${avg}ms p95=${p95}ms max=${maxl}ms | mem: before=$mem_before peak=$mem_peak | cpu=$cpu_peak"

    # Write CSV
    echo "$run,$vus,$rps,$avg,$p95,$maxl,$mem_before,$mem_peak,$cpu_peak" >> "$SUMMARY"
  done

  # Recovery after all VUS levels (5 minutes)
  log ""
  log "--- Run $run RECOVERY (5 min after 500 VUS) ---"
  mem_right_after=$(get_mem)
  log "  0s: $mem_right_after"

  sleep 60; mem_60=$(get_mem); log "  60s: $mem_60"
  sleep 60; mem_120=$(get_mem); log "  120s: $mem_120"
  sleep 60; mem_180=$(get_mem); log "  180s: $mem_180"
  sleep 60; mem_240=$(get_mem); log "  240s: $mem_240"
  sleep 60; mem_300=$(get_mem); log "  300s: $mem_300"
  restarts=$(get_restarts)
  log "  Restarts: $restarts"

  echo "$run,$mem_right_after,$mem_60,$mem_120,$mem_180,$mem_240,$mem_300,$restarts" >> "$RECOVERY"
done

# Cleanup
pkill -f "port-forward.*svc/$SERVICE" 2>/dev/null || true

log ""
log "========================================="
log "Done! $SERVICE"
log "Idle memory: $mem_after_start"
log "========================================="
log ""
log "=== RPS ==="
cat "$SUMMARY"
log ""
log "=== RECOVERY ==="
cat "$RECOVERY"
