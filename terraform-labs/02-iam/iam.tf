data "aws_caller_identity" "current" {}

locals {
  github_oidc_provider_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  ecr_repository_arn                  = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  ecs_service_arn                     = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
  ecs_task_execution_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_task_execution_role_name}"
  ecs_task_role_arn                   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.ecs_task_role_name}"
  console_ecs_task_execution_role_arn = var.console_ecs_task_execution_role_name != "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.console_ecs_task_execution_role_name}" : ""

  github_sub_plain        = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
  github_sub_ids_wildcard = "repo:${var.github_owner}@*/${var.github_repo}@*:ref:refs/heads/${var.github_branch}"
  github_sub_with_ids     = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}"

  github_sub_claims = compact([
    local.github_sub_plain,
    local.github_sub_ids_wildcard,
    local.github_sub_with_ids,
  ])
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_sub_claims
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid     = "GetAuthToken"
    effect  = "Allow"
    actions = ["ecr:GetAuthorizationToken"]

    resources = ["*"]
  }

  statement {
    sid    = "PushToRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]

    resources = [local.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

data "aws_iam_policy_document" "github_actions_ecs" {
  statement {
    sid    = "EcsReadForDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "UpdateService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
    ]

    resources = [local.ecs_service_arn]
  }

  statement {
    sid    = "RegisterTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PassEcsTaskRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]

    resources = compact([
      local.ecs_task_execution_role_arn,
      local.ecs_task_role_arn,
      local.console_ecs_task_execution_role_arn,
    ])

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions_ecs" {
  name   = "ecs-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecs.json
}
