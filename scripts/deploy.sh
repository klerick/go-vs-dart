#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s"
NAMESPACE="bench"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

log "Deploying PostgreSQL..."
kubectl apply -f "$K8S_DIR/postgres.yaml"

log "Deploying Redis..."
kubectl apply -f "$K8S_DIR/redis.yaml"

log "Waiting for PostgreSQL to be ready..."
kubectl -n "$NAMESPACE" rollout status deployment/postgres --timeout=120s

log "Waiting for Redis to be ready..."
kubectl -n "$NAMESPACE" rollout status deployment/redis --timeout=120s

log "Running seed job..."
# Delete old job if exists
kubectl -n "$NAMESPACE" delete job seed-data --ignore-not-found
kubectl apply -f "$K8S_DIR/seed-job.yaml"
kubectl -n "$NAMESPACE" wait --for=condition=complete job/seed-data --timeout=60s

log "Deploying Go service..."
kubectl apply -f "$K8S_DIR/go-service.yaml"

log "Deploying Dart service..."
kubectl apply -f "$K8S_DIR/dart-service.yaml"

log "Waiting for services..."
kubectl -n "$NAMESPACE" rollout status deployment/go-service --timeout=120s
kubectl -n "$NAMESPACE" rollout status deployment/dart-service --timeout=120s

log "All deployed. Status:"
kubectl -n "$NAMESPACE" get pods -o wide