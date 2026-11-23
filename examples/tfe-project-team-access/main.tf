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

# A team created in the same run can't be looked up by name during the plan, so pass its id.
resource "tfe_team" "auditors" {
  name = "my-aws-account-auditors"
}

# Team access is only granted on the TFE project created by this module.
module "aws_account" {
  source = "../.."
  name   = "my-aws-account"

  account = {
    email               = "my-aws-account@email.com"
    environment         = "prod"
    organizational_unit = "Production"
    sso_email           = "control-tower-admin@company.com"
  }

  tfe_project = {
    enabled = true

    team_access = {
      "platform-engineers" = {
        access = "maintain"
      }

      "my-aws-account-auditors" = {
        access  = "read"
        team_id = tfe_team.auditors.id
      }

      "application-developers" = {
        access = "custom"

        project_access = {
          settings = "read"
          teams    = "none"
        }

        workspace_access = {
          locking        = true
          runs           = "apply"
          state_versions = "read-outputs"
          variables      = "read"
        }
      }
    }
  }

  tfe_workspace = {
    default_region        = "eu-west-1"
    repository_identifier = "myorg/myworkspacerepo"
    vcs_oauth_token_id    = "oauth-token-id"
  }
}
