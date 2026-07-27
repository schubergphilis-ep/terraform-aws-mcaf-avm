locals {

  # --- TFE Variables & Variable Sets ---

  account_variable_set_name = var.account_variable_set.name != null ? var.account_variable_set.name : "account-${var.name}"

  # Common variables to be added to either project or account variable set
  common_terraform_variables = merge(
    // always add account = var.name
    { account = var.name },
    // if environment, add environment = var.account.environment
    var.account.environment != null ? { environment = var.account.environment } : {},
    // if workload_boundary_arn, add workload_permissions_boundary_arn = aws_iam_policy.workload_boundary[0].arn
    var.permissions_boundaries != null ? { workload_permissions_boundary_arn = aws_iam_policy.workload_boundary[0].arn } : {}
  )

  common_env_variables = {
    // Set the `DEFAULT_REGION` variable using the variable set. This way it is also applied to additional
    // workspaces unless that workspace sets the `region` field.
    AWS_DEFAULT_REGION = var.tfe_workspace.default_region
  }

  # --- TFE Settings ---

  tfe_project_name = coalesce(var.tfe_project.name, var.name)

  tfe_workspace = {
    working_directory = var.account.environment != null ? "terraform/${var.account.environment}" : "terraform"
  }
}

################################################################################
# AWS Account & Settings
################################################################################

provider "aws" {
  alias  = "account"
  region = var.tfe_workspace.default_region

  default_tags {
    tags = var.tags
  }

  assume_role {
    role_arn = "arn:aws:iam::${module.account.id}:role/AWSControlTowerExecution"
  }
}

module "account" {
  source  = "schubergphilis-ep/mcaf-account/aws"
  version = "~> 1.0.0"

  account                  = var.name
  email                    = var.account.email
  organizational_unit      = var.account.organizational_unit
  provisioned_product_name = var.account.provisioned_product_name
  sso_email                = var.account.sso_email
  sso_firstname            = var.account.sso_firstname
  sso_lastname             = var.account.sso_lastname
}

resource "aws_iam_account_alias" "alias" {
  provider = aws.account

  account_alias = var.account.alias_prefix != null ? "${var.account.alias_prefix}${var.name}" : var.name
}

resource "aws_account_alternate_contact" "billing" {
  count = var.account.contact_billing == null ? 0 : 1

  provider = aws.account

  alternate_contact_type = "BILLING"
  email_address          = var.account.contact_billing.email_address
  name                   = var.account.contact_billing.name
  phone_number           = var.account.contact_billing.phone_number
  title                  = var.account.contact_billing.title
}

resource "aws_account_alternate_contact" "operations" {
  count = var.account.contact_operations == null ? 0 : 1

  provider = aws.account

  alternate_contact_type = "OPERATIONS"
  email_address          = var.account.contact_operations.email_address
  name                   = var.account.contact_operations.name
  phone_number           = var.account.contact_operations.phone_number
  title                  = var.account.contact_operations.title
}

resource "aws_account_alternate_contact" "security" {
  count = var.account.contact_security == null ? 0 : 1

  provider = aws.account

  alternate_contact_type = "SECURITY"
  email_address          = var.account.contact_security.email_address
  name                   = var.account.contact_security.name
  phone_number           = var.account.contact_security.phone_number
  title                  = var.account.contact_security.title
}

data "tls_certificate" "oidc_certificate" {
  url = "https://app.terraform.io"
}

resource "aws_iam_openid_connect_provider" "tfc_provider" {
  provider = aws.account

  url             = data.tls_certificate.oidc_certificate.url
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.oidc_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_policy" "workspace_boundary" {
  count = var.permissions_boundaries != null ? 1 : 0

  provider = aws.account

  name   = var.permissions_boundaries.workspace_boundary_name
  path   = var.path
  policy = templatefile(var.permissions_boundaries.workspace_boundary, { account_id = module.account.id })
}

resource "aws_iam_policy" "workload_boundary" {
  count = var.permissions_boundaries != null ? 1 : 0

  provider = aws.account

  name   = var.permissions_boundaries.workload_boundary_name
  path   = var.path
  policy = templatefile(var.permissions_boundaries.workload_boundary, { account_id = module.account.id })
}

################################################################################
# Terraform Cloud Account Variable Set
################################################################################

resource "tfe_variable_set" "account" {
  name         = local.account_variable_set_name
  description  = "Variable set for the account and all its linked workspaces"
  organization = var.tfe_workspace.organization
}

resource "tfe_variable" "account_variable_set_clear_text_env_variables" {
  for_each = var.tfe_project.enabled ? var.account_variable_set.clear_text_env_variables : merge(var.account_variable_set.clear_text_env_variables, local.common_env_variables)

  key             = each.key
  value           = each.value
  category        = "env"
  variable_set_id = tfe_variable_set.account.id
}

