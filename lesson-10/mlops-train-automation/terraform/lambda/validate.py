import json
from datetime import datetime, timezone


REQUIRED_FIELDS = ("source",)


def handler(event, context):
    print("Validating training input...")
    print(json.dumps(event, sort_keys=True))

    missing_fields = [field for field in REQUIRED_FIELDS if not event.get(field)]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

    result = {
        "status": "valid",
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "source": event["source"],
        "commit": event.get("commit", "manual"),
        "branch": event.get("branch", "unknown"),
        "message": "Input is ready for the training pipeline.",
    }

    print(json.dumps(result, sort_keys=True))
    return result
