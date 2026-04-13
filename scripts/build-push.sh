#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-your-registry.example.com/library}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

TAG="${1:-latest}"

echo "Building and pushing Go service..."
docker buildx build --platform linux/arm64 \
  -t "$REGISTRY/go-bench:$TAG" \
  --push \
  "$PROJECT_DIR/go-service"

echo "Building and pushing Dart service..."
docker buildx build --platform linux/arm64 \
  -t "$REGISTRY/dart-bench:$TAG" \
  --push \
  "$PROJECT_DIR/dart-service"

echo "Building and pushing Axum service..."
docker buildx build --platform linux/arm64 \
  -t "$REGISTRY/axum-bench:$TAG" \
  --push \
  "$PROJECT_DIR/axum-service"

echo "Done. Images:"
echo "  $REGISTRY/go-bench:$TAG"
echo "  $REGISTRY/dart-bench:$TAG"
echo "  $REGISTRY/axum-bench:$TAG"