resource "tfe_variable" "account_variable_set_clear_text_hcl_variables" {
  for_each = var.account_variable_set.clear_text_hcl_variables

  key             = each.key
  value           = each.value
  category        = "terraform"
  hcl             = true
  variable_set_id = tfe_variable_set.account.id
}

resource "tfe_variable" "account_variable_set_clear_text_terraform_variables" {
  for_each = var.tfe_project.enabled ? var.account_variable_set.clear_text_terraform_variables : merge(var.account_variable_set.clear_text_terraform_variables, local.common_terraform_variables)

  key             = each.key
  value           = each.value
  category        = "terraform"
  variable_set_id = tfe_variable_set.account.id
}

################################################################################
# Terraform Cloud Project & Project Variable Set
################################################################################

resource "tfe_project" "default" {
  count = var.tfe_project.enabled ? 1 : 0

  name         = local.tfe_project_name
  organization = var.tfe_workspace.organization
}

resource "tfe_project_settings" "default" {
  count = var.tfe_project.enabled && (var.tfe_project.default_execution_mode != null || var.tfe_project.default_agent_pool_id != null) ? 1 : 0

  project_id             = tfe_project.default[0].id
  default_execution_mode = var.tfe_project.default_execution_mode
  default_agent_pool_id  = var.tfe_project.default_agent_pool_id
}

module "tfe_project_variable_set" {
  count = var.tfe_project.enabled && (var.tfe_project.variable_set != null || try(var.tfe_project.auth.enabled, false)) ? 1 : 0

  source  = "schubergphilis-ep/mcaf-variable-set/tfe"
  version = "~> 0.2.0"

  name              = "project-${local.tfe_project_name}"
  description       = "Variable set for the ${local.tfe_project_name} project"
  organization      = var.tfe_workspace.organization
  parent_project_id = tfe_project.default[0].id

  variables = merge(
    # Environment variables (including common env variables)
    {
      for k, v in merge(var.tfe_project.variable_set.clear_text_env_variables, local.common_env_variables) : k => {
        category    = "env"
        value       = v
        hcl         = false
        sensitive   = false
        description = null
      }
    },
    # HCL Terraform variables
    {
      for k, v in var.tfe_project.variable_set.clear_text_hcl_variables : k => {
        category    = "terraform"
        value       = v
        hcl         = true
        sensitive   = false
        description = null
      }
    },
    # Regular Terraform variables (including common terraform variables)
    {
      for k, v in merge(var.tfe_project.variable_set.clear_text_terraform_variables, local.common_terraform_variables) : k => {
        category    = "terraform"
        value       = v
        hcl         = false
        sensitive   = false
        description = null
      }
    }
  )
}

resource "tfe_project_variable_set" "default" {
  for_each = (var.tfe_project.enabled && (length(var.tfe_project.variable_set_ids) > 0)) ? var.tfe_project.variable_set_ids : {}

  project_id      = tfe_project.default[0].id
  variable_set_id = each.value
}

module "tfe_project_auth" {
  count = var.tfe_project.enabled && try(var.tfe_project.auth.enabled, false) ? 1 : 0

  providers = { aws = aws.account }

  source = "github.com/schubergphilis-ep/terraform-aws-mcaf-workspace//modules/auth?ref=add-plan-apply-roles"

  set_terraform_role_arn_variables = var.tfe_project.auth.set_terraform_role_arn_variables
  terraform_organization           = var.tfe_workspace.organization
  variable_set_id                  = module.tfe_project_variable_set[0].id

  oidc_settings = {
    provider_arn  = aws_iam_openid_connect_provider.tfc_provider.arn
    project_scope = true
    project_name  = tfe_project.default[0].name
  }

  role_settings = {
    name                     = var.tfe_project.auth.role_name
    path                     = var.path
    permissions_boundary_arn = coalesce(var.tfe_project.auth.role_add_permissions_boundary, var.permissions_boundaries != null) ? aws_iam_policy.workspace_boundary[0].arn : null

    apply = var.tfe_project.auth.roles.apply
    plan  = var.tfe_project.auth.roles.plan
    run   = var.tfe_project.auth.roles.run
  }
}

################################################################################
# Terraform Cloud Workspace(s)
################################################################################

module "tfe_workspace" {
  count = var.create_default_workspace ? 1 : 0

  providers = { aws = aws.account }

  source = "github.com/schubergphilis-ep/terraform-aws-mcaf-workspace?ref=add-plan-apply-roles"

