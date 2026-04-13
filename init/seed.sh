#!/bin/sh
set -e

echo "Seeding Redis with 100 users..."
for i in $(seq 1 100); do
  redis-cli -h redis SET "user:$i" "{\"id\":$i,\"name\":\"User $i\",\"email\":\"user${i}@bench.test\"}"
done
echo "Done seeding Redis. $i users created."
