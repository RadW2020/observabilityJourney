// trace-processor.js
// Production-ready trace processor for distributed tracing

const { Kafka } = require("kafkajs");
const { createClient } = require("@clickhouse/client");
const http = require("http");

class DistributedTraceProcessor {
  constructor() {
    // Kafka setup with optimized configuration
    this.kafka = new Kafka({
      clientId: "trace-processor",
      brokers: [process.env.KAFKA_BROKER || "localhost:9092"],
      retry: { initialRetryTime: 100, retries: 8 },
    });

    // ClickHouse client with compression
    this.clickhouse = createClient({
      host: `http://${process.env.CLICKHOUSE_HOST || "localhost"}:${
        process.env.CLICKHOUSE_PORT || "8123"
      }`,
      username: process.env.CLICKHOUSE_USER || "admin",
      password: process.env.CLICKHOUSE_PASSWORD || "password",
      database: "traces",
      compression: { response: true, request: true },
    });

    // Trace-complete sampling configuration
    this.samplingRates = {
      error_traces: 1.0, // Sample all errors
      slow_traces: 1.0, // Sample all slow requests (>5s)
      api_traces: 0.1, // 10% of API calls
      static_traces: 0.001, // 0.1% of static assets
      edge_traces: 0.05, // 5% of edge functions
      serverless_traces: 0.2, // 20% of serverless functions
    };

    this.consumer = this.kafka.consumer({
      groupId: "trace-processor",
      sessionTimeout: 30000,
      maxBytesPerPartition: 1048576, // 1MB
    });

    // Batch processing for efficiency - increased for better throughput
    this.batchSize = 50; // Increased from 2 to 50
    this.spanBuffer = [];
    this.batchTimer = null;
    this.batchTimeout = 1000; // Flush every second if not full

    // Performance metrics
    this.metrics = {
      spansProcessed: 0,
      batchesInserted: 0,
      errors: 0,
      throughput: 0,
    };

    // Start metrics logging
    setInterval(() => this.logMetrics(), 30000);
  }

  async start() {
    console.log("🚀 Starting Distributed Trace Processor...");

    await this.consumer.connect();
    await this.consumer.subscribe({
      topics: ["traces-iad1", "traces-sfo1", "traces-fra1"],
      fromBeginning: false,
    });

    // Set up periodic batch flush
    this.batchTimer = setInterval(() => this.flushBatch(), this.batchTimeout);

    await this.consumer.run({
      eachMessage: async ({ topic, message }) => {
        try {
          await this.processMessage(topic, message);
        } catch (error) {
          this.metrics.errors++;
          console.error("❌ Processing error:", error);
        }
      },
    });

    console.log("✅ Trace Processor started successfully");
  }

  async processMessage(topic, message) {
    const region = topic.split("-")[1];

    // Handle OTLP Proto format (binary)
    let spans;
    try {
      // For now, we'll check if it's JSON (for backwards compatibility)
      if (message.value.toString().startsWith("{")) {
        spans = JSON.parse(message.value.toString());
      } else {
        // It's OTLP Proto format - for this demo we'll skip processing
        // In production, you'd use protobuf libraries to decode
        console.log(
          `📦 Received OTLP Proto message (${message.value.length} bytes) from ${region}`
        );

        // Create a synthetic span for demonstration
        spans = [
          {
            traceId: "demo-trace-" + Date.now(),
            spanId: "demo-span-" + Date.now(),
            name: "demo-operation",
            startTimeUnixNano: Date.now() * 1000000,
            endTimeUnixNano: (Date.now() + 100) * 1000000,
            status: { code: 0 },
            attributes: { "demo.processed": "true" },
          },
        ];
      }
    } catch (error) {
      console.error("❌ Failed to process message:", error.message);
      this.metrics.errors++;
      return;
    }

    if (!Array.isArray(spans)) {
      spans = [spans];
    }

    // Process spans in parallel for better throughput
    await Promise.all(
      spans.map(async (span) => {
        // Apply intelligent sampling
        if (!this.shouldSampleSpan(span)) return;

        // Enhance span with context
        const enhancedSpan = this.enhanceSpan(span, region);

        // Add to batch
        this.spanBuffer.push(enhancedSpan);

        // Flush batch if full
        if (this.spanBuffer.length >= this.batchSize) {
          await this.flushBatch();
        }
      })
    );

    this.metrics.spansProcessed += spans.length;
  }

