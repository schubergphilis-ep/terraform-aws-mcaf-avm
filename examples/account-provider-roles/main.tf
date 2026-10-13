provider "aws" {
  region = "eu-west-1"
}

provider "mcaf" {
  aws {
    region = "eu-west-1"
  }
}

provider "tfe" {
  organization = "myorg"
}

# The module's own provider reaches the account through a read-only role during the plan phase
# and through AWSControlTowerExecution during the apply phase. The role is created by the apply
# phase, so for a new account `create` and `assume` can be set together. For an account that
# already exists, apply `create` first and set `assume` on a later run (see UPGRADING.md).
module "aws_account" {
  source = "../.."
  name   = "my-aws-account"

  account = {
    email               = "my-aws-account@email.com"
    environment         = "prod"
    organizational_unit = "Production"
    sso_email           = "control-tower-admin@company.com"
  }

  # The plan-phase role of the workspace running this module. It must be allowed to
  # sts:AssumeRole on arn:aws:iam::*:role/AVMPlanReadOnlyRole (see UPGRADING.md, step 1).
  account_provider_roles = {
    plan = {
      create            = true
      assume            = true
      trusted_role_arns = ["arn:aws:iam::111111111111:role/LandingZonePlanRole"]
    }
  }

  tfe_workspace = {
    default_region        = "eu-west-1"
    repository_identifier = "myorg/myworkspacerepo"
    vcs_oauth_token_id    = "oauth-token-id"
  }
}
