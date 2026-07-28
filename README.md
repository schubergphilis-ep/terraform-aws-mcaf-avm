# terraform-aws-mcaf-avm

Terraform module providing an AWS Account Vending Machine (AVM). This module provisions an AWS account using the "AWS Control Tower Account Factory" product in Service Catalog with one or more Terraform Cloud/Enterprise (TFE) workspaces backed by a VCS project.

## Authentication

This module authenticates Terraform runs to the provisioned AWS account using IAM roles with [OpenID Connect (OIDC)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials). This works for remote runners and self-hosted Terraform Cloud agents (agent version v1.7.0+), and follows authentication best practices by avoiding long-lived IAM user credentials.

The OIDC integration creates an IAM role with a trust policy allowing the OIDC provider that is created as part of this module. Workspaces are configured to use OIDC by feeding the AWS provider the required environment variables.

Roles are created per run phase using `authentication_settings.roles`: the `plan` and `apply` roles are scoped to their respective phase, and the `run` role acts as a fallback for both. By default `plan` gets `ReadOnlyAccess` while `run` and `apply` get `AdministratorAccess`.

Role names are derived from `TFEPipeline` followed by a PascalCase version of the workspace name (the project-scoped role uses `TFEPipeline` on its own), with `Plan` and `Apply` appended for the phase-specific roles. Override the base name via `authentication_settings.role_name_prefix`, or per additional workspace via `override_authentication_settings.role_name_prefix`; each IAM role must have a unique name.

> [!WARNING]
> When using self-hosted Terraform Cloud agents, ensure that your agents use v1.12.0+ when using [multiple configurations](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/specifying-multiple-configurations) (e.g. provider aliases).

### Authentication scope

`authentication_settings.scope` determines where the roles are created and is either `"project"` or `"workspace"`:

| Scope | Behaviour |
| --- | --- |
| `"workspace"` (default) | Every workspace gets its own set of roles. |
| `"project"` | A single set of roles is created for the TFE project and shared by every workspace in it. Useful for workspaces created outside of AVM and for ephemeral workspaces. |

```hcl
authentication_settings = {
  scope = "project"
}
```

Project-scoped authentication needs a TFE project, so it enables one automatically: `tfe_project.enabled` defaults to `true` whenever project-scoped roles are created, and setting it to `false` in that case is rejected. Otherwise `tfe_project.enabled` still defaults to `false`.

Individual additional workspaces can deviate from the scope, so a project-scoped setup can still give specific workspaces their own roles — see below.

#### Adding project-scoped roles to a workspace-scoped setup

The scope is either/or, but `tfe_project.enable_project_scoped_authentication` is an escape hatch: it creates the project-scoped roles *in addition to* the per-workspace roles. Use it when the workspaces managed by this module should keep their own roles, but workspaces created outside of it — or ephemeral ones — still need something to authenticate with:

```hcl
authentication_settings = {
  scope = "workspace"
}

tfe_project = {
  enable_project_scoped_authentication = true
}
```

It defaults to `true` when the scope is `"project"` (and cannot be set to `false` in that case), so you only ever set it explicitly for this combination.

### Overriding authentication per workspace

Additional workspaces can deviate from the module-wide settings through `override_authentication_settings`. Every field falls back to `authentication_settings` when it is not set:

```hcl
additional_tfe_workspaces = {
  # Follows authentication_settings.scope, but with a stricter apply policy.
  restricted = {
    override_authentication_settings = {
      roles = {
        apply = { policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"] }
        plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
      }
    }
  }

  # Gets its own roles even while authentication_settings.scope is "project".
  isolated = {
    override_authentication_settings = {
      scope = "workspace"
    }
  }
}
```

`override_authentication_settings.scope` accepts either `null` (the default, following `authentication_settings.scope`) or `"workspace"`. Setting it to `"workspace"` gives that workspace its own roles even when the module-wide scope is `"project"`; the workspace then has both sets available and its own variables take precedence over those of the project variable set.

## Workspace team access

Team access can be configured per workspace using the `team_access` variable.

As the state is considered sensitive, we recommend the following custom role permissions which is similar to the pre-existing "write" permission but blocks read access to the state (viewing outputs is still allowed):

```hcl
team_access = {
  "MyTeamName" = {
    permissions = {
      run_tasks         = false
      runs              = "apply"
      sentinel_mocks    = "read"
      state_versions    = "read-outputs"
      variables         = "write"
      workspace_locking = true
    }
  }
}
```

