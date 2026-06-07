# Final Project: AIOps Quality Pipeline

Фінальний проєкт демонструє повний MLOps/AIOps workflow для inference-сервісу: FastAPI завантажує `.pkl` модель, виконує прогноз, перевіряє input quality/drift через Great Expectations і z-score правила, пише structured logs у stdout, віддає Prometheus metrics, деплоїться через Helm та ArgoCD, а retrain запускається через GitLab CI.

## Архітектура

```text
client
  -> FastAPI /predict
  -> model/model.pkl
  -> drift detector
  -> stdout logs -> Promtail -> Loki
  -> /metrics -> Prometheus -> Grafana
  -> optional GitLab trigger webhook -> retrain-model job
  -> Docker image + Helm values update
  -> ArgoCD auto-sync
```

## Структура Проєкту

```text
aiops-quality-project/
├── app/
│   └── main.py
├── model/
│   ├── train.py
│   ├── model.pkl
│   └── metadata.json
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       └── service.yaml
├── argocd/
│   └── application.yaml
├── grafana/
│   └── dashboards.json
├── prometheus/
│   └── additionalScrapeConfigs.yaml
├── .gitlab-ci.yml
├── Dockerfile
├── requirements.txt
└── README.md
```

## Що Реалізовано

- FastAPI inference service з endpoint-ами `/health`, `/predict`, `/metrics`;
- модель `model/model.pkl`, яка завантажується при старті;
- окрема функція `predict(data)` у `app/main.py`;
- drift detector:
  - Great Expectations range validation для feature quality;
  - z-score перевірка проти reference distribution;
  - `print("Drift detected")` і structured log при спрацюванні;
  - optional webhook через `DRIFT_WEBHOOK_URL`;
- Prometheus metrics:
  - `aiops_quality_requests_total`;
  - `aiops_quality_request_latency_seconds`;
  - `aiops_quality_drift_alerts_total`;
  - `aiops_quality_model_info`;
- Helm chart з Deployment, Service, probes і Prometheus annotations;
- ArgoCD `Application` з auto-sync;
- Grafana dashboard для request rate, latency і drift alerts;
- GitLab CI job `retrain-model`, який тренує нову модель, збирає Docker image, пушить image і оновлює Helm values.

## Локальний Запуск

Підготовка Python-середовища:

```bash
cd aiops-quality-project
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Запуск API:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Перевірка health:

```bash
curl http://localhost:8000/health
```

Очікувана відповідь:

```json
{
  "status": "ok",
  "model_version": "0.1.0"
}
```

## Тест Predict Запиту

Нормальний запит без drift:

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"request_id":"normal-1","features":[0.42,0.50,0.02,130]}'
```

Приклад відповіді:

```json
{
  "prediction": 0,
  "probability": 0.186335,
  "drift_detected": false,
  "drift_reasons": [],
  "model_version": "0.1.0"
}
```

Запит, який має викликати drift:

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"request_id":"drift-1","features":[0.99,0.98,0.40,900]}'
```

У відповіді має бути:

```json
{
  "drift_detected": true
}
```

## Перевірка Логування

Локально logs видно в терміналі, де запущений `uvicorn`.

У Kubernetes:

```bash
kubectl logs -n application deploy/aiops-quality-api-aiops-quality-api
```

Для drift-запиту в логах має бути:

```text
Drift detected
```

Також сервіс пише JSON logs з input features, prediction response і drift reasons. Promtail збирає stdout контейнерів і передає ці записи в Loki.

## Перевірка Метрик

Локально:

```bash
curl http://localhost:8000/metrics
```

Корисні метрики:

```text
aiops_quality_requests_total
aiops_quality_request_latency_seconds_bucket
aiops_quality_drift_alerts_total
aiops_quality_model_info
```

Prometheus scrape config лежить у:

```text
prometheus/additionalScrapeConfigs.yaml
```

Helm Deployment також має annotations:

```text
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
prometheus.io/port: "8000"
```

## Docker Image

Збірка:

```bash
cd aiops-quality-project
docker build -t aiops-quality-api:local .
```

Запуск:

```bash
docker run --rm -p 8000:8000 aiops-quality-api:local
```

## Helm Деплой

Перевірка шаблонів:

```bash
cd aiops-quality-project
helm lint helm
helm template aiops-quality-api helm
```

Деплой напряму через Helm:

```bash
helm upgrade --install aiops-quality-api ./helm \
  --namespace application \
  --create-namespace \
  --set image.repository=<registry>/aiops-quality-api \
  --set image.tag=0.1.0
