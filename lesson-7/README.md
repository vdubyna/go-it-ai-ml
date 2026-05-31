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

## Повна інсталяція та розгортання

Цей сценарій описує запуск усього проєкту з нуля: Terraform створює EKS, потім встановлює ArgoCD, а ArgoCD читає GitHub і деплоїть MLflow.

Перед стартом потрібні:

- AWS CLI з profile `vdubyna`;
- Terraform;
- `kubectl`;
- Docker, якщо Terraform запускається через Docker image;
- запушена гілка `lesson-7`, бо ArgoCD читає remote GitHub.

Перевірте AWS profile:

```bash
aws configure list-profiles
aws sts get-caller-identity --profile vdubyna
```

Terraform backend використовує S3 bucket:

```text
goit-mlops-terraform-601535178731
```

Якщо bucket ще не створений, створіть його перед `terraform init`:

```bash
aws s3api create-bucket \
  --profile vdubyna \
  --region us-east-1 \
  --bucket goit-mlops-terraform-601535178731

aws s3api put-bucket-versioning \
  --profile vdubyna \
  --region us-east-1 \
  --bucket goit-mlops-terraform-601535178731 \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --profile vdubyna \
  --region us-east-1 \
  --bucket goit-mlops-terraform-601535178731 \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-encryption \
  --profile vdubyna \
  --region us-east-1 \
  --bucket goit-mlops-terraform-601535178731 \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Розгорніть EKS:

```bash
cd lesson-7/terraform/eks
terraform init
terraform plan
terraform apply
```

Після створення кластера переключіть `kubectl` на EKS:

```bash
aws eks update-kubeconfig \
  --profile vdubyna \
  --region us-east-1 \
  --name goit-mlops-eks

kubectl config current-context
kubectl get nodes
```

Закомітьте й запуште GitOps manifests у гілку `lesson-7`:

```bash
git switch lesson-7
git status
git push origin lesson-7
```

Розгорніть ArgoCD:

```bash
cd lesson-7/terraform/argocd
terraform init
terraform plan
terraform apply
```

Після `terraform apply` ArgoCD створить root Application `goit-argo-root`, прочитає `lesson-7/goit-argo` з GitHub і автоматично застосує `application.yaml` для MLflow.

Перевірте результат:

```bash
kubectl get pods -n infra-tools
kubectl get applications -n infra-tools
kubectl get pods -n application
kubectl get svc -n application
```

Очікуваний стан:

- pod-и ArgoCD у namespace `infra-tools` мають бути `Running`;
- `goit-argo-root` і `mlflow` мають бути `Synced` / `Healthy`;
- у namespace `application` мають працювати `demo-nginx`, `mlflow-postgresql`, `mlflow-tracking`;
- service `mlflow-tracking` має тип `LoadBalancer` і зовнішній DNS.

Увага: EKS, EC2 nodes і AWS LoadBalancer є платними ресурсами. Після перевірки домашнього завдання їх варто видалити через Terraform.

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

ArgoCD server встановлений як `ClusterIP`, тому адмінка відкривається локально через `kubectl port-forward`.

Отримайте пароль адміністратора:

```bash
kubectl -n infra-tools get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Відкрийте UI:

```bash
kubectl port-forward svc/argocd-server -n infra-tools 8080:80
```

Адмінка ArgoCD:

```text
http://localhost:8080
```

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

Основний спосіб: MLflow відкритий через AWS LoadBalancer.

```bash
kubectl get svc mlflow-tracking -n application
```

Браузер:

```text
http://a4580cd6e6ac04c7ca76a519e7133c9f-403934489.us-east-1.elb.amazonaws.com
```

Якщо DNS ще не резолвиться відразу після створення LoadBalancer, зачекайте кілька хвилин і перевірте ще раз.

Альтернативний спосіб: відкрити MLflow локально через port-forward.

```bash
kubectl port-forward -n application svc/mlflow-tracking 5500:80
```

Після цього відкрийте:

```text
http://localhost:5500
```

Логін MLflow: `admin`

Пароль MLflow: `mlflowpassword123`

## 8. Видалення та очищення ресурсів

Видаляйте ресурси у такому порядку: спочатку GitOps застосунки й LoadBalancer, потім ArgoCD, потім EKS, і лише в кінці S3 bucket зі state. Так VPC не залишиться заблокованою через Kubernetes LoadBalancer або security groups.

Зупиніть auto-sync root Application, щоб ArgoCD не створював ресурси повторно під час cleanup:

```bash
kubectl patch application goit-argo-root \
  -n infra-tools \
  --type merge \
  -p '{"spec":{"syncPolicy":null}}'
```

Видаліть MLflow Application і дочекайтеся видалення Kubernetes ресурсів, включно з AWS LoadBalancer:

```bash
kubectl delete application mlflow -n infra-tools --wait=true --timeout=300s
kubectl delete namespace application --wait=true --timeout=300s
```

Перевірте, що MLflow LoadBalancer більше не існує:

```bash
aws elb describe-load-balancers \
  --profile vdubyna \
  --region us-east-1 \
  --load-balancer-name a4580cd6e6ac04c7ca76a519e7133c9f
```

Якщо команда повертає `LoadBalancerNotFound`, LoadBalancer видалений.

Щоб Terraform міг швидко видалити root Application, приберіть ArgoCD finalizer з root Application:

```bash
kubectl patch application goit-argo-root \
  -n infra-tools \
  --type json \
  -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

Видаліть ArgoCD:

```bash
cd lesson-7/terraform/argocd
terraform destroy
```

Видаліть EKS і мережеву інфраструктуру:

```bash
cd ../eks
terraform destroy
```

Коли Terraform destroy завершиться, очистіть S3 backend bucket:

```bash
aws s3 rm s3://goit-mlops-terraform-601535178731 --recursive --profile vdubyna

aws s3api delete-bucket \
  --profile vdubyna \
  --region us-east-1 \
  --bucket goit-mlops-terraform-601535178731
```

Фінальна перевірка в AWS:

```bash
aws eks describe-cluster \
  --profile vdubyna \
  --region us-east-1 \
  --name goit-mlops-eks

aws s3api head-bucket \
  --profile vdubyna \
  --bucket goit-mlops-terraform-601535178731
```

Для обох команд очікувано отримати помилку про те, що ресурс не знайдений.

## GitOps repo

Application manifest лежить у репозиторії:

```text
https://github.com/vdubyna/go-it-ai-ml/tree/lesson-7/lesson-7/goit-argo
```
