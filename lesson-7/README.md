# HW-7: ArgoCD для Helm-деплою MLflow

Цей урок показує базовий GitOps workflow:

- Terraform встановлює ArgoCD в EKS як Helm release у namespace `infra-tools`;
- папка `lesson-7/goit-argo` в поточному репозиторії зберігає Kubernetes manifests і ArgoCD `Application`;
- ArgoCD автоматично синхронізує Git і деплоїть MLflow з Helm-чарту.

## Структура

```text
lesson-7/
├── terraform/
│   ├── eks/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   ├── terraform.tf
│   │   └── variables.tf
│   └── argocd/
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── terraform.tf
│       ├── variables.tf
│       └── values/
│           └── argocd-values.yaml
└── goit-argo/
    ├── application.yaml
    ├── namespaces/
    │   ├── application/
    │   │   ├── nginx.yaml
    │   │   └── ns.yaml
    │   └── infra-tools/
    │       └── ns.yaml
    └── README.md
```

## 1. GitOps-репозиторій

У цьому виконанні ArgoCD читає manifests з поточного репозиторію:

```text
https://github.com/vdubyna/go-it-ai-ml.git
branch: lesson-7
path: lesson-7/goit-argo
```

Перед запуском ArgoCD Terraform треба закомітити й запушити гілку `lesson-7`, бо ArgoCD читає remote GitHub, а не локальні файли.

## 2. Створення EKS

Якщо EKS-кластер уже існує, цей крок не потрібен. Якщо кластера ще немає, створіть його перед ArgoCD.

Увага: `terraform apply` для EKS створює платні AWS-ресурси: EKS control plane, EC2 worker nodes, VPC/networking.

```bash
cd lesson-7/terraform/eks
terraform init
terraform plan
terraform apply
```

За замовчуванням створюється:

- cluster name: `goit-mlops-eks`;
- region: `us-east-1`;
- AWS profile: `vdubyna`;
- managed node group: 2 x `t3.medium`.

Terraform state зберігається в S3 bucket:

```text
goit-mlops-terraform-601535178731
```

Після створення переключіть `kubectl` на EKS:

```bash
aws eks update-kubeconfig \
  --profile vdubyna \
  --region us-east-1 \
  --name goit-mlops-eks

kubectl config current-context
kubectl get nodes
```

## 3. Запуск Terraform для ArgoCD

Terraform читає outputs існуючого EKS-кластера з S3 remote state `eks/terraform.tfstate` і встановлює ArgoCD через Helm.

Для Terraform зараз використовується AWS profile `vdubyna`.
Локально доступні profile-и: `default`, `vdubyna`.

```bash
cd lesson-7/terraform/argocd
terraform init
terraform plan
terraform apply
```

Якщо ваш remote state або GitOps repo має іншу назву:

```bash
terraform apply \
  -var="aws_profile=<aws-profile>" \
  -var="tf_state_bucket=<bucket-name>" \
  -var="eks_state_key=<eks-state-key>" \
  -var="app_repo_url=https://github.com/<user>/<repo>.git"
```

## 4. Перевірка ArgoCD

Перед перевіркою переконайтеся, що `kubectl` дивиться саме в EKS, а не в локальний Docker Desktop:

```bash
kubectl config current-context
aws eks update-kubeconfig \
  --profile vdubyna \
  --region us-east-1 \
  --name <eks-cluster-name>
```

```bash
kubectl get pods -n infra-tools
kubectl get applications -n infra-tools
```

Очікувано мають бути pod-и з префіксом `argocd-` і Application `goit-argo-root`. Після синхронізації з Git також зʼявиться Application `mlflow`.

## 5. Доступ до ArgoCD UI

Отримайте пароль адміністратора:

```bash
kubectl -n infra-tools get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Відкрийте UI:

```bash
kubectl port-forward svc/argocd-server -n infra-tools 8080:80
```

Браузер: `http://localhost:8080`

Логін: `admin`

Пароль: значення з secret вище.

## 6. Перевірка деплою MLflow

```bash
kubectl get pods -n application
kubectl get svc -n application
kubectl get applications -n infra-tools
```

Очікувано:

- `demo-nginx` створюється з GitOps repo як простий Kubernetes manifest;
- `mlflow` створюється ArgoCD Application з `application.yaml`;
- MLflow деплоїться Helm-чартом `bitnami/mlflow`.

## 7. Доступ до MLflow

Для локального доступу використайте port-forward:

```bash
kubectl port-forward -n application svc/mlflow-tracking 5000:80
```

Браузер: `http://localhost:5000`

Логін MLflow: `admin`

Пароль MLflow: `mlflowpassword123`

## GitOps repo

Application manifest лежить у репозиторії:

```text
https://github.com/vdubyna/go-it-ai-ml/tree/lesson-7/lesson-7/goit-argo
```
