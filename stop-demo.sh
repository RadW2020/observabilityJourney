#!/bin/bash

# stop-demo.sh
# Cleanup script for Distributed Tracing PoC

echo "🛑 Stopping Distributed Tracing PoC..."

# Stop and remove all containers
docker-compose down --remove-orphans --volumes

# Remove generated files
rm -f load-test.sh
rm -f memory_usage.log
rm -f benchmark-report-*.md

# Clean up temporary directories
rm -rf grafana

echo "✅ Cleanup completed"
echo ""
echo "ℹ️  To restart the demo, run: ./start-demo.sh" 