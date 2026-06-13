# HW-5: VPC та EKS через Terraform

Це домашнє завдання створює базову AWS-інфраструктуру для майбутніх ML-сервісів:

- VPC через офіційний модуль `terraform-aws-modules/vpc/aws`;
- EKS через офіційний модуль `terraform-aws-modules/eks/aws`;
- два EKS managed node group-и: `cpu` та `gpu`;
- окремі Terraform стеки `vpc/` і `eks/`;
- підключення EKS до VPC через `data.terraform_remote_state`.

## Структура

```text
lesson-5/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tf
├── backend.tf
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tf
│   └── backend.tf
├── eks/
│   ├── data.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tf
│   └── backend.tf
└── README.md
```

Root `main.tf` імпортує обидва локальні модулі:

```hcl
module "vpc" {
  source = "./vpc"
}

module "eks" {
  source = "./eks"
}
```

Для перевірки `terraform_remote_state` треба запускати як описано нижче: спочатку `vpc/`, потім `eks/`.

## Налаштування

За замовчуванням використовується:

| Параметр | Значення |
| --- | --- |
| AWS profile | `vdubyna` |
| AWS region | `us-east-1` |
| Terraform state bucket | `goit-mlops-terraform-601535178731` |
| VPC state key | `lesson-5/vpc/terraform.tfstate` |
| EKS state key | `lesson-5/eks/terraform.tfstate` |
| Cluster name | `goit-mlops-lesson-5-eks` |
| Node groups | `cpu`, `gpu` |
| Instance type | `t3.micro` |

`gpu` node group має окремі labels/tags для ML/GPU задач, але за замовчуванням теж використовує `t3.micro`, щоб не створити дорогий GPU instance випадково. Для реального GPU можна передати, наприклад:

```bash
terraform apply -var='gpu_node_instance_types=["g4dn.xlarge"]'
```

## Перед Стартом

Потрібні:

- AWS CLI з profile `vdubyna`;
- Terraform `>= 1.5.0`;
- `kubectl`;
- S3 bucket для remote state.

Перевірка AWS profile:

```bash
aws sts get-caller-identity --profile vdubyna
```

Якщо S3 bucket для state ще не створений:

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
```

## 1. Створення VPC

```bash
cd lesson-5/vpc
terraform init
terraform plan
terraform apply
```

Після `apply` Terraform запише outputs у S3 state `lesson-5/vpc/terraform.tfstate`. Саме їх читає EKS стек через `data.terraform_remote_state`.

Очікувані outputs:

- `vpc_id`;
- `public_subnets`;
- `private_subnets`;
- `azs`;
- `aws_region`.

## 2. Створення EKS

```bash
cd ../eks
terraform init
terraform plan
terraform apply
```

EKS стек читає VPC outputs з S3:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket  = "goit-mlops-terraform-601535178731"
    key     = "lesson-5/vpc/terraform.tfstate"
    region  = "us-east-1"
    profile = "vdubyna"
  }
}
```

За замовчуванням worker nodes запускаються у public subnets, щоб не створювати NAT Gateway для навчального середовища. Для production-like варіанту:

```bash
cd ../vpc
terraform apply -var="enable_nat_gateway=true"

cd ../eks
terraform apply -var="node_subnet_type=private"
```

## 3. Підключення Kubectl

Після успішного створення EKS:

```bash
terraform output -raw configure_kubectl
```

Або одразу:

```bash
aws eks update-kubeconfig \
  --profile vdubyna \
  --region us-east-1 \
  --name goit-mlops-lesson-5-eks
```

Перевірка:

```bash
kubectl config current-context
kubectl get nodes
kubectl get nodes --show-labels
```

Очікувано має бути видно дві managed node group-и з labels:

- `workload=cpu`;
- `workload=gpu`.

## Root Варіант

У корені `lesson-5/` є інтегрований Terraform stack, який викликає `module "vpc"` і `module "eks"` напряму та передає VPC outputs без remote state:

```bash
cd lesson-5
terraform init
terraform plan
terraform apply
```

Для здачі домашнього завдання краще використовувати окремий запуск `vpc/` -> `eks/`, бо так явно перевіряється `terraform_remote_state`.

## Очищення Ресурсів

AWS EKS, EC2 nodes, NAT Gateway та Load Balancer-и можуть коштувати гроші. Після перевірки видаліть ресурси у зворотному порядку:

```bash
cd lesson-5/eks
terraform destroy

cd ../vpc
terraform destroy
```

Якщо запускали root stack:

```bash
cd lesson-5
terraform destroy
```

S3 bucket зі state можна залишити: його зберігання дешеве, а видалення bucket-а разом зі state ускладнить подальший `destroy`.
