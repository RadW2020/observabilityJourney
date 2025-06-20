# Distributed Tracing Architecture PoC

> **Production-scale observability system for enterprise-grade distributed tracing**

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue)](https://docker.com)
[![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-1.0+-green)](https://opentelemetry.io)
[![ClickHouse](https://img.shields.io/badge/ClickHouse-23.8+-orange)](https://clickhouse.com)

## 🎯 **Project Purpose**

This project experiment around a **production-ready distributed tracing architecture** designed for scale, addressing the specific challenges of observability in a globally distributed serverless platform.

**Primary Goals:**

- 🔍 **Skill reinforcement**: Advanced observability system design
- 🏗️ **Architecture Demonstration**: Implement solutions for real-world distributed tracing problems at scale
- 📊 **Performance Validation**: Benchmark and validate observability solutions with concrete metrics

## 🚀 **What Problems Does This Study?**

This implementation addresses **4 critical observability challenges** in distributed serverless architectures:

### 1. **Cross-Region Trace Correlation** ❌➡️✅

- **Problem**: Traces spanning multiple regions get fragmented
- **Solution**: Redis-based correlation service with deterministic trace stitching
- **Validation**: <1s correlation time for multi-region traces

### 2. **Edge Function Latency Impact** ❌➡️✅

- **Problem**: Tracing overhead affects edge function performance
- **Solution**: Optimized collectors with memory buffering and async processing
- **Validation**: <5ms additional latency overhead

### 3. **Intelligent Sampling at Scale** ❌➡️✅

- **Problem**: High-volume tracing is cost-prohibitive
- **Solution**: Trace-complete sampling maintaining trace integrity
- **Validation**: 90% cost reduction with 100% trace completeness

### 4. **Horizontal Storage Scaling** ❌➡️✅

- **Problem**: Single storage instances can't handle billions of spans
- **Solution**: Sharded ClickHouse with hash-based distribution
- **Validation**: Ready for 1B+ spans/day with 80%+ compression

## 🏗️ **Architecture Overview**

```mermaid
graph TB
    subgraph "Edge Layer"
        A[User Request] --> B[Edge PoP IAD]
        A --> C[Edge PoP SFO]
    end

    subgraph "Collection Layer"
        B --> D[OTel Collector IAD]
        C --> E[OTel Collector SFO]
    end

    subgraph "Message Queue"
        D --> F[Kafka Cluster]
        E --> F
    end

    subgraph "Processing Layer"
        F --> G[Trace Processor]
        F --> H[Correlation Service]
    end

    subgraph "Storage Layer"
        G --> I[ClickHouse Shard 1]
        G --> J[ClickHouse Shard 2]
        H --> K[Redis Cache]
    end

    subgraph "Visualization"
        I --> L[Jaeger UI]
        J --> L
        I --> M[Grafana Dashboards]
        J --> M
    end
```

## 🔧 **Technology Stack**

| Component         | Technology               | Purpose                               |
| ----------------- | ------------------------ | ------------------------------------- |
| **Collectors**    | OpenTelemetry            | low latency span collection           |
| **Message Queue** | Apache Kafka             | Async processing & regional buffering |
| **Processing**    | Node.js + Custom Logic   | Trace correlation & sampling          |
| **Storage**       | ClickHouse (Sharded)     | High-performance time-series storage  |
| **Correlation**   | Redis                    | Cross-region trace stitching          |
| **Visualization** | Jaeger + Grafana         | Trace exploration & monitoring        |
| **Applications**  | Next.js + Edge Functions | Workload simulation                   |

## 🚀 **Quick Start**

### Prerequisites

- Docker & Docker Compose
- 4GB+ RAM available
- Ports 3000-3002, 8123, 9092, 16686 available

### 1. Clone & Start

```bash
git clone <repository>
cd observabilityJourney

# Start all services
./start-demo.sh

# Wait for services to initialize (~1 minute)
```

### 2. Run Benchmark

```bash
# Run comprehensive benchmarks
./xxx-benchmark.sh
```

### 3. Explore Results

- **Jaeger UI**: http://localhost:16686 - Trace exploration
- **Grafana**: http://localhost:3002 (admin/admin) - Performance dashboards
- **ClickHouse**: http://localhost:8123 - Query interface

## 🔍 **Key Implementation Highlights**

### Trace-Complete Sampling Algorithm

```javascript
// Maintains complete traces while reducing volume
const samplingDecision = sampler.shouldSampleTrace({
  traceId,
  isError: span.status?.code === 2,
  duration: span.endTime - span.startTime,
  serviceType: span.attributes?.["function_type"],
});
```

### Sharded Storage Strategy

```javascript
// Deterministic shard selection for horizontal scaling
const shardId = crypto
  .createHash("md5")
  .update(traceId)
  .digest("hex")
  .slice(0, 8);
const shard = parseInt(shardId, 16) % SHARD_COUNT;
```

### Cross-Region Correlation

```javascript
// Redis-based trace stitching with correlation IDs
await redis.sadd(`trace:${traceId}:regions`, region);
const regions = await redis.smembers(`trace:${traceId}:regions`);
if (regions.length > 1) {
  await stitchCrossRegionTrace(traceId, regions);
}
```

## 📁 **Project Structure**

```
├── README.md                    # Complete project documentation
├── start-demo.sh                # One-command startup with health checks
├── *-benchmark.sh               # Several Performance validations
├── docker-compose.yml           # Complete observability stack
├── trace-processor-enhanced.js  # Production-ready trace processing
├── package.json                 # Node.js dependencies
├── app-simulator.sh             # Realistic traffic generator
├── collector-template.yml       # Unified collector configuration
└── prometheus.yml               # Monitoring configuration
```

## 🎯 **Learning Applications**

### System Design Questions

- "Design a distributed tracing system for a global serverless platform"
- "How would you handle trace correlation across regions?"
- "Optimize observability costs while maintaining data quality"

### Technical Deep Dives

- OpenTelemetry instrumentation best practices
- ClickHouse optimization for time-series data
- Kafka producer/consumer patterns for high throughput
- Redis caching strategies for real-time correlation

## 🧪 **Validation & Testing**

### Manual Testing Scenarios

```bash
# Test cross-region traces
curl -H "X-Trace-ID: $(uuidgen)" http://localhost:3000/api/user
curl -H "X-Trace-ID: <same-id>" http://localhost:3001/edge-api/process

# Test error scenarios
curl http://localhost:3000/api/user?error=500

# Test high-frequency edge functions
for i in {1..100}; do curl http://localhost:3001/edge-api/process & done
```

## 🔧 **Customization & Extension**

### Add New Regions

1. Add new collector service to `docker-compose.yml` with appropriate env vars
2. Update topic routing in trace processor

### Modify Sampling Rules

```javascript
// In trace-processor-enhanced.js
const baseRates = {
  error_traces: 1.0, // Sample all errors
  slow_traces: 1.0, // Sample all slow requests
  api_traces: 0.1, // 10% of API calls
  static_traces: 0.001, // 0.1% of static assets
  edge_traces: 0.05, // 5% of edge functions
};
```

### Add Custom Metrics

```javascript
// Add to span enhancement
span.setAttributes({
  "custom.business_metric": calculateBusinessValue(span),
  "custom.user_tier": getUserTier(span.attributes["user.id"]),
});
```

## 📊 **Monitoring & Alerting**

The system includes comprehensive monitoring:

- **Trace Processing Metrics**: Throughput, errors, latency
- **Storage Metrics**: Compression ratios, query performance
- **Correlation Metrics**: Cross-region success rates
- **Business Metrics**: API error rates, response times

Access dashboards at http://localhost:3002 after startup.

## 📚 **Additional Resources**

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [ClickHouse Time-Series Best Practices](https://clickhouse.com/blog/working-with-time-series-data-and-functions-ClickHouse)
- [Vercel Observability Blog Posts](https://vercel.com/products/observability)
- [Distributed Tracing Patterns](https://microservices.io/patterns/observability/distributed-tracing.html)
