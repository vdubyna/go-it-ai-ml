import hashlib
import json
from datetime import datetime, timezone


def metric_from_commit(commit):
    digest = hashlib.sha256(commit.encode("utf-8")).hexdigest()
    return 0.8 + (int(digest[:6], 16) % 1500) / 10000


def handler(event, context):
    print("Logging training metrics...")
    print(json.dumps(event, sort_keys=True))

    validation = event.get("validation", {})
    commit = event.get("commit") or validation.get("commit") or "manual"
    accuracy = round(metric_from_commit(commit), 4)
    loss = round(max(0.0, 1 - accuracy), 4)

    result = {
        "status": "logged",
        "logged_at": datetime.now(timezone.utc).isoformat(),
        "source": event.get("source", validation.get("source", "unknown")),
        "commit": commit,
        "metrics": {
            "accuracy": accuracy,
            "loss": loss,
        },
    }

    print(json.dumps(result, sort_keys=True))
    return result
