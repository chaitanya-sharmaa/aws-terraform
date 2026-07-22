data "aws_iam_policy_document" "bedrock_access" {
  statement {
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"] # Adjust to specific model ARNs in production if needed
  }
}

resource "aws_iam_policy" "sre_bedrock_policy" {
  name        = "AI_SRE_Bedrock_Access"
  description = "Allows the AI SRE Agent to invoke Bedrock models"
  policy      = data.aws_iam_policy_document.bedrock_access.json
}

module "sre_agent_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "ai-sre-agent-role"

  role_policy_arns = {
    policy = aws_iam_policy.sre_bedrock_policy.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account_name}"]
    }
  }
}
