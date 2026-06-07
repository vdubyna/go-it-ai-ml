import json
import logging
import math
import os
import pickle
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from fastapi import BackgroundTasks, FastAPI, HTTPException
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from pydantic import BaseModel, Field
from starlette.responses import Response


APP_NAME = "aiops-quality-api"
DEFAULT_MODEL_PATH = Path(__file__).resolve().parents[1] / "model" / "model.pkl"
MODEL_PATH = Path(os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))
DRIFT_WEBHOOK_URL = os.getenv("DRIFT_WEBHOOK_URL", "")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

logging.basicConfig(level=LOG_LEVEL, format="%(message)s")
logger = logging.getLogger(APP_NAME)

REQUESTS_TOTAL = Counter(
    "aiops_quality_requests_total",
    "Total prediction requests.",
    ["endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "aiops_quality_request_latency_seconds",
    "Prediction request latency in seconds.",
    ["endpoint"],
)
DRIFT_ALERTS_TOTAL = Counter(
    "aiops_quality_drift_alerts_total",
    "Total number of drift alerts.",
    ["reason"],
)
MODEL_INFO = Gauge(
    "aiops_quality_model_info",
    "Loaded model version info.",
    ["version"],
)

app = FastAPI(title="AIOps Quality API", version="0.1.0")
MODEL: dict[str, Any] | None = None


class PredictionRequest(BaseModel):
    features: list[float] = Field(..., min_items=4, max_items=4)
    request_id: str | None = Field(default=None, max_length=80)


class PredictionResponse(BaseModel):
    prediction: int
    probability: float
    drift_detected: bool
    drift_reasons: list[str]
    model_version: str


def load_model(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Model file does not exist: {path}")

    with path.open("rb") as model_file:
        model = pickle.load(model_file)

    required_keys = {"weights", "bias", "threshold", "feature_names"}
    missing_keys = required_keys.difference(model)
    if missing_keys:
        raise ValueError(f"Model file is missing keys: {sorted(missing_keys)}")

    return model


def get_model() -> dict[str, Any]:
    if MODEL is None:
        raise HTTPException(status_code=503, detail="Model is not loaded yet.")
    return MODEL


def sigmoid(value: float) -> float:
    return 1 / (1 + math.exp(-value))


def predict(data: list[float]) -> dict[str, Any]:
    model = get_model()
    weights = model["weights"]
    score = sum(weight * value for weight, value in zip(weights, data)) + model["bias"]
    probability = sigmoid(score)
    prediction = int(probability >= model["threshold"])

    return {
        "prediction": prediction,
        "probability": round(probability, 6),
        "model_version": model.get("version", "unknown"),
    }


def evaluate_with_great_expectations(data: list[float], model: dict[str, Any]) -> tuple[bool, list[str]]:
    feature_names = model.get("feature_names", [])
    feature_ranges = model.get("feature_ranges", {})
    row = dict(zip(feature_names, data))

    try:
        import pandas as pd
        from great_expectations.dataset import PandasDataset

        dataset = PandasDataset(pd.DataFrame([row]))
        failed_expectations = []

        for feature_name, bounds in feature_ranges.items():
            expectation = dataset.expect_column_values_to_be_between(
                feature_name,
                min_value=bounds["min"],
                max_value=bounds["max"],
            )
            if not expectation.get("success", False):
                failed_expectations.append(f"{feature_name}_outside_expected_range")

        return len(failed_expectations) == 0, failed_expectations
    except Exception as exc:
        failed_expectations = []
        for feature_name, value in row.items():
            bounds = feature_ranges.get(feature_name)
            if bounds and not (bounds["min"] <= value <= bounds["max"]):
                failed_expectations.append(f"{feature_name}_outside_expected_range")

        if failed_expectations:
            logger.warning(
                json.dumps(
                    {
                        "event": "great_expectations_fallback",
                        "reason": str(exc),
                        "failed_expectations": failed_expectations,
                    }
                )
            )

        return len(failed_expectations) == 0, failed_expectations


def detect_drift(data: list[float], model: dict[str, Any]) -> dict[str, Any]:
    reference_mean = model.get("reference_mean", [0.0] * len(data))
    reference_std = model.get("reference_std", [1.0] * len(data))
    z_threshold = float(os.getenv("DRIFT_Z_THRESHOLD", model.get("drift_z_threshold", 3.0)))
    feature_names = model.get("feature_names", [f"feature_{index}" for index in range(len(data))])

    z_scores = []
    drift_reasons = []
    for feature_name, value, mean, std in zip(feature_names, data, reference_mean, reference_std):
        safe_std = std if std else 1.0
        z_score = abs((value - mean) / safe_std)
        z_scores.append(round(z_score, 4))
        if z_score > z_threshold:
            drift_reasons.append(f"{feature_name}_z_score_gt_{z_threshold}")

    ge_success, ge_reasons = evaluate_with_great_expectations(data, model)
    if not ge_success:
        drift_reasons.extend(ge_reasons)

    return {
        "drift_detected": len(drift_reasons) > 0,
        "drift_reasons": sorted(set(drift_reasons)),
        "z_scores": z_scores,
    }


def send_drift_webhook(payload: dict[str, Any]) -> None:
    if not DRIFT_WEBHOOK_URL:
        return

    request = urllib.request.Request(
        DRIFT_WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            logger.info(
                json.dumps(
                    {
                        "event": "drift_webhook_sent",
                        "status": response.status,
                    }
                )
            )
    except (urllib.error.URLError, TimeoutError) as exc:
        logger.error(
            json.dumps(
                {
                    "event": "drift_webhook_failed",
                    "error": str(exc),
                }
            )
        )


@app.on_event("startup")
def startup() -> None:
    global MODEL
    MODEL = load_model(MODEL_PATH)
    MODEL_INFO.labels(version=MODEL.get("version", "unknown")).set(1)
    logger.info(
        json.dumps(
            {
                "event": "model_loaded",
                "model_path": str(MODEL_PATH),
                "model_version": MODEL.get("version", "unknown"),
            }
        )
    )


@app.get("/health")
def health() -> dict[str, Any]:
    model = get_model()
    return {
        "status": "ok",
        "model_version": model.get("version", "unknown"),
    }


@app.post("/predict", response_model=PredictionResponse)
def predict_endpoint(request: PredictionRequest, background_tasks: BackgroundTasks) -> dict[str, Any]:
    started_at = time.perf_counter()
    status = "success"

    try:
        model = get_model()
        prediction = predict(request.features)
        drift = detect_drift(request.features, model)

        response = {
            **prediction,
            "drift_detected": drift["drift_detected"],
            "drift_reasons": drift["drift_reasons"],
        }

        log_payload = {
            "event": "prediction",
            "request_id": request.request_id,
            "features": request.features,
            "response": response,
            "drift": drift,
        }
        logger.info(json.dumps(log_payload, sort_keys=True))

        if drift["drift_detected"]:
            print("Drift detected", flush=True)
            for reason in drift["drift_reasons"]:
                DRIFT_ALERTS_TOTAL.labels(reason=reason).inc()

            logger.warning(
                json.dumps(
                    {
                        "event": "drift_detected",
                        "request_id": request.request_id,
                        "reasons": drift["drift_reasons"],
                    },
                    sort_keys=True,
                )
            )
            background_tasks.add_task(send_drift_webhook, log_payload)

        return response
    except Exception:
        status = "error"
        raise
    finally:
        REQUESTS_TOTAL.labels(endpoint="/predict", status=status).inc()
        REQUEST_LATENCY.labels(endpoint="/predict").observe(time.perf_counter() - started_at)


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
