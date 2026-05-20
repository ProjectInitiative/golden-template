# System Architecture: Ingestion Pipeline

## High-Level Flow

```
[ Client Browser ]
      │
      ├─ 1. Authenticates & requests upload url ────────► [ Upload handler (Fission HTTP) ]
      ├─ 2. Returns presigned URL ◄──────────────────────┤
      │
      └─ 3. Uploads file directly over S3 ──────────────► [ S3-compatible Storage ]
      │
      └─ 4. On success, calls confirm ──────────────────► [ Confirm handler (Fission HTTP) ]
                                                               │
                                                               ├─ Publishes to JetStream ──► [ NATS ]
                                                                                                    │
                                                                                          (Fission MQ Trigger)
                                                                                                    ▼
[ Output Directory ] ◄── 6. Computes & Saves ─────────── [ K8s Processing Job ] ◄── 5. Orchestrator
```

## Component Blueprint

| Layer             | Technology                          | Responsibility                               |
| ----------------- | ----------------------------------- | -------------------------------------------- |
| Frontend          | Vanilla JS                          | Web form, progress bar, direct-to-S3 upload  |
| FaaS Core         | Fission (on Kubernetes)             | Python endpoints: auth, confirm, orchestrate |
| Message Queue     | NATS JetStream                      | Durable queue with retries + DLQ             |
| Object Store      | S3-compatible (Garage, MinIO, etc.) | Direct uploads, no proxy bottleneck          |
| Compute Execution | Kubernetes Batch API (Job)          | Long-lived processing decoupled from FaaS    |

## Core Decisions

1. **Zero proxy bottleneck** — Files stream directly from browser to S3 via presigned URLs. No server-side buffering of multi-GB files.

2. **NATS JetStream as event backbone** — S3 doesn't emit native events, so the confirm handler publishes to NATS after upload. Fission's `MessageQueueTrigger` subscribes natively — no polling or sidecar pods needed. Failed messages go to DLQ after maxRetries.

3. **Ephemeral K8s Jobs** — Processing runs as batch Jobs, not FaaS functions, avoiding time limits and memory constraints.

4. **Fission + NATS** — Because Fission natively supports NATS triggers, the orchestrator function is invoked directly by the queue. No adapter or subscription pod required.
