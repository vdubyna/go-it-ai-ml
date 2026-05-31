# goit-argo

GitOps manifests для домашнього завдання з ArgoCD.

У цьому виконанні ArgoCD читає їх з поточного репозиторію:

```text
https://github.com/vdubyna/go-it-ai-ml.git
branch: lesson-7
path: lesson-7/goit-argo
```

## Що всередині

```text
goit-argo
├── application.yaml
├── namespaces
│   ├── application
│   │   ├── nginx.yaml
│   │   └── ns.yaml
│   └── infra-tools
│       └── ns.yaml
└── README.md
```

## Як це працює

Terraform створює ArgoCD Application `goit-argo-root`, який читає цей репозиторій рекурсивно.

Після `git push` ArgoCD:

- створює namespace `application`;
- створює demo `nginx` deployment/service;
- застосовує `application.yaml`;
- через `application.yaml` деплоїть MLflow Helm-чарт у namespace `application`.

## Перевірка

```bash
kubectl get applications -n infra-tools
kubectl get pods -n application
kubectl get svc -n application
```

## Доступ до MLflow

```bash
kubectl port-forward -n application svc/mlflow-tracking 5000:80
```

Відкрити: `http://localhost:5000`

Логін: `admin`

Пароль: `mlflowpass`