```

Port-forward:

```bash
kubectl port-forward -n application svc/aiops-quality-api-aiops-quality-api 8000:8000
```

Після цього API доступний на:

```text
http://localhost:8000
```

## ArgoCD

Application manifest:

```text
argocd/application.yaml
```

Застосування:

```bash
kubectl apply -f aiops-quality-project/argocd/application.yaml
```

Перевірка:

```bash
kubectl get applications -n infra-tools
kubectl get pods -n application
kubectl get svc -n application
```

ArgoCD читає Helm chart з:

```text
repoURL: https://github.com/vdubyna/go-it-ai-ml.git
path: aiops-quality-project/helm
targetRevision: main
```

Auto-sync увімкнений через:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

## Grafana

Dashboard JSON:

```text
grafana/dashboards.json
```

Панелі:

- Prediction requests per minute;
- Prediction latency p95;
- Drift alerts by reason.

Port-forward Grafana, якщо вона встановлена як у попередніх уроках:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Потім імпортувати dashboard JSON у Grafana UI.

## GitLab CI Retrain

CI файл:

```text
.gitlab-ci.yml
```

Job:

```text
retrain-model
```

Що робить job:

1. запускає `python3 model/train.py`;
2. генерує новий `model/model.pkl` і `model/metadata.json`;
3. збирає Docker image;
4. пушить image у GitLab Container Registry;
5. оновлює `helm/values.yaml` новим image tag;
6. комітить зміни;
7. пушить їх назад у гілку, якщо заданий `GITLAB_TOKEN`;
8. ArgoCD бачить зміну Helm chart і автоматично синхронізує deployment.

Потрібні GitLab variables:

| Змінна | Призначення |
| --- | --- |
| `CI_REGISTRY_USER` | GitLab registry user, зазвичай доступний автоматично |
| `CI_REGISTRY_PASSWORD` | GitLab registry password, зазвичай доступний автоматично |
| `CI_REGISTRY` | GitLab registry host, зазвичай доступний автоматично |
| `CI_REGISTRY_IMAGE` | registry path, зазвичай доступний автоматично |
| `GITLAB_TOKEN` | token з правом push у repo для оновлення Helm values |

Job можна запустити вручну або через pipeline trigger.

## Drift Webhook Для Retrain

FastAPI сервіс може викликати webhook при drift, якщо задано:

```text
DRIFT_WEBHOOK_URL
```

Для GitLab trigger це може бути URL такого типу:

```text
https://gitlab.com/api/v4/projects/<PROJECT_ID>/trigger/pipeline?token=<TRIGGER_TOKEN>&ref=main
```

У Helm це задається так:

```bash
helm upgrade --install aiops-quality-api ./helm \
  --namespace application \
  --set env.driftWebhookUrl="https://gitlab.com/api/v4/projects/<PROJECT_ID>/trigger/pipeline?token=<TRIGGER_TOKEN>&ref=main"
```

Для навчальної перевірки достатньо побачити `Drift detected` у logs. Webhook можна залишити порожнім.

## Оновлення Моделі Вручну

```bash
cd aiops-quality-project
python3 model/train.py --output model/model.pkl --metadata model/metadata.json --version 0.2.0
docker build -t aiops-quality-api:0.2.0 .
```

Після push image потрібно оновити:

```yaml
image:
  repository: <registry>/aiops-quality-api
  tag: "0.2.0"
```

у `helm/values.yaml`. ArgoCD після commit/push підтягне новий chart.

## Перевірка Повного Сценарію

1. Задеплоїти сервіс через ArgoCD.
2. Виконати `kubectl port-forward`.
3. Надіслати normal `/predict` request.
4. Надіслати drift `/predict` request.
5. Перевірити `kubectl logs`, що є `Drift detected`.
6. Перевірити `/metrics`, що зросли request та drift counters.
7. Імпортувати Grafana dashboard і побачити трафік.
8. Запустити GitLab job `retrain-model`.
9. Перевірити, що згенерована нова модель і оновлений Helm image tag.
10. Перевірити, що ArgoCD синхронізував оновлений deployment.
