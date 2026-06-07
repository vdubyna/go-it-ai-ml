# Lesson 10: Автоматизоване Тренування Моделей

Це домашнє завдання автоматизує запуск навчального ML-пайплайну через AWS Step Functions. Terraform створює IAM ролі, дві Lambda-функції та Step Function, а GitLab CI запускає execution при push і передає контекст коміту через JSON.

## Структура Проєкту

```text
mlops-train-automation/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── lambda/
│       ├── validate.py
│       ├── log_metrics.py
│       ├── validate.zip
│       └── log_metrics.zip
├── .gitlab-ci.yml
└── README.md
```

## Що Реалізовано

- `validate.py` перевіряє вхідний JSON і повертає статус `valid`;
- `log_metrics.py` імітує логування метрик `accuracy` і `loss`;
- `aws_lambda_function.validate` та `aws_lambda_function.log_metrics` підключають `.zip` архіви з `terraform/lambda/`;
- `aws_sfn_state_machine.training_pipeline` виконує кроки `ValidateData -> LogMetrics`;
- `.gitlab-ci.yml` містить job `train-model`, який використовує офіційний image `amazon/aws-cli:2.15.0` і викликає `aws stepfunctions start-execution`.

## 1. Збірка Lambda-Архівів

Архіви потрібні Terraform-ресурсам `aws_lambda_function`.

```bash
cd lesson-10/mlops-train-automation/terraform/lambda
zip validate.zip validate.py
zip log_metrics.zip log_metrics.py
```

Після зміни Python-коду архіви треба зібрати повторно.

## 2. Розгортання Через Terraform

Перед запуском потрібні:

- AWS CLI з налаштованим profile `vdubyna` або іншим profile;
- Terraform `>= 1.5.0`;
- права AWS на створення IAM Role/Policy, Lambda та Step Functions.

Перевірка AWS profile:

```bash
aws sts get-caller-identity --profile vdubyna
```

Розгортання:

```bash
cd lesson-10/mlops-train-automation/terraform
terraform init
terraform plan
terraform apply
```

Якщо треба використати інший profile або region:

```bash
terraform apply \
  -var="aws_profile=default" \
  -var="aws_region=us-east-1"
```

Після успішного `apply` Terraform виведе `state_machine_arn`. Це значення потрібно додати в GitLab CI/CD змінну `STEP_FUNCTION_ARN`.

## 3. Ручний Запуск Step Function

Через AWS CLI:

```bash
aws stepfunctions start-execution \
  --profile vdubyna \
  --region us-east-1 \
  --state-machine-arn "$(terraform output -raw state_machine_arn)" \
  --name "manual-train-$(date +%s)" \
  --input '{"source":"manual-cli","commit":"local-test","branch":"lesson-10"}'
```

Через AWS Console:

1. Відкрити AWS Console.
2. Перейти в `Step Functions`.
3. Знайти state machine `mlops-train-automation-pipeline`.
4. Натиснути `Start execution`.
5. Передати JSON з прикладу нижче.
6. Перевірити, що стани `ValidateData` і `LogMetrics` завершились успішно.

Приклад JSON:

```json
{
  "source": "manual-console",
  "commit": "abc1234",
  "branch": "lesson-10"
}
```

## 4. GitLab CI

Файл `.gitlab-ci.yml` описує один stage `train` і job `train-model`. Job запускається при push, бере ARN Step Function зі змінної `STEP_FUNCTION_ARN` та передає в AWS такий JSON:

```json
{
  "source": "gitlab-ci",
  "commit": "$CI_COMMIT_SHORT_SHA",
  "branch": "$CI_COMMIT_REF_NAME",
  "pipeline_id": "$CI_PIPELINE_ID",
  "pipeline_url": "$CI_PIPELINE_URL"
}
```

Потрібні GitLab CI/CD variables:

| Змінна | Призначення |
| --- | --- |
| `STEP_FUNCTION_ARN` | ARN state machine з `terraform output -raw state_machine_arn` |
| `AWS_ACCESS_KEY_ID` | Access key для AWS IAM user або тимчасових credentials |
| `AWS_SECRET_ACCESS_KEY` | Secret key для AWS IAM user або тимчасових credentials |
| `AWS_DEFAULT_REGION` | AWS region, за замовчуванням `us-east-1` |
| `AWS_SESSION_TOKEN` | Потрібна лише для тимчасових credentials |

Мінімальні права для GitLab credentials:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "states:StartExecution",
      "Resource": "arn:aws:states:us-east-1:123456789012:stateMachine:mlops-train-automation-pipeline"
    }
  ]
}
```

Для production краще використовувати OIDC і IAM роль з тимчасовими credentials, щоб не зберігати постійні AWS ключі в CI.

## 5. Перевірка Результату

Після запуску через GitLab CI або вручну:

```bash
aws stepfunctions list-executions \
  --profile vdubyna \
  --region us-east-1 \
  --state-machine-arn "$(terraform output -raw state_machine_arn)" \
  --max-results 5
```

У деталях execution має бути видно два кроки:

```text
ValidateData -> LogMetrics
```

Логи Lambda можна перевірити в AWS Console у `CloudWatch Logs` для функцій:

```text
mlops-train-automation-validate
mlops-train-automation-log-metrics
```

## 6. Очищення Ресурсів

Після перевірки домашнього завдання ресурси можна видалити:

```bash
cd lesson-10/mlops-train-automation/terraform
terraform destroy
```