More complete usage information can be found in the underlying [terraform-aws-mcaf-workspace module README](https://github.com/schubergphilis/terraform-aws-mcaf-workspace#team-access).

> [!WARNING]
> The team should already exist, this module will not create it for you.

## AWS SSO Configuration

In the `account` variable, the SSO attributes (`sso_email`, `sso_firstname` and `sso_lastname`) will be used by AWS Service Catalog to provide initial access to the newly created account.

You should use the details from the AWS Control Tower Admin user.

## How to use

### Basic configuration

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "x.x.x"

  name = "my-aws-account"
  tags = { Terraform = true }

  account = {
    email               = "my-aws-account@email.com"
    environment         = "prod"
    organizational_unit = "Production"
    sso_email           = "control-tower-admin@company.com"
  }

  tfe_workspace = {
    default_region        = "eu-west-1"
    repository_identifier = "myorg/myworkspacerepo"
    organization          = "myorg"
    vcs_oauth_token_id    = var.oauth_token_id
  }
}
```

### Additional workspaces

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "x.x.x"

  name = "my-aws-account"
  tags = { Terraform = true }

  account = {
    email               = "my-aws-account@email.com"
    environment         = "prod"
    organizational_unit = "Production"
    sso_email           = "control-tower-admin@company.com"
  }

  tfe_workspace = {
    default_region        = "eu-west-1"
    repository_identifier = "schubergphilis/terraform-aws-mcaf-avm"
    organization          = "schubergphilis"
    vcs_oauth_token_id    = var.oauth_token_id
  }

  additional_tfe_workspaces = {
    baseline-my-aws-account = {
      auto_apply            = true
      repository_identifier = "schubergphilis/terraform-aws-mcaf-account-baseline"
    }
  }
}
```

### Only deploy additional workspaces

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "x.x.x"

  create_default_workspace = false
  name                     = "my-aws-account"
  tags                     = { Terraform = true }

  account = {
    email               = "my-aws-account@email.com"
    environment         = "prod"
    organizational_unit = "Production"
    sso_email           = "control-tower-admin@company.com"
  }

  tfe_workspace = {
    default_region        = "eu-west-1"
    repository_identifier = "schubergphilis/terraform-aws-mcaf-avm"
    organization          = "schubergphilis"
    vcs_oauth_token_id    = var.oauth_token_id
  }

  additional_tfe_workspaces = {
    my-aws-account-subsystem1 = {
      working_directory = "terraform/subsystem1"
    }
    my-aws-account-subsystem2 = {
      working_directory = "terraform/subsystem2"
    }
  }
}
```

## IAM Permissions Boundaries

The module supports setting a Permission Boundary on the pipeline IAM roles by passing down `authentication_settings.permissions_boundaries.workspace_boundary`, which needs to be referencing the path where the permissions boundary is stored in git and the name: `authentication_settings.permissions_boundaries.workspace_boundary_name`. Whenever `permissions_boundaries` is set, the workspace boundary is attached to every pipeline role created by this module: the project role and the role of every workspace. An additional workspace can opt out by setting `override_authentication_settings.role_add_permissions_boundary = false`.

In case you want to reference a permission boundary that needs to be attached to every IAM role that will be created by the workspace role then you can create this permission boundary by specifying `authentication_settings.permissions_boundaries.workload_boundary` which needs to be referencing the path where the permissions boundary is stored in git and the name: `authentication_settings.permissions_boundaries.workload_boundary_name`. Its ARN is exposed to the workspaces as the `workload_permissions_boundary_arn` Terraform variable.

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "x.x.x"

  ...
  authentication_settings = {
    permissions_boundaries = {
      workspace_boundary      = "${path.module}/workspace_boundary.json"
      workspace_boundary_name = "workspace_boundary"
      workload_boundary       = "${path.module}/workload_boundary.json"
      workload_boundary_name  = "workload_boundary"
    }
  }
  ...
}
```

