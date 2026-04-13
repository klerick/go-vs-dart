#!/usr/bin/env bash
set -euo pipefail

# Smoke test all services via docker-compose ports.
# Usage: ./scripts/smoke-test.sh [service-name]

declare -A SERVICES=(
  [go-service]=8081
  [dart-service]=8082
  [axum-service]=8083
  [node-service]=8084
  [bun-service]=8085
  [deno-service]=8086
  [dotnet-service]=8087
  [nestjs-service]=8088
)

FILTER="${1:-}"
PASS=0
FAIL=0

red()   { printf '\033[31m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
bold()  { printf '\033[1m%s\033[0m' "$*"; }

check() {
  local label="$1" url="$2" method="${3:-GET}" body="${4:-}" expect_status="${5:-200}"
  local args=(-s -o /dev/null -w '%{http_code}' --max-time 5)

  if [ "$method" = "POST" ]; then
    args+=(-X POST -H 'Content-Type: application/json' -d "$body")
  fi

  local status
  status=$(curl "${args[@]}" "$url" 2>/dev/null || true)

  if [ "$status" = "$expect_status" ]; then
    echo "  $(green "✓") $label ($status)"
    PASS=$((PASS + 1))
  else
    echo "  $(red "✗") $label (got $status, expected $expect_status)"
    FAIL=$((FAIL + 1))
  fi
}

for svc in $(echo "${!SERVICES[@]}" | tr ' ' '\n' | sort); do
  port=${SERVICES[$svc]}

  if [ -n "$FILTER" ] && [ "$FILTER" != "$svc" ]; then
    continue
  fi

  echo ""
  bold "── $svc (localhost:$port) ──"
  echo ""

  # Quick reachability check
  if ! curl -sf --max-time 3 "http://localhost:$port/health" > /dev/null 2>&1; then
    echo "  $(red "✗") not reachable — skipping"
    FAIL=$((FAIL + 1))
    continue
  fi

  check "GET  /health"              "http://localhost:$port/health"
  check "GET  /orders/1"            "http://localhost:$port/orders/1"
  check "GET  /orders?user_id=1"    "http://localhost:$port/orders?user_id=1"
  check "POST /orders (create)"     "http://localhost:$port/orders" \
        POST '{"user_id":1,"product_id":1,"quantity":2}' 201
  check "GET  /orders?user_id=bad"  "http://localhost:$port/orders?user_id=bad" \
        GET "" 400
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $(green "Passed: $PASS")  $([ "$FAIL" -gt 0 ] && red "Failed: $FAIL" || echo "Failed: 0")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ]
