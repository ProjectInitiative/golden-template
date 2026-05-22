import os
import hashlib
import json
import requests as http_requests
from flask import request, jsonify

FISSION_KUBERNETES_API = os.environ.get(
    "FISSION_KUBERNETES_API", "http://localhost:8001"
)
NAMESPACE = os.environ.get("JOB_NAMESPACE", "ingestion-system")


def _job_name(object_key: str) -> str:
    suffix = hashlib.sha256(object_key.encode()).hexdigest()[:16]
    return f"process-{suffix}"


def main():
    body = request.get_json(force=True, silent=True) or {}
    object_key = body.get("object_key")

    if not object_key:
        return jsonify({"error": "object_key is required"}), 400

    name = _job_name(object_key)

    manifest = {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {
            "name": name,
            "namespace": NAMESPACE,
        },
        "spec": {
            "backoffLimit": 1,
            "template": {
                "spec": {
                    "restartPolicy": "Never",
                    "containers": [
                        {
                            "name": "worker",
                            "image": "your-worker-image:latest",
                            "env": [
                                {"name": "OBJECT_KEY", "value": object_key},
                                {
                                    "name": "S3_ENDPOINT",
                                    "valueFrom": {
                                        "secretKeyRef": {
                                            "name": "s3-creds",
                                            "key": "endpoint",
                                        }
                                    },
                                },
                                {
                                    "name": "AWS_ACCESS_KEY_ID",
                                    "valueFrom": {
                                        "secretKeyRef": {
                                            "name": "s3-creds",
                                            "key": "access-key",
                                        }
                                    },
                                },
                                {
                                    "name": "AWS_SECRET_ACCESS_KEY",
                                    "valueFrom": {
                                        "secretKeyRef": {
                                            "name": "s3-creds",
                                            "key": "secret-key",
                                        }
                                    },
                                },
                            ],
                            "command": [
                                "/bin/sh",
                                "-c",
                                "echo Processing $OBJECT_KEY ...",
                            ],
                        }
                    ],
                }
            },
        },
    }

    try:
        resp = http_requests.post(
            f"{FISSION_KUBERNETES_API}/apis/batch/v1/namespaces/{NAMESPACE}/jobs",
            headers={"Content-Type": "application/json"},
            data=json.dumps(manifest),
        )
        return jsonify({"status": resp.status_code, "job": name}), resp.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500