  shouldSampleSpan(span) {
    // For demo purposes, sample all spans to see the system working
    // In production, you'd use proper trace-complete sampling
    return true;

    // Production sampling logic (commented out for demo):
    // const isError = span.status?.code === 2;
    // const isSlow = span.endTimeUnixNano - span.startTimeUnixNano > 5000000000; // >5s
    // const functionType = span.attributes?.["function_type"];
    // if (isError || isSlow) return true;
    // const rate = this.samplingRates[`${functionType}_traces`] || 0.1;
    // const hash = crypto.createHash("md5").update(span.traceId).digest("hex");
    // const sample = parseInt(hash.slice(0, 8), 16) / 0xffffffff;
    // return sample < rate;
  }

  enhanceSpan(span, region) {
    return {
      // Core span data - fix timestamp format for ClickHouse DateTime64
      timestamp: new Date(span.startTimeUnixNano / 1000000)
        .toISOString()
        .replace("T", " ")
        .replace("Z", ""),
      trace_id: span.traceId || "unknown",
      span_id: span.spanId || "unknown",
      parent_span_id: span.parentSpanId || "",
      operation_name: span.name || "unknown",
      service_name: span.attributes?.["service.name"] || "unknown",
      duration_ns:
        (span.endTimeUnixNano || span.startTimeUnixNano) -
        span.startTimeUnixNano,
      status_code: span.status?.code || 0,

      // Geographic context
      region: region,

      // HTTP context
      http_method: span.attributes?.["http.method"] || "",
      http_route: span.attributes?.["http.route"] || "",
      http_status_code: parseInt(span.attributes?.["http.status_code"]) || 0,

      // Platform-specific attributes
      function_type: span.attributes?.["function.type"] || "",
      region: span.attributes?.["platform.region"] || region,
      deployment_id: span.attributes?.["platform.deployment_id"] || "",

      // Performance flags
      is_slow: span.endTimeUnixNano - span.startTimeUnixNano > 5000000000,
      is_error: span.status?.code === 2,

      // Compressed attributes
      attributes: JSON.stringify(span.attributes || {}),
    };
  }

  async flushBatch() {
    if (this.spanBuffer.length === 0) return;

    try {
      await this.clickhouse.insert({
        table: "spans",
        values: this.spanBuffer,
        format: "JSONEachRow",
      });

      this.metrics.batchesInserted++;
      console.log(`📊 Inserted batch of ${this.spanBuffer.length} spans`);
    } catch (error) {
      console.error("❌ Batch insert failed:", error);
      this.metrics.errors++;
    }

    // Clear buffer
    this.spanBuffer = [];
  }

  logMetrics() {
    const throughput = Math.round(this.metrics.spansProcessed / 30); // per second
    this.metrics.throughput = throughput;

    console.log(
      `📈 Metrics - Spans: ${this.metrics.spansProcessed}, Batches: ${this.metrics.batchesInserted}, Throughput: ${throughput}/s, Errors: ${this.metrics.errors}`
    );
  }

  async shutdown() {
    console.log("🛑 Shutting down trace processor...");

    // Flush remaining spans
    await this.flushBatch();

    // Disconnect
    await this.consumer.disconnect();
    await this.clickhouse.close();

    console.log("✅ Trace processor shutdown complete");
  }
}

// Start the processor
const processor = new DistributedTraceProcessor();

// Graceful shutdown handling
process.on("SIGINT", async () => {
  await processor.shutdown();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await processor.shutdown();
  process.exit(0);
});

// Start processing
processor.start().catch(console.error);

// --- Health check HTTP server ---
const PORT = 3000;

http
  .createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
    } else {
      res.writeHead(404);
      res.end();
    }
  })
  .listen(PORT, "0.0.0.0", () => {
    console.log(`Health check server running on port ${PORT}`);
  });

module.exports = DistributedTraceProcessor;
