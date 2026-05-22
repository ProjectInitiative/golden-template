# Dapr Integration

Dapr sidecars inject into each Fission function pod, giving them PubSub and binding capabilities without changing NATS or Fission.

## Install

```bash
dapr init --kubernetes --runtime-version 1.15
```

## Components

Apply Dapr component configs. Each one references the NATS cluster:

```bash
kubectl apply -f dapr/components/
```

## How It Works

Each Fission function gets a Dapr sidecar injected via pod annotations (see `k8s/fission-functions.yaml`). Your Python code calls Dapr's HTTP API on `localhost:3500`:

```python
import requests
resp = requests.post(
    "http://localhost:3500/v1.0/publish/ingestion-pubsub/ingestion.incoming",
    json={"object_key": "..."},
    headers={"Content-Type": "application/json"},
)
```

Or use the Dapr SDK:

```python
from dapr.clients import DaprClient
with DaprClient() as d:
    d.publish_event("ingestion-pubsub", "ingestion.incoming", payload=json_bytes)
```

## Available Components

| Component           | Type                 | Purpose                                                                       |
| ------------------- | -------------------- | ----------------------------------------------------------------------------- |
| `pubsub-nats.yaml`  | PubSub               | All event publishing goes through this                                        |
| `s3-binding.yaml`   | Input/Output binding | S3-compatible storage events                                                  |
| `cron-binding.yaml` | Input binding        | Scheduled polling (use sparingly; prefer K8s CronJob for reliable scheduling) |
