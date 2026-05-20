import os
import asyncio
import json
from flask import request, jsonify

NATS_URL = os.environ.get(
    "NATS_URL", "nats://nats.ingestion-system.svc.cluster.local:4222"
)
STREAM_NAME = os.environ.get("NATS_STREAM", "ingestion")
SUBJECT = os.environ.get("NATS_SUBJECT", "ingestion.incoming")


async def publish(subject: str, data: dict) -> None:
    import nats

    nc = await nats.connect(NATS_URL)
    js = nc.jetstream()
    await js.publish(subject, json.dumps(data).encode())
    await nc.close()


def main():
    auth_header = request.headers.get("Authorization")
    if (
        not auth_header
        or auth_header != f"Bearer {os.environ.get('UPLOAD_SECRET_TOKEN')}"
    ):
        return jsonify({"error": "Unauthorized"}), 401

    req_data = request.get_json() or {}
    object_key = req_data.get("object_key")
    if not object_key:
        return jsonify({"error": "object_key is required"}), 400

    try:
        asyncio.run(publish(SUBJECT, req_data))
        return jsonify({"status": "queued"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
