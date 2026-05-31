# Lesson 9: MLflow Experiments Monitoring

Домашнє завдання з MLOps присвячене моніторингу ML-експериментів у Kubernetes. У роботі розгорнуто MLflow Tracking Server з MinIO та PostgreSQL, додано PushGateway, Prometheus і Grafana, а також підготовлено Python-скрипт, який тренує кілька моделей, логує результати в MLflow і відправляє метрики в Prometheus через PushGateway.

Гілка з реалізацією: [lesson-9](https://github.com/vdubyna/go-it-ai-ml/tree/lesson-9).

## Завдання

Потрібно було:

- розгорнути через ArgoCD інфраструктуру для MLflow experiments monitoring;
- налаштувати MinIO як artifact storage для MLflow;
- налаштувати PostgreSQL як backend store для MLflow;
- підняти PushGateway, Prometheus і Grafana для збору та перегляду метрик;
- написати скрипт тренування, який запускає кілька експериментів, логує параметри, метрики й модель;
- вибрати найкращу модель і зберегти її в `best_model/`;
- показати метрики `accuracy` і `loss` у Grafana через Prometheus.

## Очікувані Результати

- MLflow, MinIO, PostgreSQL, PushGateway розгорнуті через ArgoCD;
- скрипт тренує кілька моделей і логує метрики;
- найкраща модель скопійована в `best_model/`;
- метрики `accuracy` і `loss` видно в `Grafana -> Prometheus -> Explore`;
- усі інструкції для розгортання, запуску, перевірки й очищення є в цьому README.

## Що Реалізовано

- `MinIO` у namespace `application` з bucket `mlflow-artifacts`;
- `PostgreSQL` у namespace `application` з базою `mlflow`;
- `MLflow Tracking Server` у namespace `application`, сервіс `ClusterIP`, порт `5000`;
- `PushGateway` у namespace `monitoring`, сервіс `ClusterIP`, порт `9091`;
- `Prometheus` у namespace `monitoring`, який scrape-ить PushGateway;
- `Grafana` у namespace `monitoring` з datasource `Prometheus` і dashboard `MLflow Experiment Monitoring`;
- `experiments/train_and_push.py`, який тренує grid моделей `SGDClassifier` на Iris dataset;
- логування в MLflow: params `learning_rate`, `epochs`, `dataset`, metrics `accuracy`, `loss`, artifact `model/`;
- пуш метрик `mlflow_accuracy` і `mlflow_loss` у PushGateway;
- копіювання найкращої моделі в `best_model/model/`.

## Структура Проєкту

```text
mlops-experiments/
├── argocd/
│   └── applications/
│       ├── grafana.yaml
│       ├── mlflow.yaml
│       ├── minio.yaml
│       ├── postgres.yaml
│       ├── prometheus.yaml
│       └── pushgateway.yaml
├── experiments/
│   ├── .env.example
│   ├── requirements.txt
│   └── train_and_push.py
├── best_model/
│   └── model/
└── screenshots/
    └── grafana-dashboard.jpg
```

## Компоненти Та Дані

| Компонент | Namespace | Сервіс | Порт | Призначення |
| --- | --- | --- | --- | --- |
| MLflow | `application` | `mlflow-tracking` | `5000` | UI, tracking server, runs, metrics, artifacts |
| MinIO | `application` | `minio` | `9000`, `9001` | S3-compatible artifact storage |
| PostgreSQL | `application` | `mlflow-postgres-postgresql` | `5432` | backend store для MLflow |
| PushGateway | `monitoring` | `pushgateway` | `9091` | приймає метрики зі скрипта |
| Prometheus | `monitoring` | `prometheus-server` | `9090` | scrape PushGateway і PromQL |
| Grafana | `monitoring` | `grafana` | `80` | Explore і dashboard для MLflow метрик |

Використані Helm charts:

| Application | Chart | Version |
| --- | --- | --- |
| `minio` | `bitnami/minio` | `13.7.2` |
| `mlflow-postgres` | `bitnami/postgresql` | `12.5.6` |
| `mlflow` | `bitnami/mlflow` | `5.1.17` |
| `pushgateway` | `prometheus-community/prometheus-pushgateway` | `3.6.0` |
| `prometheus` | `prometheus-community/prometheus` | `29.9.0` |
| `grafana` | `grafana/grafana` | `10.5.15` |

MinIO credentials для навчального середовища:

```text
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
```

Grafana credentials:

```text
username: admin
password: admin
```

## Розгортання Через ArgoCD

Маніфести ArgoCD Application лежать у:

```text
lesson-9/mlops-experiments/argocd/applications
```

Якщо ArgoCD встановлено Terraform-ом з `lesson-7`, root Application має дивитись на цю папку:

```text
repoURL: https://github.com/vdubyna/go-it-ai-ml.git
targetRevision: lesson-9
path: lesson-9/mlops-experiments/argocd
directory.recurse: true
```

Оновлення root Application через Terraform:

```bash
cd lesson-7/terraform/argocd
terraform apply \
  -var="app_repo_branch=lesson-9" \
  -var="app_repo_path=lesson-9/mlops-experiments/argocd"
```

Якщо потрібно примусово оновити ArgoCD після push:

```bash
kubectl -n infra-tools annotate application goit-argo-root \
  argocd.argoproj.io/refresh=hard --overwrite
```

## Перевірка Кластера

ArgoCD applications:

```bash
kubectl get applications -n infra-tools
```

Очікуваний стан:

```text
goit-argo-root    Synced    Healthy
grafana           Synced    Healthy
minio             Synced    Healthy
mlflow            Synced    Healthy
mlflow-postgres   Synced    Healthy
prometheus        Synced    Healthy
pushgateway       Synced    Healthy
```

Pods:

```bash
kubectl get pods -n application
kubectl get pods -n monitoring
```

Services:

```bash
kubectl get svc -n application
kubectl get svc -n monitoring
```

Очікувані сервіси:

```text
application/mlflow-tracking                  ClusterIP  5000
application/minio                            ClusterIP  9000,9001
application/mlflow-postgres-postgresql       ClusterIP  5432
monitoring/pushgateway                       ClusterIP  9091
monitoring/prometheus-server                 ClusterIP  9090
monitoring/grafana                           ClusterIP  80
```

## Port-Forward Для Локальної Перевірки

MLflow UI:

```bash
kubectl port-forward -n application svc/mlflow-tracking 5000:5000
```

Якщо локальний порт `5000` зайнятий:

```bash
kubectl port-forward -n application svc/mlflow-tracking 5500:5000
```

MinIO API:

```bash
kubectl port-forward -n application svc/minio 9000:9000
```

PushGateway:

```bash
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

Prometheus:

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
```

Grafana:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Локальні адреси:

```text
MLflow UI:    http://localhost:5000
MinIO API:    http://localhost:9000
PushGateway:  http://localhost:9091
Prometheus:   http://localhost:9090
Grafana:      http://localhost:3000
```

## Запуск Експериментів

Підготовка Python-середовища:

```bash
cd lesson-9/mlops-experiments/experiments
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Для локального запуску через port-forward у `.env`:

```env
MLFLOW_TRACKING_URI=http://localhost:5000
PUSHGATEWAY_URL=http://localhost:9091
MLFLOW_EXPERIMENT_NAME=Iris Quality Monitoring
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
```

Якщо MLflow port-forward зроблений на `5500:5000`, змініть:

```env
MLFLOW_TRACKING_URI=http://localhost:5500
```

Запуск:

```bash
python train_and_push.py
```

Для запуску з pod-а всередині Kubernetes використовуйте service DNS:

```env
MLFLOW_TRACKING_URI=http://mlflow-tracking.application.svc.cluster.local:5000
PUSHGATEWAY_URL=http://pushgateway.monitoring.svc.cluster.local:9091
MLFLOW_S3_ENDPOINT_URL=http://minio.application.svc.cluster.local:9000
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
```

Скрипт тренує 9 моделей:

```text
learning_rates = [0.001, 0.01, 0.05]
epochs_values  = [200, 500, 1000]
```

Найкраща модель вибирається за `accuracy DESC`, а при рівності - за `loss ASC`. Після успішного запуску вона копіюється сюди:

```text
lesson-9/mlops-experiments/best_model/model/
```

## Результати Тестового Запуску

Experiment у MLflow:

```text
Iris Quality Monitoring
```

Метрики, які логуються в MLflow:

```text
accuracy
loss
```

Метрики, які пушаться у PushGateway і доступні в Prometheus:

```text
mlflow_accuracy
mlflow_loss
```

Labels для Prometheus metrics:

```text
run_id
learning_rate
epochs
```

Найкращий run у поточному тестовому запуску:

```text
run_id:        5ba14edafe0941efb792a0f182cfa482
learning_rate: 0.05
epochs:        1000
accuracy:      0.8421
loss:          0.2742
```

Збережена модель:

```text
lesson-9/mlops-experiments/best_model/model/
```

У директорії моделі є стандартні MLflow artifacts:

```text
MLmodel
model.pkl
conda.yaml
python_env.yaml
requirements.txt
```

## Перевірка MLflow

Відкрийте MLflow UI:

```text
http://localhost:5000
```

Або, якщо використовується локальний порт `5500`:

```text
http://localhost:5500
```

У experiment `Iris Quality Monitoring` мають бути runs з:

- params: `learning_rate`, `epochs`, `dataset`;
- metrics: `accuracy`, `loss`;
- artifacts: `model/`.

Перевірка через API:

```bash
curl "http://localhost:5000/api/2.0/mlflow/experiments/get-by-name?experiment_name=Iris%20Quality%20Monitoring"
```

Якщо MLflow працює на локальному `5500`, замініть порт у команді.

## Перевірка PushGateway

```bash
curl http://localhost:9091/metrics | grep mlflow_
```

Очікувані метрики:

```text
mlflow_accuracy
mlflow_loss
```

## Перевірка Prometheus

Prometheus UI:

```text
http://localhost:9090
```

PromQL-запити:

```promql
mlflow_accuracy
mlflow_loss
```

Перевірка через API:

```bash
curl "http://localhost:9090/api/v1/query?query=mlflow_accuracy"
curl "http://localhost:9090/api/v1/query?query=mlflow_loss"
```

Target PushGateway можна перевірити тут:

```text
http://localhost:9090/targets
```

## Перевірка Grafana

Grafana UI:

```text
http://localhost:3000
```

Login:

```text
admin / admin
```

Datasource `Prometheus` створюється автоматично.

Для ручної перевірки відкрийте:

```text
Explore -> Prometheus
```

І виконайте запити:

```promql
mlflow_accuracy
mlflow_loss
```

Dashboard створюється автоматично:

```text
Dashboards -> MLOps -> MLflow Experiment Monitoring
```

Пряме посилання після port-forward:

```text
http://localhost:3000/d/mlflow-experiment-monitoring/mlflow-experiment-monitoring?orgId=1
```

Dashboard містить:

- `MLflow Accuracy` - графік accuracy по run-ах;
- `MLflow Loss` - графік loss по run-ах;
- `Experiment Metrics by Run` - таблицю з labels `run_id`, `learning_rate`, `epochs`.

Якщо графіки порожні, встановіть time range `Last 1 hour` або `Last 6 hours` і натисніть refresh.

Візуальний результат dashboard:

![Grafana dashboard with MLflow experiment metrics](screenshots/grafana-dashboard.jpg)

## Очищення Проєкту

Зупиніть локальні `port-forward` процеси комбінацією `Ctrl+C` у відповідних терміналах.

Якщо потрібно прибрати тільки застосунки lesson-9 з кластера, видаліть ArgoCD applications:

```bash
kubectl delete application grafana minio mlflow mlflow-postgres prometheus pushgateway -n infra-tools
```

Якщо root Application продовжує синхронізувати lesson-9, спочатку змініть або видаліть root Application, інакше ArgoCD може створити ресурси знову.

Якщо інфраструктура була піднята Terraform-ом з `lesson-7`, після перевірки можна видалити ArgoCD та EKS:

```bash
cd lesson-7/terraform/argocd
terraform destroy

cd ../eks
terraform destroy
```

Якщо S3 bucket використовується для Terraform state, його можна залишити. Вартість S3 залежить від обсягу збережених даних.