  agent_pool_id                                = var.tfe_workspace.agent_pool_id
  allow_destroy_plan                           = var.tfe_workspace.allow_destroy_plan
  assessments_enabled                          = var.tfe_workspace.assessments_enabled
  auto_apply                                   = var.tfe_workspace.auto_apply
  auto_apply_run_trigger                       = var.tfe_workspace.auto_apply_run_trigger
  auto_destroy_activity_duration               = var.tfe_workspace.auto_destroy_activity_duration
  auto_destroy_at                              = var.tfe_workspace.auto_destroy_at
  branch                                       = var.tfe_workspace.connect_vcs_repo != false ? var.tfe_workspace.branch : null
  clear_text_env_variables                     = var.tfe_workspace.clear_text_env_variables
  clear_text_hcl_variables                     = var.tfe_workspace.clear_text_hcl_variables
  clear_text_terraform_variables               = var.tfe_workspace.clear_text_terraform_variables
  description                                  = var.tfe_workspace.description
  execution_mode                               = var.tfe_workspace.execution_mode
  file_triggers_enabled                        = var.tfe_workspace.connect_vcs_repo != false ? var.tfe_workspace.file_triggers_enabled : false
  force_delete                                 = var.tfe_workspace.force_delete
  github_app_installation_id                   = var.tfe_workspace.connect_vcs_repo != false ? var.tfe_workspace.vcs_github_app_installation_id : null
  global_remote_state                          = var.tfe_workspace.global_remote_state
  name                                         = coalesce(var.tfe_workspace.name, var.name)
  notification_configuration                   = var.tfe_workspace.notification_configuration
  oauth_token_id                               = var.tfe_workspace.connect_vcs_repo != false ? var.tfe_workspace.vcs_oauth_token_id : null
  project_id                                   = var.tfe_project.enabled ? coalesce(var.tfe_workspace.project_id, try(tfe_project.default[0].id, null)) : var.tfe_workspace.project_id
  queue_all_runs                               = var.tfe_workspace.queue_all_runs
  remote_state_consumer_ids                    = var.tfe_workspace.remote_state_consumer_ids
  repository_identifier                        = var.tfe_workspace.connect_vcs_repo ? var.tfe_workspace.repository_identifier : null
  sensitive_env_variables                      = var.tfe_workspace.sensitive_env_variables
  sensitive_hcl_variables                      = var.tfe_workspace.sensitive_hcl_variables
  sensitive_terraform_variables                = var.tfe_workspace.sensitive_terraform_variables
  speculative_enabled                          = var.tfe_workspace.speculative_enabled
  ssh_key_id                                   = var.tfe_workspace.ssh_key_id
  team_access                                  = var.tfe_workspace.team_access
  terraform_organization                       = var.tfe_workspace.organization
  terraform_version                            = var.tfe_workspace.terraform_version
  trigger_patterns                             = var.tfe_workspace.connect_vcs_repo != false ? var.tfe_workspace.trigger_patterns : null
  trigger_patterns_working_directory_recursive = var.tfe_workspace.trigger_patterns_working_directory_recursive
  variable_set_ids                             = merge({ (local.account_variable_set_name) : tfe_variable_set.account.id }, var.tfe_workspace.variable_set_ids)
  working_directory                            = var.tfe_workspace.set_working_directory ? coalesce(var.tfe_workspace.working_directory, local.tfe_workspace.working_directory) : null
  workspace_tags                               = var.tfe_workspace.workspace_tags

  authentication = var.tfe_workspace.auth.enabled ? {
    oidc_settings = { provider_arn = aws_iam_openid_connect_provider.tfc_provider.arn }
    role_settings = {
      name                             = var.tfe_workspace.auth.role_name
      path                             = var.path
      permissions_boundary_arn         = coalesce(var.tfe_workspace.auth.role_add_permissions_boundary, var.permissions_boundaries != null) ? aws_iam_policy.workspace_boundary[0].arn : null
      set_terraform_role_arn_variables = var.tfe_workspace.auth.set_terraform_role_arn_variables

      apply = var.tfe_workspace.auth.roles.apply
      plan  = var.tfe_workspace.auth.roles.plan
      run   = var.tfe_workspace.auth.roles.run
    }
  } : null
}

module "additional_tfe_workspaces" {
  for_each = var.additional_tfe_workspaces

  providers = { aws = aws.account }

  source = "github.com/schubergphilis-ep/terraform-aws-mcaf-workspace?ref=add-plan-apply-roles"

