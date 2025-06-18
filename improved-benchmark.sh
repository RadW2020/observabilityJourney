#!/bin/bash

echo "🚀 IMPROVED DISTRIBUTED TRACING BENCHMARK"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Improved test parameters
TEST_DURATION=15  # seconds
SPANS_PER_SEC=1000  # more realistic load
BATCH_SIZE=10     # batch multiple spans together

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Check if services are running
check_services() {
    echo "🔍 Checking services..."
    
    local failed=0
    
    # Check collectors
    if curl -s http://localhost:4318 > /dev/null 2>&1; then
        log_success "Collector IAD (4318) is running"
    else
        log_error "Collector IAD (4318) is not responding"
        failed=1
    fi
    
    if curl -s http://localhost:4320 > /dev/null 2>&1; then
        log_success "Collector SFO (4320) is running"
    else
        log_error "Collector SFO (4320) is not responding"
        failed=1
    fi
    
    # Check Jaeger
    if curl -s http://localhost:16686 > /dev/null 2>&1; then
        log_success "Jaeger UI (16686) is running"
    else
        log_error "Jaeger UI (16686) is not responding"
        failed=1
    fi
    
    if [ $failed -eq 1 ]; then
        return 1
    fi
    
    echo ""
}

# Improved throughput test with batching
test_throughput() {
    log_test "📊 IMPROVED THROUGHPUT TEST"
    echo "   Sending ${SPANS_PER_SEC} spans/sec for ${TEST_DURATION} seconds..."
    echo "   Using batching: ${BATCH_SIZE} spans per request"
    
    local total_spans=$((SPANS_PER_SEC * TEST_DURATION))
    local total_batches=$((total_spans / BATCH_SIZE))
    local success_count=0
    local error_count=0
    
    echo "   Total batches to send: $total_batches"
    echo "   Expected throughput: ${SPANS_PER_SEC} spans/sec"
    echo ""
    
    local start_time=$(date +%s)
    
    for ((i=0; i<total_batches; i++)); do
        # Create batch of spans
        local batch_data="{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"improved-test\"}}]},\"scopeSpans\":[{\"spans\":["
        
        for ((j=0; j<BATCH_SIZE; j++)); do
            local span_index=$((i * BATCH_SIZE + j))
            local trace_id=$(printf "%032x" $((RANDOM * RANDOM + span_index)))
            local start_time_ns=$(date +%s%N)
            
            batch_data+="{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" $span_index)\",\"name\":\"improved-test\",\"kind\":1,\"startTimeUnixNano\":\"$start_time_ns\",\"endTimeUnixNano\":\"$((start_time_ns + 1000000))\",\"status\":{\"code\":0}}"
            
            if [ $j -lt $((BATCH_SIZE-1)) ]; then
                batch_data+=","
            fi
        done
        
        batch_data+="]}]}]}"
        
        # Send to IAD collector
        local response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://localhost:4318/v1/traces" \
            -H 'Content-Type: application/json' \
            -d "$batch_data" \
            --max-time 2 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
        # Show progress every 10 batches
        if [ $((i % 10)) -eq 0 ]; then
            local completed_spans=$((i * BATCH_SIZE))
            local elapsed=$(( $(date +%s) - start_time ))
            local current_rate=0
            if [ $elapsed -gt 0 ]; then
                current_rate=$((completed_spans / elapsed))
            fi
            echo "   Progress: $((i + 1))/$total_batches batches (${completed_spans} spans) - Current rate: ${current_rate} spans/sec"
        fi
        
        # Reduced sleep for better throughput
        sleep 0.02  # 50 requests/sec per worker
    done
    
    local end_time=$(date +%s)
    local actual_duration=$((end_time - start_time))
    local actual_spans=$((success_count * BATCH_SIZE))
    local actual_throughput=$((actual_spans / actual_duration))
    local success_rate=$(echo "scale=1; $success_count * 100 / $total_batches" | bc -l 2>/dev/null || echo "0")
    
    echo ""
    log_success "Throughput test completed!"
    echo "   Total batches sent: $total_batches"
    echo "   Successful batches: $success_count"
    echo "   Failed batches: $error_count"
    echo "   Total spans sent: $actual_spans"
    echo "   Actual throughput: ${actual_throughput} spans/sec"
    echo "   Success rate: ${success_rate}%"
    echo "   Duration: ${actual_duration}s"
    echo ""
    
    # Check against target
    if [ $actual_throughput -ge $SPANS_PER_SEC ]; then
        log_success "Throughput: ${actual_throughput} spans/sec (target: ≥${SPANS_PER_SEC} spans/sec)"
    else
        log_error "Throughput: ${actual_throughput} spans/sec below target: ${SPANS_PER_SEC} spans/sec"
    fi
    
    if (( $(echo "$success_rate >= 95" | bc -l 2>/dev/null || echo "0") )); then
        log_success "Success rate: ${success_rate}% (target: ≥95%)"
    else
        log_error "Success rate: ${success_rate}% below target: 95%"
    fi
}

