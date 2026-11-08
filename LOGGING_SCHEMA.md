# PROJECT OBSIDIAN — PHASE 6
# STRUCTURED LOGGING SCHEMA & TAXONOMY SPECIFICATION
## Machine-Readable JSONL Specification, Severity Rules & Canonical Event Catalog

---

## 1. Executive Summary

This document specifies the standard logging schema for IT Feels Music. Every diagnostic log emitted across mobile, desktop, and web platforms conforms to this formal schema, guaranteeing cross-platform consistency and frictionless automated parsing.

---

## 2. Formal JSON Schema Specification

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ITFeelsLogEntry",
  "type": "object",
  "required": [
    "timestamp",
    "level",
    "appVersion",
    "buildNumber",
    "platform",
    "module",
    "component",
    "eventName",
    "eventId",
    "sessionId"
  ],
  "properties": {
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO-8601 UTC timestamp of log emission"
    },
    "level": {
      "type": "string",
      "enum": ["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"],
      "description": "Severity classification"
    },
    "appVersion": {
      "type": "string",
      "description": "Semantic application version (e.g. 3.9.5)"
    },
    "buildNumber": {
      "type": "string",
      "description": "Platform build number"
    },
    "platform": {
      "type": "string",
      "enum": ["android", "ios", "windows", "macos", "linux", "web"],
      "description": "Host execution platform"
    },
    "module": {
      "type": "string",
      "enum": [
        "playback",
        "network",
        "database",
        "content",
        "performance",
        "framework",
        "platform",
        "lifecycle",
        "security"
      ],
      "description": "Architectural subsystem domain"
    },
    "component": {
      "type": "string",
      "description": "Specific Dart service, notifier, or widget"
    },
    "eventName": {
      "type": "string",
      "pattern": "^[a-z]+(_[a-z]+)*$",
      "description": "Canonical snake_case event identifier"
    },
    "eventId": {
      "type": "string",
      "pattern": "^EVT-[A-Z]+-[0-9A-F]{4,6}$",
      "description": "Unique deterministic event occurrence identifier"
    },
    "correlationId": {
      "type": "string",
      "description": "Shared trace identifier linking related asynchronous operations"
    },
    "sessionId": {
      "type": "string",
      "description": "Unique per-app-launch execution identifier"
    },
    "operationDurationMs": {
      "type": "integer",
      "minimum": 0,
      "description": "Elapsed duration in milliseconds if applicable"
    },
    "errorCode": {
      "type": "string",
      "pattern": "^(ERR|WARN)-[A-Z0-9-]+$",
      "description": "Machine-readable error classification code"
    },
    "errorMessage": {
      "type": "string",
      "description": "Human-readable error explanation (scrubbed of PII)"
    },
    "stackTrace": {
      "type": "string",
      "description": "Sanitized stack trace snippet (top 5 lines)"
    },
    "metadata": {
      "type": "object",
      "description": "Non-sensitive key-value parameters contextualizing the event"
    }
  }
}
```

---

## 3. Severity Level Criteria

| Severity | Color Code | Criteria & Use Cases | Example Scenarios |
|---|---|---|---|
| **`TRACE`** | Gray | Fine-grained internal operations, loop iterations, raw byte counts. | Packet received, buffer index advance. |
| **`DEBUG`** | Cyan | Information helpful during local debugging and feature testing. | Query parsed, seek position bounded, cache hit. |
| **`INFO`** | Emerald | Major application milestones and state machine transitions. | Play requested, track changed, mix refreshed. |
| **`WARN`** | Amber | Degraded states, unexpected conditions that did not abort the task. | Slow query ($>50\text{ms}$), 429 throttle, duplicate art. |
| **`ERROR`** | Red | Failed operations where an individual task or network call aborted. | Stream 403, decoder reject, database write error. |
| **`FATAL`** | Violet/Crimson | Critical system failures that risk crash or corrupt system state. | Uncaught async error, audio engine crash. |

---

## 4. Canonical Event Catalog

To ensure standardized telemetry across all contributors and AI agents, all event names follow `^[a-z]+(_[a-z]+)*$`:

### 4.1 Playback Subsystem (`module: playback`)
- `playback_requested`: User initiates track playback.
- `source_resolution_started`: Stream resolution query dispatched.
- `source_resolved`: Remote or local stream URL successfully resolved.
- `player_init_started`: Native media player initialized.
- `buffering_started`: Audio stream buffering initiated.
- `buffering_completed`: Buffering concluded and audio rendered.
- `first_audio_rendered`: First audible output confirmed.
- `seek_requested`: User or engine seek requested.
- `seek_completed`: Seek pointer reached target position.
- `track_transition`: Queue advanced to next or previous song.
- `playback_error`: Audio playback failed.

### 4.2 Network Subsystem (`module: network`)
- `network_request_completed`: Outbound HTTP request completed with status $< 400$.
- `network_request_failed`: Outbound HTTP request failed with status $\ge 400$.
- `slow_network_request`: Request latency exceeded SLA ($> 1200\text{ms}$).
- `rate_limit_throttled`: HTTP 429 received from external provider.
- `network_connection_exception`: Socket timeout, DNS resolution error, or offline state.

### 4.3 Database Subsystem (`module: database`)
- `database_query_executed`: Isar / local database read completed.
- `slow_database_query`: Read operation exceeded $50\text{ms}$ threshold.
- `database_write_executed`: Insert, update, or batch transaction committed.
- `database_operation_failed`: Transaction aborted or serialization error.

### 4.4 Content Subsystem (`module: content`)
- `artwork_repair_completed`: Artwork resolution promoted to high-res or quad composite generated.
- `artwork_repair_failed`: Failed to escalate or load album art.
- `duplicate_track_eliminated`: Consolidated redundant tracks while preserving variants.
- `unplayable_item_detected`: Item flagged with missing audio stream or invalid URL.

---

## 5. Streaming Format: JSON Lines (JSONL)

Logs are written sequentially with one JSON object per line, separated strictly by `\n`. This format enables streaming consumption, memory-efficient parsing, and grep-like searchability.
