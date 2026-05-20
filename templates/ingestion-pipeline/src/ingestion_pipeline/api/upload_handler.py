import os
import time
import boto3
from botocore.config import Config
from flask import request, jsonify

S3_ENDPOINT = os.environ.get("S3_ENDPOINT", "https://s3.local.lan")
ACCESS_KEY = os.environ.get("S3_ACCESS_KEY")
SECRET_KEY = os.environ.get("S3_SECRET_KEY")
BUCKET_NAME = os.environ.get("S3_BUCKET", "raw-ingest")


def main():
    auth_header = request.headers.get("Authorization")
    if (
        not auth_header
        or auth_header != f"Bearer {os.environ.get('UPLOAD_SECRET_TOKEN')}"
    ):
        return jsonify({"error": "Unauthorized"}), 401

    req_data = request.get_json() or {}
    filename = req_data.get("filename")
    if not filename:
        return jsonify({"error": "filename is required"}), 400

    s3_client = boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )

    safe = "".join(c for c in filename if c.isalnum() or c in (".", "_", "-"))
    object_key = f"incoming/{int(time.time())}_{safe}"

    try:
        presigned = s3_client.generate_presigned_url(
            "put_object",
            Params={"Bucket": BUCKET_NAME, "Key": object_key},
            ExpiresIn=43200,
        )
        return jsonify({"upload_url": presigned, "object_key": object_key}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
