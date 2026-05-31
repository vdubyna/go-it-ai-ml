# Lesson 9: MLflow experiments + PushGateway

Цей проєкт розгортає MLflow-інфраструктуру через ArgoCD і запускає серію ML-експериментів для Iris dataset. Скрипт логує параметри, метрики й модель у MLflow, пушить `mlflow_accuracy` та `mlflow_loss` у Prometheus PushGateway, а після завершення завантажує найкращу модель у `best_model/`.

## Структура

```text
mlops-experiments/
├── argocd/
│   └── applications/
│       ├── mlflow.yaml
│       ├── minio.yaml
│       ├── postgres.yaml
│       └── pushgateway.yaml
├── experiments/
│   ├── .env.example
│   ├── requirements.txt
│   └── train_and_push.py
├── best_model/
└── screenshots/
```

## ArgoCD

Маніфести лежать у `lesson-9/mlops-experiments/argocd/applications`.

Якщо ArgoCD уже розгорнутий з попереднього уроку, достатньо, щоб root Application дивився на цю папку:

```text
repoURL: https://github.com/vdubyna/go-it-ai-ml.git
targetRevision: lesson-9
path: lesson-9/mlops-experiments/argocd
directory.recurse: true
```

Якщо використовуєте Terraform з `lesson-7`, можна оновити root Application так:

```bash
cd lesson-7/terraform/argocd
terraform apply \
  -var="app_repo_branch=lesson-9" \
  -var="app_repo_path=lesson-9/mlops-experiments/argocd"
```

Або можна застосувати Application-и вручну:

```bash
kubectl apply -f lesson-9/mlops-experiments/argocd/applications/
```

Перевірка ArgoCD:

```bash
kubectl get applications -n infra-tools
kubectl get pods -n application
kubectl get svc -n application
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Очікувані сервіси:

```text
application/mlflow-tracking        ClusterIP  5000
application/minio                  ClusterIP  9000
application/mlflow-postgres-postgresql ClusterIP 5432
monitoring/pushgateway             ClusterIP  9091
```

## Port-forward

MLflow UI:

```bash
kubectl port-forward -n application svc/mlflow-tracking 5000:5000
```

MinIO API для локального логування артефактів:

```bash
kubectl port-forward -n application svc/minio 9000:9000
```

PushGateway:

```bash
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

Після цього:

- MLflow UI: http://localhost:5000
- PushGateway: http://localhost:9091

Усередині кластера PushGateway доступний як:

```text
http://pushgateway.monitoring.svc.cluster.local:9091
```

## Запуск експериментів

```bash
cd lesson-9/mlops-experiments/experiments
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python train_and_push.py
```

Для локального запуску через port-forward у `.env` достатньо таких значень:

```env
MLFLOW_TRACKING_URI=http://localhost:5000
PUSHGATEWAY_URL=http://localhost:9091
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
```

Якщо скрипт запускається з pod-а всередині кластера:

```env
MLFLOW_TRACKING_URI=http://mlflow-tracking.application.svc.cluster.local:5000
PUSHGATEWAY_URL=http://pushgateway.monitoring.svc.cluster.local:9091
MLFLOW_S3_ENDPOINT_URL=http://minio.application.svc.cluster.local:9000
```

Після успішного запуску найкраща модель буде завантажена в:

```text
lesson-9/mlops-experiments/best_model/model/
```

## Перевірка MLflow

```bash
kubectl get pods -n application
kubectl get svc mlflow-tracking -n application
kubectl logs -n application -l app.kubernetes.io/name=mlflow
```

Відкрийте http://localhost:5000 і перевірте experiment `Iris Quality Monitoring`. У run-ах мають бути:

- params: `learning_rate`, `epochs`, `dataset`;
- metrics: `accuracy`, `loss`;
- artifacts: `model/`.

## Перевірка PushGateway

```bash
curl http://localhost:9091/metrics | grep mlflow_
```

Очікувані метрики:

```text
mlflow_accuracy
mlflow_loss
```

## Grafana

У Grafana відкрийте `Explore`, оберіть datasource `Prometheus` і виконайте запити:

```promql
mlflow_accuracy
mlflow_loss
```

Для таблиці найзручніше увімкнути `Table` view. Для графіка можна використати:

```promql
max by (run_id, learning_rate, epochs) (mlflow_accuracy)
min by (run_id, learning_rate, epochs) (mlflow_loss)
```

Якщо метрики не видно, перевірте, що Prometheus scrape-ить сервіс `pushgateway` у namespace `monitoring`. У маніфесті додані scrape-анотації `prometheus.io/scrape=true` і `prometheus.io/port=9091`; для kube-prometheus-stack може знадобитись ServiceMonitor з labels саме вашого Prometheus release.

## Скриншоти для здачі

Додайте скриншоти після запуску:

- MLflow UI: `lesson-9/mlops-experiments/screenshots/mlflow-ui.png`
- Grafana Explore: `lesson-9/mlops-experiments/screenshots/grafana-explore.png`

## Cleanup

Після перевірки видаліть платні ресурси:

```bash
cd lesson-7/terraform/argocd
terraform destroy

cd ../eks
terraform destroy
```

Якщо S3 bucket використовується для Terraform state, його можна залишити. Вартість S3 орієнтовно залежить від обсягу збережених даних.
