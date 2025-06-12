CREATE DATABASE IF NOT EXISTS traces;

USE traces;

CREATE TABLE IF NOT EXISTS spans (
    timestamp DateTime64(9),
    trace_id String,
    span_id String,
    parent_span_id String,
    operation_name String,
    service_name String,
    duration_ns UInt64,
    status_code UInt8,
    region String,
    http_method String,
    http_route String,
    http_status_code UInt16,
    attributes String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (service_name, timestamp, trace_id)
TTL toDateTime(timestamp) + INTERVAL 30 DAY;
