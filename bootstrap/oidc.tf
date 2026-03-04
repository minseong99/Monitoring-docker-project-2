provider "aws" {
  region  = "ap-northeast-1"
  profile = "project_1"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 2. GitHub パイプラインが使う　IAM Role生成
resource "aws_iam_role" "github_actions" {
  name = "github-actions-docker-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:minseong99/aws-with-terraform-project-1:ref:refs/heads/*",
              "repo:minseong99/Monitoring-docker-project-2:ref:refs/heads/main"
            ]
          }
        }
      }
    ]
  })
}

# GitHub Actionsに「本当に必要な権限だけ」を付与する（最小権限の原則, custom policy)
resource "aws_iam_role_policy" "github_actions_deploy_policy" {
  name = "github-actions-ssm-deploy-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",   # EC2のIPやIDを検索する権限
          "ssm:SendCommand",         # デプロイの命令を送る権限
          "ssm:GetCommandInvocation" # 成功したか結果を確認する権限
        ]
        Resource = "*"
      }
    ]
  })
}


# 出力値: パイプラインに使う ARN 値出力
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "これはGitHub Actions パイプラインに入力する IAM Role ARNです"
}