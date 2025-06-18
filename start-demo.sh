#!/bin/bash

# start-demo.sh
# Main startup script for Distributed Tracing PoC

set -e

echo "🚀 Starting Distributed Tracing PoC"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is required but not installed"
        exit 1
    fi
    
    # Check available memory
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        total_mem=$(free -m | awk '/^Mem:/{print $2}')
        if [ $total_mem -lt 2048 ]; then
            log_warning "Less than 2GB RAM available - performance may be affected"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - just log info
        log_info "Running on macOS - ensure Docker has at least 2GB memory allocated"
    fi
    
    log_success "Prerequisites check completed"
}

# Start services
start_services() {
    log_info "Starting services with Docker Compose..."
    
    # Stop any existing containers
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Start services
    docker-compose up -d
    
    log_success "Services started"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for key services
    echo -n "Waiting for ClickHouse"
    while ! curl -s http://localhost:8123/ping >/dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✅"
    
    echo -n "Waiting for Kafka"
    while ! nc -z localhost 9092 >/dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✅"
    
    echo -n "Waiting for Jaeger"
    while ! curl -s http://localhost:16686 >/dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✅"
    
    echo -n "Waiting for Grafana"
    while ! curl -s http://localhost:3002 >/dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✅"
    
    # Give additional time for all services to fully initialize
    log_info "Allowing additional time for service initialization..."
    sleep 10
}

# Main execution
main() {
    check_prerequisites
    start_services
    wait_for_services
    
    echo ""
    echo "🎉 Distributed Tracing PoC is ready!"
    echo "==========================================="
    echo ""
    echo "📊 Access Points:"
    echo "  🔍 Jaeger UI:          http://localhost:16686"
    echo "  📈 Grafana:            http://localhost:3002 (admin/admin)"
    echo "  💾 ClickHouse Native:  http://localhost:9000"
    echo "  💾 ClickHouse HTTP:    http://localhost:8123"
    echo "  📊 Prometheus:         http://localhost:9090"
    echo "  🔄 App Simulator:      Continuously generating traces"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Wait for traces:    The app simulator is automatically generating traces"
    echo "  2. View in Grafana:    Open http://localhost:3002 and go to Dashboards"
    echo "  3. Explore in Jaeger:  Open http://localhost:16686 to see individual traces"
    echo ""
    echo "💡 Tip: If you don't see data in Grafana immediately, wait a few minutes for traces to accumulate"
}

# Run main function
main 