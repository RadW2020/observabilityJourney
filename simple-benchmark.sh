#!/bin/bash

echo "🚀 SIMPLE DISTRIBUTED TRACING BENCHMARK"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simple test parameters
TEST_DURATION=10  # seconds
SPANS_PER_SEC=10  # very low load for testing

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Check if services are running
check_services() {
    echo "🔍 Checking services..."
    
    # Check collectors
    if curl -s http://localhost:4318 > /dev/null 2>&1; then
        log_success "Collector IAD (4318) is running"
    else
        log_error "Collector IAD (4318) is not responding"
        return 1
    fi
    
    if curl -s http://localhost:4320 > /dev/null 2>&1; then
        log_success "Collector SFO (4320) is running"
    else
        log_error "Collector SFO (4320) is not responding"
        return 1
    fi
    
    # Check Jaeger
    if curl -s http://localhost:16686 > /dev/null 2>&1; then
        log_success "Jaeger UI (16686) is running"
    else
        log_error "Jaeger UI (16686) is not responding"
        return 1
    fi
    
    echo ""
}

# Simple throughput test
test_throughput() {
    log_test "📊 SIMPLE THROUGHPUT TEST"
    echo "   Sending ${SPANS_PER_SEC} spans/sec for ${TEST_DURATION} seconds..."
    
    local total_spans=$((SPANS_PER_SEC * TEST_DURATION))
    local success_count=0
    local error_count=0
    
    for ((i=0; i<total_spans; i++)); do
        local trace_id=$(printf "%032x" $((RANDOM * RANDOM + i)))
        local start_time=$(date +%s%N)
        
        # Send to IAD collector
        local response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://localhost:4318/v1/traces" \
            -H 'Content-Type: application/json' \
            -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"simple-test\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" $i)\",\"name\":\"simple-test\",\"kind\":1,\"startTimeUnixNano\":\"$start_time\",\"endTimeUnixNano\":\"$((start_time + 1000000))\",\"status\":{\"code\":0}}]}]}]}" \
            --max-time 2 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
        # Show progress every 10 spans
        if [ $((i % 10)) -eq 0 ]; then
            echo "   Progress: $((i + 1))/$total_spans spans sent"
        fi
        
        # Sleep to maintain rate
        sleep 0.1
    done
    
    local success_rate=$(echo "scale=1; $success_count * 100 / $total_spans" | bc -l 2>/dev/null || echo "0")
    
    echo ""
    log_success "Throughput test completed!"
    echo "   Total spans sent: $total_spans"
    echo "   Successful: $success_count"
    echo "   Errors: $error_count"
    echo "   Success rate: ${success_rate}%"
    echo ""
}

# Simple latency test
test_latency() {
    log_test "⚡ SIMPLE LATENCY TEST"
    echo "   Measuring latency for 10 requests..."
    
    local total_latency=0
    local count=0
    
    for ((i=0; i<10; i++)); do
        local trace_id=$(printf "%032x" $((RANDOM * RANDOM + i)))
        local start_time=$(date +%s%N)
        
        # Measure response time
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null -X POST "http://localhost:4318/v1/traces" \
            -H 'Content-Type: application/json' \
            -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"latency-test\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" $i)\",\"name\":\"latency-test\",\"kind\":1,\"startTimeUnixNano\":\"$start_time\",\"endTimeUnixNano\":\"$((start_time + 1000000))\",\"status\":{\"code\":0}}]}]}]}" \
            --max-time 5 2>/dev/null || echo "5.0")
        
        # Convert to milliseconds
        local latency_ms=$(echo "scale=2; $response_time * 1000" | bc -l 2>/dev/null || echo "5000")
        total_latency=$(echo "scale=2; $total_latency + $latency_ms" | bc -l 2>/dev/null || echo "0")
        count=$((count + 1))
        
        echo "   Request $((i+1)): ${latency_ms}ms"
    done
    
    local avg_latency=$(echo "scale=2; $total_latency / $count" | bc -l 2>/dev/null || echo "0")
    
    echo ""
    log_success "Latency test completed!"
    echo "   Average latency: ${avg_latency}ms"
    echo ""
}

# Simple cross-region test
test_cross_region() {
    log_test "🌍 SIMPLE CROSS-REGION TEST"
    echo "   Testing cross-region trace correlation..."
    
    local trace_id=$(printf "%032x" $((RANDOM * RANDOM)))
    local timestamp=$(date +%s%N)
    
    echo "   Sending trace $trace_id to both regions..."
    
    # Send to IAD
    curl -s -X POST "http://localhost:4318/v1/traces" \
        -H 'Content-Type: application/json' \
        -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"cross-region-test\"}},{\"key\":\"platform.region\",\"value\":{\"stringValue\":\"iad1\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" 1)\",\"name\":\"cross-region-iad\",\"kind\":1,\"startTimeUnixNano\":\"$timestamp\",\"endTimeUnixNano\":\"$((timestamp + 1000000))\",\"status\":{\"code\":0}}]}]}]}" \
        --max-time 2 > /dev/null 2>&1
    
    # Send to SFO
    curl -s -X POST "http://localhost:4320/v1/traces" \
        -H 'Content-Type: application/json' \
        -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"cross-region-test\"}},{\"key\":\"platform.region\",\"value\":{\"stringValue\":\"sfo1\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" 2)\",\"name\":\"cross-region-sfo\",\"kind\":1,\"startTimeUnixNano\":\"$timestamp\",\"endTimeUnixNano\":\"$((timestamp + 1000000))\",\"status\":{\"code\":0}}]}]}]}" \
        --max-time 2 > /dev/null 2>&1
    
    echo "   Waiting 3 seconds for processing..."
    sleep 3
    
    log_success "Cross-region test completed!"
    echo "   Trace ID: $trace_id"
    echo "   Check Jaeger UI: http://localhost:16686"
    echo ""
}

# Main execution
main() {
    echo "Starting simple benchmark..."
    echo "Duration: ${TEST_DURATION} seconds"
    echo "Load: ${SPANS_PER_SEC} spans/sec"
    echo ""
    
    # Check services first
    if ! check_services; then
        echo "❌ Some services are not running. Please start the stack first:"
        echo "   docker-compose up -d"
        exit 1
    fi
    
    # Run simple tests
    test_throughput
    test_latency
    test_cross_region
    
    echo "🎉 SIMPLE BENCHMARK COMPLETED!"
    echo "==============================="
    echo ""
    echo "📊 Access your observability tools:"
    echo "   • Jaeger UI: http://localhost:16686"
    echo "   • Grafana: http://localhost:3002"
    echo "   • Prometheus: http://localhost:9090"
    echo ""
}

# Run main function
main 