> [!TIP]
> The `workspace_boundary` and `workload_boundary` can be templated files, `account_id` will be replaced by AVM by the account ID of the AWS account created.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.9.0 |
| <a name="requirement_mcaf"></a> [mcaf](#requirement\_mcaf) | >= 0.4.5 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >= 0.70.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws.account"></a> [aws.account](#provider\_aws.account) | 6.56.0 |
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | 0.79.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_account"></a> [account](#module\_account) | schubergphilis-ep/mcaf-account/aws | ~> 1.0.0 |
| <a name="module_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#module\_additional\_tfe\_workspaces) | github.com/schubergphilis-ep/terraform-aws-mcaf-workspace | add-plan-apply-roles |
| <a name="module_tfe_project_auth"></a> [tfe\_project\_auth](#module\_tfe\_project\_auth) | github.com/schubergphilis-ep/terraform-aws-mcaf-workspace//modules/auth | add-plan-apply-roles |
| <a name="module_tfe_project_variable_set"></a> [tfe\_project\_variable\_set](#module\_tfe\_project\_variable\_set) | schubergphilis-ep/mcaf-variable-set/tfe | ~> 0.2.0 |
| <a name="module_tfe_workspace"></a> [tfe\_workspace](#module\_tfe\_workspace) | github.com/schubergphilis-ep/terraform-aws-mcaf-workspace | add-plan-apply-roles |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_account_alternate_contact.billing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_account_alternate_contact.operations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_account_alternate_contact.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_iam_account_alias.alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_alias) | resource |
| [aws_iam_openid_connect_provider.tfc_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.workload_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.workspace_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [tfe_project.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project) | resource |
| [tfe_project_settings.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project_settings) | resource |
| [tfe_project_variable_set.default](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/project_variable_set) | resource |
| [tfe_variable.account_variable_set_clear_text_env_variables](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.account_variable_set_clear_text_hcl_variables](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable.account_variable_set_clear_text_terraform_variables](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable) | resource |
| [tfe_variable_set.account](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/variable_set) | resource |
| [tls_certificate.oidc_certificate](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account"></a> [account](#input\_account) | AWS account settings | <pre>object({<br/>    alias_prefix = optional(string)<br/>    contact_billing = optional(object({<br/>      email_address = string<br/>      name          = string<br/>      phone_number  = string<br/>      title         = string<br/>    }), null)<br/>    contact_operations = optional(object({<br/>      email_address = string<br/>      name          = string<br/>      phone_number  = string<br/>      title         = string<br/>    }), null)<br/>    contact_security = optional(object({<br/>      email_address = string<br/>      name          = string<br/>      phone_number  = string<br/>      title         = string<br/>    }), null)<br/>    email                    = string<br/>    environment              = optional(string)<br/>    organizational_unit      = string<br/>    provisioned_product_name = optional(string)<br/>    sso_email                = string<br/>    sso_firstname            = optional(string, "AWS Control Tower")<br/>    sso_lastname             = optional(string, "Admin")<br/>  })</pre> | n/a | yes |
| <a name="input_account_variable_set"></a> [account\_variable\_set](#input\_account\_variable\_set) | Settings of variable set that is attached to each workspace | <pre>object({<br/>    name                           = optional(string)<br/>    clear_text_env_variables       = optional(map(string), {})<br/>    clear_text_hcl_variables       = optional(map(string), {})<br/>    clear_text_terraform_variables = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#input\_additional\_tfe\_workspaces) | Additional TFE workspaces. Set `override_authentication_settings.scope` to "workspace" to give a workspace its own IAM roles while authentication\_settings.scope is "project"; leave it null to follow authentication\_settings.scope. | <pre>map(object({<br/>    agent_pool_id                                = optional(string)<br/>    allow_destroy_plan                           = optional(bool)<br/>    assessments_enabled                          = optional(bool)<br/>    auto_apply                                   = optional(bool, false)<br/>    auto_apply_run_trigger                       = optional(bool, false)<br/>    auto_destroy_activity_duration               = optional(string)<br/>    auto_destroy_at                              = optional(string)<br/>    branch                                       = optional(string)<br/>    clear_text_env_variables                     = optional(map(string), {})<br/>    clear_text_hcl_variables                     = optional(map(string), {})<br/>    clear_text_terraform_variables               = optional(map(string), {})<br/>    connect_vcs_repo                             = optional(bool, true)<br/>    default_region                               = optional(string)<br/>    description                                  = optional(string)<br/>    execution_mode                               = optional(string)<br/>    file_triggers_enabled                        = optional(bool, true)<br/>    force_delete                                 = optional(bool, false)<br/>    global_remote_state                          = optional(bool, false)<br/>    name                                         = optional(string)<br/>    project_id                                   = optional(string)<br/>    queue_all_runs                               = optional(bool)<br/>    remote_state_consumer_ids                    = optional(set(string))<br/>    repository_identifier                        = optional(string)<br/>    sensitive_env_variables                      = optional(map(string), {})<br/>    sensitive_hcl_variables                      = optional(map(object({ sensitive = string })), {})<br/>    sensitive_terraform_variables                = optional(map(string), {})<br/>    set_working_directory                        = optional(bool)<br/>    speculative_enabled                          = optional(bool, true)<br/>    ssh_key_id                                   = optional(string)<br/>    terraform_version                            = optional(string)<br/>    trigger_patterns                             = optional(list(string))<br/>    trigger_patterns_working_directory_recursive = optional(bool)<br/>    variable_set_ids                             = optional(map(string), {})<br/>    vcs_github_app_installation_id               = optional(string)<br/>    vcs_oauth_token_id                           = optional(string)<br/>    working_directory                            = optional(string)<br/>    workspace_tags                               = optional(map(string))<br/><br/>    override_authentication_settings = optional(object({<br/>      role_add_permissions_boundary    = optional(bool) # defaults to true when authentication_settings.permissions_boundaries is set, set to false to opt this workspace out<br/>      role_name_prefix                 = optional(string)<br/>      scope                            = optional(string) # only accepts "workspace", inherits authentication_settings.scope when null<br/>      set_terraform_role_arn_variables = optional(bool)<br/><br/>      roles = optional(object({<br/>        run = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>        plan = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>        apply = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>      }), {})<br/>    }), {})<br/><br/>    notification_configuration = optional(map(object({<br/>      destination_type = string<br/>      enabled          = optional(bool, true)<br/>      url              = string<br/>      triggers = optional(list(string), [<br/>        "run:created",<br/>        "run:planning",<br/>        "run:needs_attention",<br/>        "run:applying",<br/>        "run:completed",<br/>        "run:errored",<br/>      ])<br/>    })), null)<br/><br/>    team_access = optional(map(object({<br/>      access = optional(string, null),<br/>      permissions = optional(object({<br/>        run_tasks         = bool<br/>        runs              = string<br/>        sentinel_mocks    = string<br/>        state_versions    = string<br/>        variables         = string<br/>        workspace_locking = bool<br/>      }), null)<br/>    })), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_authentication_settings"></a> [authentication\_settings](#input\_authentication\_settings) | TFE AWS authentication settings. `scope` determines where the pipeline IAM roles are created: "project" creates a single set of roles shared by every workspace in the project, "workspace" creates a set of roles per workspace. | <pre>object({<br/>    role_name_prefix                 = optional(string)              # automatically set by the module if not provided<br/>    scope                            = optional(string, "workspace") # either "project" or "workspace"<br/>    set_terraform_role_arn_variables = optional(bool, true)<br/><br/>    permissions_boundaries = optional(object({<br/>      workspace_boundary      = string<br/>      workspace_boundary_name = optional(string, "pipeline_boundary")<br/>      workload_boundary       = string<br/>      workload_boundary_name  = optional(string, "workload_boundary")<br/>    }))<br/><br/>    roles = optional(object({<br/>      run = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      plan = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      apply = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      }), {<br/>      run   = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }<br/>      plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }<br/>      apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }<br/>    })<br/>  })</pre> | `{}` | no |
| <a name="input_create_default_workspace"></a> [create\_default\_workspace](#input\_create\_default\_workspace) | Set to false to skip creating default workspace | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the account and default TFE workspace | `string` | n/a | yes |
| <a name="input_path"></a> [path](#input\_path) | Optional path for all IAM users, user groups, roles, and customer managed policies created by this module | `string` | `"/"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to all resources | `map(string)` | `{}` | no |
| <a name="input_tfe_project"></a> [tfe\_project](#input\_tfe\_project) | TFE project configuration including variable sets and authentication settings. If no name is provided, var.name will be used for the project name & variable set name. `enable_project_scoped_authentication` defaults to true when authentication\_settings.scope is "project"; set it to true while the scope is "workspace" to create project-scoped roles in addition to the per-workspace roles, for example for workspaces created outside of this module. `enabled` defaults to true whenever project-scoped authentication is enabled, since it requires a project, and false otherwise. | <pre>object({<br/>    enabled = optional(bool) # defaults to true when project-scoped authentication is enabled<br/>    name    = optional(string)<br/><br/>    default_agent_pool_id                = optional(string)<br/>    default_execution_mode               = optional(string)<br/>    enable_project_scoped_authentication = optional(bool) # defaults to true when authentication_settings.scope is "project"<br/>    variable_set_ids                     = optional(map(string), {})<br/><br/>    variable_set = optional(object({<br/>      clear_text_env_variables       = optional(map(string), {})<br/>      clear_text_hcl_variables       = optional(map(string), {})<br/>      clear_text_terraform_variables = optional(map(string), {})<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_tfe_workspace"></a> [tfe\_workspace](#input\_tfe\_workspace) | TFE workspace settings | <pre>object({<br/>    agent_pool_id                                = optional(string)<br/>    allow_destroy_plan                           = optional(bool, true)<br/>    assessments_enabled                          = optional(bool, true)<br/>    auto_apply                                   = optional(bool, false)<br/>    auto_apply_run_trigger                       = optional(bool, false)<br/>    auto_destroy_activity_duration               = optional(string)<br/>    auto_destroy_at                              = optional(string)<br/>    branch                                       = optional(string, "main")<br/>    clear_text_env_variables                     = optional(map(string), {})<br/>    clear_text_hcl_variables                     = optional(map(string), {})<br/>    clear_text_terraform_variables               = optional(map(string), {})<br/>    connect_vcs_repo                             = optional(bool, true)<br/>    default_region                               = string<br/>    description                                  = optional(string)<br/>    execution_mode                               = optional(string, "remote")<br/>    file_triggers_enabled                        = optional(bool, true)<br/>    force_delete                                 = optional(bool, false)<br/>    global_remote_state                          = optional(bool, false)<br/>    name                                         = optional(string)<br/>    organization                                 = optional(string)<br/>    project_id                                   = optional(string)<br/>    queue_all_runs                               = optional(bool)<br/>    remote_state_consumer_ids                    = optional(set(string))<br/>    repository_identifier                        = optional(string)<br/>    sensitive_env_variables                      = optional(map(string), {})<br/>    sensitive_hcl_variables                      = optional(map(object({ sensitive = string })), {})<br/>    sensitive_terraform_variables                = optional(map(string), {})<br/>    set_working_directory                        = optional(bool, true)<br/>    speculative_enabled                          = optional(bool, true)<br/>    ssh_key_id                                   = optional(string)<br/>    terraform_version                            = optional(string)<br/>    trigger_patterns                             = optional(list(string), ["modules/**/*"])<br/>    trigger_patterns_working_directory_recursive = optional(bool)<br/>    variable_set_ids                             = optional(map(string), {})<br/>    vcs_github_app_installation_id               = optional(string)<br/>    vcs_oauth_token_id                           = optional(string)<br/>    working_directory                            = optional(string)<br/>    workspace_tags                               = optional(map(string))<br/><br/>    notification_configuration = optional(map(object({<br/>      destination_type = string<br/>      enabled          = optional(bool, true)<br/>      url              = string<br/>      triggers = optional(list(string), [<br/>        "run:created",<br/>        "run:planning",<br/>        "run:needs_attention",<br/>        "run:applying",<br/>        "run:completed",<br/>        "run:errored",<br/>      ])<br/>    })), {})<br/><br/>    team_access = optional(map(object({<br/>      access = optional(string, null),<br/>      permissions = optional(object({<br/>        run_tasks         = bool<br/>        runs              = string<br/>        sentinel_mocks    = string<br/>        state_versions    = string<br/>        variables         = string<br/>        workspace_locking = bool<br/>      }), null)<br/>    })), {})<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_variable_set_id"></a> [account\_variable\_set\_id](#output\_account\_variable\_set\_id) | The ID of the account variable set |
| <a name="output_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#output\_additional\_tfe\_workspaces) | Map of any additional Terraform Cloud workspace names and IDs |
| <a name="output_environment"></a> [environment](#output\_environment) | The environment name |
| <a name="output_id"></a> [id](#output\_id) | The AWS account ID |
| <a name="output_name"></a> [name](#output\_name) | The AWS account name |
| <a name="output_repository_identifier"></a> [repository\_identifier](#output\_repository\_identifier) | The repository identifier if one is specified |
| <a name="output_tfe_project_id"></a> [tfe\_project\_id](#output\_tfe\_project\_id) | Project ID of default project when `tfe_project.enabled` is true |
| <a name="output_tfe_workspace_id"></a> [tfe\_workspace\_id](#output\_tfe\_workspace\_id) | Workspace ID of default workspace ID when `create_default_workspace` is true |
| <a name="output_tfe_workspaces"></a> [tfe\_workspaces](#output\_tfe\_workspaces) | List of Terraform Cloud workspaces |
| <a name="output_workload_permissions_boundary_arn"></a> [workload\_permissions\_boundary\_arn](#output\_workload\_permissions\_boundary\_arn) | The ARN of the workload permissions boundary |
| <a name="output_workload_permissions_boundary_name"></a> [workload\_permissions\_boundary\_name](#output\_workload\_permissions\_boundary\_name) | The name of the workload permissions boundary |
| <a name="output_workspace_permissions_boundary_arn"></a> [workspace\_permissions\_boundary\_arn](#output\_workspace\_permissions\_boundary\_arn) | The ARN of the workspace permissions boundary |
| <a name="output_workspace_permissions_boundary_name"></a> [workspace\_permissions\_boundary\_name](#output\_workspace\_permissions\_boundary\_name) | The name of the workspace permissions boundary |
<!-- END_TF_DOCS -->