  agent_pool_id                                = each.value.agent_pool_id != null ? each.value.agent_pool_id : var.tfe_workspace.agent_pool_id
  allow_destroy_plan                           = each.value.allow_destroy_plan != null ? each.value.allow_destroy_plan : var.tfe_workspace.allow_destroy_plan
  assessments_enabled                          = each.value.assessments_enabled != null ? each.value.assessments_enabled : var.tfe_workspace.assessments_enabled
  auto_apply                                   = each.value.auto_apply
  auto_apply_run_trigger                       = each.value.auto_apply_run_trigger
  auto_destroy_activity_duration               = each.value.auto_destroy_activity_duration
  auto_destroy_at                              = each.value.auto_destroy_at
  branch                                       = each.value.connect_vcs_repo != false ? coalesce(each.value.branch, var.tfe_workspace.branch) : null
  clear_text_env_variables                     = each.value.clear_text_env_variables
  clear_text_hcl_variables                     = each.value.clear_text_hcl_variables
  clear_text_terraform_variables               = each.value.clear_text_terraform_variables
  description                                  = each.value.description
  execution_mode                               = coalesce(each.value.execution_mode, var.tfe_workspace.execution_mode)
  file_triggers_enabled                        = each.value.connect_vcs_repo != false ? each.value.file_triggers_enabled : false
  force_delete                                 = each.value.force_delete
  github_app_installation_id                   = each.value.connect_vcs_repo != false ? try(coalesce(each.value.vcs_github_app_installation_id, var.tfe_workspace.vcs_github_app_installation_id), null) : null
  global_remote_state                          = each.value.global_remote_state
  name                                         = coalesce(each.value.name, each.key)
  notification_configuration                   = each.value.notification_configuration != null ? each.value.notification_configuration : var.tfe_workspace.notification_configuration
  oauth_token_id                               = each.value.connect_vcs_repo != false ? try(coalesce(each.value.vcs_oauth_token_id, var.tfe_workspace.vcs_oauth_token_id), null) : null
  project_id                                   = var.tfe_project.enabled ? coalesce(each.value.project_id, var.tfe_workspace.project_id, try(tfe_project.default[0].id, null)) : coalesce(each.value.project_id, var.tfe_workspace.project_id)
  queue_all_runs                               = each.value.queue_all_runs
  region                                       = each.value.default_region
  remote_state_consumer_ids                    = each.value.remote_state_consumer_ids
  repository_identifier                        = each.value.connect_vcs_repo != false ? coalesce(each.value.repository_identifier, var.tfe_workspace.repository_identifier) : null
  sensitive_env_variables                      = each.value.sensitive_env_variables
  sensitive_hcl_variables                      = each.value.sensitive_hcl_variables
  sensitive_terraform_variables                = each.value.sensitive_terraform_variables
  speculative_enabled                          = each.value.speculative_enabled
  ssh_key_id                                   = each.value.ssh_key_id != null ? each.value.ssh_key_id : var.tfe_workspace.ssh_key_id
  team_access                                  = each.value.team_access != null ? each.value.team_access : var.tfe_workspace.team_access
  terraform_organization                       = var.tfe_workspace.organization
  terraform_version                            = each.value.terraform_version != null ? (each.value.terraform_version == "" ? null : each.value.terraform_version) : var.tfe_workspace.terraform_version
  trigger_patterns                             = each.value.connect_vcs_repo != false ? coalesce(each.value.trigger_patterns, var.tfe_workspace.trigger_patterns) : null
  trigger_patterns_working_directory_recursive = each.value.trigger_patterns_working_directory_recursive
  variable_set_ids                             = merge({ (local.account_variable_set_name) : tfe_variable_set.account.id }, each.value.variable_set_ids)
  working_directory                            = coalesce(each.value.set_working_directory, var.tfe_workspace.set_working_directory) ? coalesce(each.value.working_directory, "terraform/${coalesce(each.value.name, each.key)}") : null
  workspace_tags                               = each.value.workspace_tags

  authentication = coalesce(each.value.auth.enabled, var.tfe_workspace.auth.enabled) ? {
    oidc_settings = { provider_arn = aws_iam_openid_connect_provider.tfc_provider.arn }
    role_settings = {
      name                             = each.value.auth.role_name
      path                             = var.path
      permissions_boundary_arn         = coalesce(each.value.auth.role_add_permissions_boundary, var.permissions_boundaries != null) ? aws_iam_policy.workspace_boundary[0].arn : null
      set_terraform_role_arn_variables = coalesce(each.value.auth.set_terraform_role_arn_variables, var.tfe_workspace.auth.set_terraform_role_arn_variables)

      apply = coalesce(each.value.auth.roles.apply, var.tfe_workspace.auth.roles.apply)
      plan  = coalesce(each.value.auth.roles.plan, var.tfe_workspace.auth.roles.plan)
      run   = coalesce(each.value.auth.roles.run, var.tfe_workspace.auth.roles.run)
    }
  } : null
}
