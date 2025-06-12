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

# Create required directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    
    mkdir -p grafana/{dashboards,datasources}
    
    log_success "Directory structure created"
}

# Create minimal configurations
create_configs() {
    log_info "Creating service configurations..."
    
    # Ensure ClickHouse init directory exists
    if [ ! -d "clickhouse-init" ]; then
        log_warning "ClickHouse init directory not found - creating it"
        mkdir -p clickhouse-init
        log_warning "Please ensure clickhouse-init/init.sql exists with proper schema"
    fi
    
    # Create basic Grafana datasource config
    if [ ! -f "grafana/datasources/clickhouse.yml" ]; then
        mkdir -p grafana/datasources
        cat > grafana/datasources/clickhouse.yml << 'EOF'
apiVersion: 1

datasources:
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    url: http://clickhouse:8123
    access: proxy
    basicAuth: false
    isDefault: true
    jsonData:
      username: admin
      defaultDatabase: traces
    secureJsonData:
      password: password
EOF
    fi
    
    log_success "Configurations created"
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
    
    # Give additional time for all services to fully initialize
    log_info "Allowing additional time for service initialization..."
    sleep 10
    
    log_success "All services are ready"
}

# Main execution
main() {
    check_prerequisites
    setup_directories
    create_configs
    start_services
    wait_for_services
    
    echo ""
    echo "🎉 Distributed Tracing PoC is ready!"
    echo "==========================================="
    echo ""
    echo "📊 Access Points:"
    echo "  🔍 Jaeger UI:        http://localhost:16686"
    echo "  📈 Grafana:          http://localhost:3002 (admin/admin)"
    echo "  💾 ClickHouse:       http://localhost:8123"
    echo "  📊 Prometheus:       http://localhost:9090"
    echo "  🔄 App Simulator:    Continuously generating traces"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Generate load:    docker exec app-simulator sh /app-simulator.sh (already running continuously)"
    echo "  2. Run benchmarks:   ./benchmark-solutions.sh"
    echo "  3. Explore traces in Jaeger"
    echo ""
    echo "📋 Performance Targets:"
    echo "  • Edge latency overhead: <0.1ms"
    echo "  • Cross-region correlation: <1s"
    echo "  • Sampling efficiency: 90%+"
    echo "  • Storage compression: 80%+"
    echo ""
    echo "🎯 This demonstrates solutions for:"
    echo "  ✅ Cross-region trace correlation"
    echo "  ✅ Edge function latency optimization"
    echo "  ✅ Trace-complete sampling"
    echo "  ✅ Horizontal storage scaling"
}

# Run main function
main 