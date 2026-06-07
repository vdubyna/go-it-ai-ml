terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.40.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Lesson      = "10"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "validate" {
  filename         = "${path.module}/lambda/validate.zip"
  function_name    = "${var.project_name}-validate"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "validate.handler"
  runtime          = var.lambda_runtime
  source_code_hash = filebase64sha256("${path.module}/lambda/validate.zip")
  timeout          = 30
  memory_size      = 128

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-validate"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}

resource "aws_lambda_function" "log_metrics" {
  filename         = "${path.module}/lambda/log_metrics.zip"
  function_name    = "${var.project_name}-log-metrics"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "log_metrics.handler"
  runtime          = var.lambda_runtime
  source_code_hash = filebase64sha256("${path.module}/lambda/log_metrics.zip")
  timeout          = 30
  memory_size      = 128

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-log-metrics"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}

data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "step_functions_exec" {
  name               = "${var.project_name}-step-functions-exec"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "step_functions_lambda_invoke" {
  statement {
    actions = ["lambda:InvokeFunction"]

    resources = [
      aws_lambda_function.validate.arn,
      aws_lambda_function.log_metrics.arn,
    ]
  }
}

resource "aws_iam_role_policy" "step_functions_lambda_invoke" {
  name   = "${var.project_name}-lambda-invoke"
  role   = aws_iam_role.step_functions_exec.id
  policy = data.aws_iam_policy_document.step_functions_lambda_invoke.json
}

resource "aws_sfn_state_machine" "training_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.step_functions_exec.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Automated ML training pipeline for lesson 10"
    StartAt = "ValidateData"
    States = {
      ValidateData = {
        Type       = "Task"
        Resource   = aws_lambda_function.validate.arn
        ResultPath = "$.validation"
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
            ]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        Next = "LogMetrics"
      }
      LogMetrics = {
        Type     = "Task"
        Resource = aws_lambda_function.log_metrics.arn
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
            ]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
        End = true
      }
    }
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-pipeline"
  })
}

output "state_machine_arn" {
  description = "ARN Step Function для GitLab CI змінної STEP_FUNCTION_ARN."
  value       = aws_sfn_state_machine.training_pipeline.arn
}

output "validate_lambda_name" {
  description = "Назва Lambda-функції для валідації."
  value       = aws_lambda_function.validate.function_name
}

output "log_metrics_lambda_name" {
  description = "Назва Lambda-функції для логування метрик."
  value       = aws_lambda_function.log_metrics.function_name
}