# Improved latency test
test_latency() {
    log_test "⚡ IMPROVED LATENCY TEST"
    echo "   Measuring latency for 20 requests..."
    
    local total_latency=0
    local count=0
    local latencies=()
    
    for ((i=0; i<20; i++)); do
        local trace_id=$(printf "%032x" $((RANDOM * RANDOM + i)))
        local start_time=$(date +%s%N)
        
        # Measure response time
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null -X POST "http://localhost:4318/v1/traces" \
            -H 'Content-Type: application/json' \
            -d "{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"latency-test\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"$trace_id\",\"spanId\":\"$(printf "%016x" $i)\",\"name\":\"latency-test\",\"kind\":1,\"startTimeUnixNano\":\"$start_time\",\"endTimeUnixNano\":\"$((start_time + 1000000))\",\"status\":{\"code\":0}}]}]}]}" \
            --max-time 5 2>/dev/null || echo "5.0")
        
        # Convert to milliseconds
        local latency_ms=$(echo "scale=2; $response_time * 1000" | bc -l 2>/dev/null || echo "5000")
        latencies+=($latency_ms)
        total_latency=$(echo "scale=2; $total_latency + $latency_ms" | bc -l 2>/dev/null || echo "0")
        count=$((count + 1))
        
        echo "   Request $((i+1)): ${latency_ms}ms"
    done
    
    # Calculate statistics
    local avg_latency=$(echo "scale=2; $total_latency / $count" | bc -l 2>/dev/null || echo "0")
    
    # Calculate P95 and P99 (simplified)
    IFS=$'\n' sorted=($(sort -n <<<"${latencies[*]}"))
    unset IFS
    local p95_index=$((count * 95 / 100))
    local p99_index=$((count * 99 / 100))
    local p95=${sorted[$p95_index]}
    local p99=${sorted[$p99_index]}
    
    echo ""
    log_success "Latency test completed!"
    echo "   Average latency: ${avg_latency}ms"
    echo "   P95 latency: ${p95}ms"
    echo "   P99 latency: ${p99}ms"
    echo ""
    
    # Check against targets
    if (( $(echo "$avg_latency <= 50" | bc -l 2>/dev/null || echo "0") )); then
        log_success "Average latency: ${avg_latency}ms (target: ≤50ms)"
    else
        log_error "Average latency: ${avg_latency}ms exceeds target: 50ms"
    fi
    
    if (( $(echo "$p95 <= 200" | bc -l 2>/dev/null || echo "0") )); then
        log_success "P95 latency: ${p95}ms (target: ≤200ms)"
    else
        log_error "P95 latency: ${p95}ms exceeds target: 200ms"
    fi
}

# Main execution
main() {
    echo "Starting improved benchmark..."
    echo "Duration: ${TEST_DURATION} seconds"
    echo "Load: ${SPANS_PER_SEC} spans/sec"
    echo "Batch size: ${BATCH_SIZE} spans/batch"
    echo ""
    
    # Check services first
    if ! check_services; then
        echo "❌ Some services are not running. Please start the stack first:"
        echo "   docker-compose up -d"
        exit 1
    fi
    
    # Run improved tests
    test_throughput
    test_latency
    
    echo "🎉 IMPROVED BENCHMARK COMPLETED!"
    echo "================================"
    echo ""
    echo "📊 Access your observability tools:"
    echo "   • Jaeger UI: http://localhost:16686"
    echo "   • Grafana: http://localhost:3002"
    echo "   • Prometheus: http://localhost:9090"
    echo ""
}

# Run main function
main 