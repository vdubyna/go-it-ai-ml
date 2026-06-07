import argparse
import json
import pickle
from datetime import datetime, timezone
from pathlib import Path


def train_mock_model(version: str) -> dict:
    return {
        "version": version,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "model_type": "mock-logistic-regression",
        "feature_names": [
            "cpu_load",
            "memory_pressure",
            "error_rate",
            "request_latency_ms",
        ],
        "weights": [0.9, 0.7, 2.4, 0.015],
        "bias": -4.2,
        "threshold": 0.5,
        "reference_mean": [0.45, 0.5, 0.02, 120.0],
        "reference_std": [0.2, 0.18, 0.03, 45.0],
        "feature_ranges": {
            "cpu_load": {"min": 0.0, "max": 1.0},
            "memory_pressure": {"min": 0.0, "max": 1.0},
            "error_rate": {"min": 0.0, "max": 0.25},
            "request_latency_ms": {"min": 0.0, "max": 500.0},
        },
        "drift_z_threshold": 3.0,
    }


def write_model(model: dict, output_path: Path, metadata_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("wb") as model_file:
        pickle.dump(model, model_file)

    metadata = {
        "version": model["version"],
        "trained_at": model["trained_at"],
        "model_type": model["model_type"],
        "output_path": str(output_path),
        "feature_names": model["feature_names"],
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Retrain mock AIOps quality model.")
    parser.add_argument("--output", default="model/model.pkl", help="Path to model pickle artifact.")
    parser.add_argument("--metadata", default="model/metadata.json", help="Path to metadata JSON.")
    parser.add_argument("--version", default=None, help="Model version. Defaults to timestamp.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    version = args.version or datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    model = train_mock_model(version)
    write_model(model, Path(args.output), Path(args.metadata))
    print(json.dumps({"event": "model_trained", "version": version, "output": args.output}))


if __name__ == "__main__":
    main()
