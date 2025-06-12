#!/bin/sh

# app-simulator.sh
# Generates realistic traces for Vercel observability testing

echo "🚀 Starting Vercel App Simulator..."

# Wait for collectors to be ready
sleep 30

# Function to generate OTLP trace data
generate_trace() {
    local trace_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1)
    local span_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 16 | head -n 1)
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
    
    # Generate OTLP JSON payload
    cat << EOF > /tmp/trace_${trace_id}.json
{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": {"stringValue": "$service_name"}
      }, {
        "key": "vercel.region",
        "value": {"stringValue": "$region"}
      }, {
        "key": "vercel.function_type",
        "value": {"stringValue": "edge"}
      }]
    },
    "instrumentationLibrarySpans": [{
      "instrumentationLibrary": {
        "name": "vercel-simulator"
      },
      "spans": [{
        "traceId": "$trace_id",
        "spanId": "$span_id",
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

    # Send to collector
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/trace_${trace_id}.json \
        http://$collector_endpoint/v1/traces >/dev/null 2>&1
    
    rm -f /tmp/trace_${trace_id}.json
}

# Function to simulate realistic user patterns
simulate_user_session() {
    local session_id=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
    echo "👤 Simulating user session: $session_id"
    
    # Landing page (IAD)
    generate_trace "iad1" "vercel-nextjs-app" "landing" 150
    sleep 0.2
    
    # API calls (IAD)
    generate_trace "iad1" "vercel-nextjs-app" "user" 250
    generate_trace "iad1" "vercel-nextjs-app" "profile" 180
    sleep 0.3
    
    # Edge function calls (SFO)
    generate_trace "sfo1" "vercel-edge-function" "geo-lookup" 50
    generate_trace "sfo1" "vercel-edge-function" "auth-check" 30
    sleep 0.5
    
    # Cross-region API call
    generate_trace "iad1" "vercel-nextjs-app" "orders" 400
    
    # Occasionally generate errors (5% rate)
    if [ $((RANDOM % 20)) -eq 0 ]; then
        generate_trace "iad1" "vercel-nextjs-app" "error" 100 2
    fi
}

# Function to simulate traffic bursts
simulate_traffic_burst() {
    echo "📈 Simulating traffic burst..."
    for i in $(seq 1 20); do
        simulate_user_session &
        sleep 0.1
    done
    wait
}

# Main simulation loop
echo "🎬 Starting continuous traffic simulation..."
counter=0

while true; do
    counter=$((counter + 1))
    
    # Normal traffic pattern
    simulate_user_session
    
    # Every 10th iteration, create a burst
    if [ $((counter % 10)) -eq 0 ]; then
        simulate_traffic_burst
        echo "📊 Completed $counter sessions, latest burst: $(date)"
    fi
    
    # Random delay between 1-5 seconds
    sleep_time=$((RANDOM % 5 + 1))
    sleep $sleep_time
done 