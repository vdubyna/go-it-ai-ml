from __future__ import annotations

import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from mlflow import MlflowClient
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from sklearn.datasets import load_iris
from sklearn.linear_model import SGDClassifier
from sklearn.metrics import accuracy_score, log_loss
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

import mlflow
import mlflow.sklearn


@dataclass(frozen=True)
class RunResult:
    run_id: str
    learning_rate: float
    epochs: int
    accuracy: float
    loss: float
    local_model_path: Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BEST_MODEL_DIR = PROJECT_ROOT / "best_model"


def configure_environment() -> tuple[str, str]:
    load_dotenv()

    tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
    pushgateway_url = os.getenv("PUSHGATEWAY_URL", "http://localhost:9091")

    os.environ.setdefault("AWS_ACCESS_KEY_ID", "minio")
    os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "minio123")
    os.environ.setdefault("MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000")

    mlflow.set_tracking_uri(tracking_uri)

    return tracking_uri, pushgateway_url


def get_or_create_experiment(name: str) -> str:
    experiment = mlflow.get_experiment_by_name(name)
    if experiment is not None:
        return experiment.experiment_id

    artifact_location = os.getenv("MLFLOW_ARTIFACT_LOCATION")
    if artifact_location:
        return mlflow.create_experiment(name, artifact_location=artifact_location)

    return mlflow.create_experiment(name)


def train_model(learning_rate: float, epochs: int) -> tuple[Pipeline, float, float]:
    iris = load_iris()
    x_train, x_test, y_train, y_test = train_test_split(
        iris.data,
        iris.target,
        test_size=0.25,
        random_state=42,
        stratify=iris.target,
    )

    model = Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            (
                "classifier",
                SGDClassifier(
                    loss="log_loss",
                    learning_rate="constant",
                    eta0=learning_rate,
                    max_iter=epochs,
                    random_state=42,
                    tol=1e-4,
                ),
            ),
        ]
    )
    model.fit(x_train, y_train)

    predictions = model.predict(x_test)
    probabilities = model.predict_proba(x_test)

    accuracy = accuracy_score(y_test, predictions)
    loss = log_loss(y_test, probabilities)

    return model, accuracy, loss


def push_metrics(
    pushgateway_url: str,
    run_id: str,
    learning_rate: float,
    epochs: int,
    accuracy: float,
    loss: float,
) -> None:
    registry = CollectorRegistry()
    label_names = ["learning_rate", "epochs"]

    accuracy_gauge = Gauge(
        "mlflow_accuracy",
        "Accuracy of an MLflow experiment run.",
        label_names,
        registry=registry,
    )
    loss_gauge = Gauge(
        "mlflow_loss",
        "Log loss of an MLflow experiment run.",
        label_names,
        registry=registry,
    )

    labels = {
        "learning_rate": str(learning_rate),
        "epochs": str(epochs),
    }
    accuracy_gauge.labels(**labels).set(accuracy)
    loss_gauge.labels(**labels).set(loss)

    push_to_gateway(
        pushgateway_url,
        job="mlflow_experiment",
        grouping_key={"run_id": run_id},
        registry=registry,
    )


def save_model_artifact(model: Pipeline, destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)

    mlflow.sklearn.save_model(model, path=str(destination))
    mlflow.log_artifacts(str(destination), artifact_path="model")


def run_training_grid(
    experiment_id: str,
    pushgateway_url: str,
    model_cache_dir: Path,
) -> list[RunResult]:
    learning_rates = [0.001, 0.01, 0.05]
    epochs_values = [200, 500, 1000]
    results: list[RunResult] = []

    for learning_rate in learning_rates:
        for epochs in epochs_values:
            run_name = f"sgd_lr_{learning_rate}_epochs_{epochs}"
            with mlflow.start_run(experiment_id=experiment_id, run_name=run_name) as run:
                model, accuracy, loss = train_model(learning_rate, epochs)
                run_id = run.info.run_id
                local_model_path = model_cache_dir / run_id / "model"

                mlflow.log_param("learning_rate", learning_rate)
                mlflow.log_param("epochs", epochs)
                mlflow.log_param("dataset", "sklearn.datasets.load_iris")
                mlflow.log_metric("accuracy", accuracy)
                mlflow.log_metric("loss", loss)
                save_model_artifact(model, local_model_path)

                push_metrics(pushgateway_url, run_id, learning_rate, epochs, accuracy, loss)

                result = RunResult(
                    run_id=run_id,
                    learning_rate=learning_rate,
                    epochs=epochs,
                    accuracy=accuracy,
                    loss=loss,
                    local_model_path=local_model_path,
                )
                results.append(result)
                print(
                    "run_id={run_id} learning_rate={learning_rate} "
                    "epochs={epochs} accuracy={accuracy:.4f} loss={loss:.4f}".format(
                        run_id=run_id,
                        learning_rate=learning_rate,
                        epochs=epochs,
                        accuracy=accuracy,
                        loss=loss,
                    )
                )

    return results


def select_best_model(experiment_id: str, results: list[RunResult]) -> RunResult:
    if not results:
        raise RuntimeError("No training results found.")

    client = MlflowClient()
    best_runs = client.search_runs(
        experiment_ids=[experiment_id],
        order_by=["metrics.accuracy DESC", "metrics.loss ASC"],
        max_results=len(results),
    )
    if not best_runs:
        raise RuntimeError("No MLflow runs found for the experiment.")

    result_by_run_id = {result.run_id: result for result in results}
    for run in best_runs:
        if run.info.run_id in result_by_run_id:
            return result_by_run_id[run.info.run_id]

    return max(results, key=lambda result: (result.accuracy, -result.loss))


def prepare_best_model_dir() -> Path:
    BEST_MODEL_DIR.mkdir(parents=True, exist_ok=True)
    for path in BEST_MODEL_DIR.iterdir():
        if path.name == ".gitkeep":
            continue
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()

    return BEST_MODEL_DIR / "model"


def copy_best_model(best_result: RunResult) -> None:
    target_dir = prepare_best_model_dir()
    shutil.copytree(best_result.local_model_path, target_dir)



def main() -> None:
    tracking_uri, pushgateway_url = configure_environment()
    experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME", "Iris Quality Monitoring")
    experiment_id = get_or_create_experiment(experiment_name)

    print(f"MLflow tracking URI: {tracking_uri}")
    print(f"PushGateway URL: {pushgateway_url}")
    print(f"Experiment: {experiment_name} ({experiment_id})")

    with tempfile.TemporaryDirectory(prefix="mlflow-model-cache-") as cache_dir:
        results = run_training_grid(experiment_id, pushgateway_url, Path(cache_dir))
        best_result = select_best_model(experiment_id, results)
        copy_best_model(best_result)

    print(
        "Best model: run_id={run_id} learning_rate={learning_rate} "
        "epochs={epochs} accuracy={accuracy:.4f} loss={loss:.4f}".format(
            run_id=best_result.run_id,
            learning_rate=best_result.learning_rate,
            epochs=best_result.epochs,
            accuracy=best_result.accuracy,
            loss=best_result.loss,
        )
    )
    print(f"Best model copied to: {BEST_MODEL_DIR / 'model'}")


if __name__ == "__main__":
    main()
