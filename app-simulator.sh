#!/bin/sh

# app-simulator.sh
# Generates realistic traces for distributed observability testing

echo "🚀 Starting Distributed App Simulator..."

# Wait for collectors to be ready
sleep 10

# Function to generate OTLP trace data
generate_trace() {
    local trace_id=$(head -c 16 /dev/urandom | xxd -p)
    local span_id=$(head -c 8 /dev/urandom | xxd -p)
    local region=$1
    local service_name=$2
    local operation=$3
    local duration_ms=$4
    local status_code=${5:-0}
    
    local collector_endpoint
    if [ "$region" = "iad1" ]; then
        collector_endpoint="otel-collector-iad:4318"
    else
        collector_endpoint="otel-collector-sfo:4318"
    fi
    
    # Convert traceId and spanId from hex to base64
    local trace_id_b64=$(echo -n "$trace_id" | xxd -r -p | base64)
    local span_id_b64=$(echo -n "$span_id" | xxd -r -p | base64)

    # Generate OTLP JSON payload (OTLP 1.0+)
    cat << EOF > /tmp/trace_${trace_id}.json
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "$service_name"}
      }, {
        "key": "platform.region",
        "value": {"stringValue": "$region"}
      }, {
        "key": "function.type",
        "value": {"stringValue": "edge"}
      }]
    },
    "scopeSpans": [{
      "scope": {
        "name": "distributed-simulator"
      },
      "spans": [{
        "traceId": "$trace_id_b64",
        "spanId": "$span_id_b64",
        "name": "$operation",
        "kind": "SPAN_KIND_SERVER",
        "startTimeUnixNano": "$(date +%s)000000000",
        "endTimeUnixNano": "$(($(date +%s) + duration_ms))000000",
        "status": {
          "code": $status_code
        },
        "attributes": [{
          "key": "http.method",
          "value": {"stringValue": "GET"}
        }, {
          "key": "http.route",
          "value": {"stringValue": "/api/$operation"}
        }, {
          "key": "http.status_code",
          "value": {"intValue": "200"}
        }]
      }]
    }]
  }]
}
EOF

    # Print the generated JSON for debugging
    cat /tmp/trace_${trace_id}.json

    # Send to collector
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/trace_${trace_id}.json \
        http://$collector_endpoint/v1/traces >/dev/null 2>&1
    
    rm -f /tmp/trace_${trace_id}.json
}

# Function to simulate realistic user patterns
simulate_user_session() {
    local session_id=$(head -c 4 /dev/urandom | xxd -p)
    echo "👤 Simulating user session: $session_id"
    
    # Generate all traces concurrently for better throughput
    (
        # Landing page (IAD)
        generate_trace "iad1" "web-app" "landing" 150 &
        
        # API calls (IAD)
        generate_trace "iad1" "web-app" "user" 250 &
        generate_trace "iad1" "web-app" "profile" 180 &
        
        # Edge function calls (SFO)
        generate_trace "sfo1" "edge-function" "geo-lookup" 50 &
        generate_trace "sfo1" "edge-function" "auth-check" 30 &
        
        # Cross-region API call
        generate_trace "iad1" "web-app" "orders" 400 &
        
        # Occasionally generate errors (5% rate)
        if [ $((RANDOM % 20)) -eq 0 ]; then
            generate_trace "iad1" "web-app" "error" 100 2 &
        fi
        
        wait  # Wait for all traces in this session to complete
    )
}

# Function to simulate traffic bursts
simulate_traffic_burst() {
    echo "📈 Simulating traffic burst..."
    # Increase concurrent sessions from 20 to 50
    for i in $(seq 1 50); do
        simulate_user_session &
    done
    wait
}

# Main simulation loop
echo "🎬 Starting continuous traffic simulation..."
counter=0

while true; do
    counter=$((counter + 1))
    
    # Normal traffic pattern - run multiple sessions concurrently
    for i in $(seq 1 5); do
        simulate_user_session &
    done
    wait
    
    # Every 5th iteration (reduced from 10), create a burst
    if [ $((counter % 5)) -eq 0 ]; then
        simulate_traffic_burst
        echo "📊 Completed $counter sessions, latest burst: $(date)"
    fi
    
    # Reduced random delay between 0.5-2 seconds (from 1-5)
    sleep_time=$(echo "scale=2; $((RANDOM % 15 + 5)) / 10" | bc)
    sleep $sleep_time
done 