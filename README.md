# terraform-aws-mcaf-avm

Terraform module providing an AWS Account Vending Machine (AVM). This module provisions an AWS account using the "AWS Control Tower Account Factory" product in Service Catalog with one or more HCP Terraform/Enterprise (TFE) workspaces backed by a VCS project.

## Authentication

This module authenticates Terraform runs to the provisioned AWS account using IAM roles with [OpenID Connect (OIDC)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials). This works for remote runners and self-hosted HCP Terraform agents (agent version v1.7.0+), and follows authentication best practices by avoiding long-lived IAM user credentials.

The OIDC integration creates an IAM role with a trust policy allowing the OIDC provider that is created as part of this module. HCP Terraform is configured to use OIDC by feeding the AWS provider the required environment variables.

All authentication is configured through a single variable, `authentication_settings`, and can be overridden per additional workspace through `override_authentication_settings`.

> [!WARNING]
> When using self-hosted HCP Terraform agents, ensure that your agents use v1.12.0+ when using [multiple configurations](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/specifying-multiple-configurations) (e.g. provider aliases).

### Run phases and roles

Roles are created per run phase using `authentication_settings.roles`. Each entry accepts a `policy` (an inline policy document) and/or `policy_arns` (managed policies to attach), and a role is only created for the phases you set:

| Phase | Default policy | Assumed during |
| --- | --- | --- |
| `run` | `AdministratorAccess` | Any phase that has no role of its own — the fallback. |
| `plan` | `ReadOnlyAccess` | The plan phase only. |
| `apply` | `AdministratorAccess` | The apply phase only. |

HCP Terraform picks the role per phase from the workspace variables this module sets: it uses `TFC_AWS_PLAN_ROLE_ARN` / `TFC_AWS_APPLY_ROLE_ARN` when present, and falls back to `TFC_AWS_RUN_ROLE_ARN` otherwise. Keeping `run` set alongside `plan` and `apply` therefore guarantees every phase resolves to a role.

`plan` and `apply` must be set together, and at least one of the three must be set.

Setting `authentication_settings.set_terraform_role_arn_variables` (default `true`) also exposes each ARN as a Terraform-category variable — `tfc_aws_run_role_arn` etc — which allows you to use this data in your code to e.g. make decisions based on which phase is running or pass this down into modules to ensure access is granted to a role (e.g. KMS).

### Role names

Role names are derived from `TFEPipeline` followed by a PascalCase version of the workspace name, with `Plan` and `Apply` appended for the phase-specific roles and `Role` appended by the underlying role module. Project-scoped roles use `TFEPipeline` on its own, since they are not tied to a single workspace:

| Scope | Workspace / project | Resulting role names |
| --- | --- | --- |
| Workspace | workspace `my-aws-account` | `TFEPipelineMyAwsAccountRole`, `TFEPipelineMyAwsAccountPlanRole`, `TFEPipelineMyAwsAccountApplyRole` |
| Project | any project | `TFEPipelineRole`, `TFEPipelinePlanRole`, `TFEPipelineApplyRole` |

Override the base name with `authentication_settings.role_name`, or for a single workspace with `override_authentication_settings.role_name`. The value replaces the generated name in full, so setting it module-wide gives every workspace the same role name — when you have additional workspaces, override it per workspace as well. Every IAM role name must be unique within the account.

`authentication_settings.role_name` names the project-scoped roles as well, so leave it unset in [scenario 3](#scenario-3-project-scoped-roles-alongside-per-workspace-roles), where the project roles and the per-workspace roles exist side by side and rely on the derived names to stay distinct.

### Scenarios

`authentication_settings.scope` determines where the roles are created. The three supported scenarios are:

| Scenario | Configuration | Roles created |
| --- | --- | --- |
| [1. Workspace-scoped](#scenario-1-workspace-scoped-authentication-default) | `scope = "workspace"` (default) | One set per workspace. |
| [2. Project-scoped](#scenario-2-project-scoped-authentication) | `scope = "project"` | One set for the whole project. |
| [3. Both](#scenario-3-project-scoped-roles-alongside-per-workspace-roles) | `scope = "workspace"` + `tfe_project.enable_project_scoped_authentication = true` | One set per workspace *and* one set for the project. |

#### Scenario 1: workspace-scoped authentication (default)

Every workspace this module creates — the default workspace and each additional workspace — gets its own `run`, `plan` and `apply` role, and the `TFC_AWS_*` variables are set on the workspace itself. Workspaces are isolated from each other: widening one workspace's permissions does not affect any other.

This is the default and needs no configuration.

##### Variation 1: a single role per workspace

Set only `run` to get one role per workspace that is assumed during every phase. This is useful when phase-specific least privilege is not wanted.

```hcl
authentication_settings = {
  roles = {
    run = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
  }
}
```

Because `roles` is replaced rather than merged, leaving `plan` and `apply` out means those roles are not created and HCP Terraform falls back to the run role for both phases.

##### Variation 2: different settings for a single workspace

Use `override_authentication_settings` on an additional workspace to deviate from the module-wide settings. Every field falls back to `authentication_settings` when it is not set, so you only specify what differs:

```hcl
authentication_settings = {
  roles = {
    run   = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
    apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
  }
}

additional_tfe_workspaces = {
  # Inherits the module-wide roles, but under a different role name.
  networking = {
    override_authentication_settings = {
      role_name = "TFEPipelineNetworking"
    }
  }

  # Keeps the module-wide role names, but may never change anything.
  audit = {
    override_authentication_settings = {
      roles = {
        run   = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
        plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
        apply = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
      }
    }
  }
}
```

Note that `roles` is replaced as a whole here too: an override that sets only `plan` and `apply` drops the module-wide `run` role for that workspace.

A workspace can also opt out of the permissions boundary with `override_authentication_settings.add_permissions_boundary = false` — see [IAM Permissions Boundaries](#iam-permissions-boundaries).

#### Scenario 2: project-scoped authentication

With `scope = "project"`, one set of `run`, `plan` and `apply` roles is created for the TFE project and shared by every workspace in it. The trust policy is scoped to the project rather than to a single workspace, and the `TFC_AWS_*` variables are set on the project variable set, so every workspace in the project inherits them automatically:

```hcl
authentication_settings = {
  scope = "project"

  roles = {
    run   = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
    apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
  }
}
```

This keeps the number of IAM roles constant as the account grows, at the cost of isolation: every workspace in the project has the same permissions. Project-scoped roles need a TFE project, so `tfe_project.enabled` defaults to `true` in this scenario and setting it to `false` is rejected. Without project-scoped authentication it still defaults to `false`.

##### Variation: give a single workspace its own roles

Set `override_authentication_settings.scope = "workspace"` on an additional workspace to exempt it from the project-scoped roles and give it its own set instead:

```hcl
authentication_settings = {
  scope = "project"
}

additional_tfe_workspaces = {
  # Uses the project-scoped roles.
  baseline = {}

  # Gets its own roles, with permissions that no other workspace in the project has.
  isolated = {
    override_authentication_settings = {
      scope = "workspace"

      roles = {
        run = { policy = data.aws_iam_policy_document.isolated.json }
      }
    }
  }
}
```

The workspace-level `TFC_AWS_*` variables take precedence over those from the project variable set, so the workspace uses its own roles even though the project ones remain attached. `override_authentication_settings.scope` accepts only `null` (follow `authentication_settings.scope`) or `"workspace"`; a workspace cannot opt *into* the project scope while the module-wide scope is `"workspace"` — that is what scenario 3 is for.

#### Scenario 3: project-scoped roles alongside per-workspace roles

The scope is either/or, but `tfe_project.enable_project_scoped_authentication` is an escape hatch: it creates the project-scoped roles *in addition to* the per-workspace roles. Use it when the workspaces managed by this module should keep their own roles, but workspaces created outside of it — or ephemeral ones — still need something to authenticate with:

```hcl
authentication_settings = {
  scope = "workspace"
}

tfe_project = {
  enable_project_scoped_authentication = true
}
```

Any workspace placed in the project inherits `TFC_AWS_PROVIDER_AUTH`, `TFC_AWS_WORKLOAD_IDENTITY_AUDIENCE` and the project role ARNs from the project variable set, so an out-of-band workspace authenticates without this module knowing about it. The workspaces this module manages keep their own roles, because their workspace-level variables take precedence.

`enable_project_scoped_authentication` defaults to `true` when the scope is `"project"` (and cannot be set to `false` in that case), so you only ever set it explicitly for this combination.

> [!NOTE]
> The project-scoped roles are as permissive as `authentication_settings.roles` says, and any workspace in the project can assume them. Scope their policies to what an unmanaged workspace legitimately needs rather than leaving them at the `AdministratorAccess` default.

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

The module supports setting a Permission Boundary on the pipeline IAM roles by passing down `authentication_settings.permissions_boundaries.workspace_boundary`, which needs to be referencing the path where the permissions boundary is stored in git and the name: `authentication_settings.permissions_boundaries.workspace_boundary_name`. Whenever `permissions_boundaries` is set, the workspace boundary is attached to every pipeline role created by this module: the project roles and the roles of every workspace. An additional workspace can opt out by setting `override_authentication_settings.add_permissions_boundary = false`.

In case you want to reference a permission boundary that needs to be attached to every IAM role that will be created by the workspace role then you can create this permission boundary by specifying `authentication_settings.permissions_boundaries.workload_boundary` which needs to be referencing the path where the permissions boundary is stored in git and the name: `authentication_settings.permissions_boundaries.workload_boundary_name`. Its ARN is exposed to the workspaces as the `workload_permissions_boundary_arn` Terraform variable.

Both boundaries are configured together: `workspace_boundary` and `workload_boundary` are mandatory fields once `permissions_boundaries` is set. Their names default to `pipeline_boundary` and `workload_boundary`.

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
| <a name="module_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#module\_additional\_tfe\_workspaces) | schubergphilis-ep/mcaf-workspace/aws | ~> 6.0.0 |
| <a name="module_tfe_project_auth"></a> [tfe\_project\_auth](#module\_tfe\_project\_auth) | schubergphilis-ep/mcaf-workspace/aws//modules/auth | ~> 6.0.0 |
| <a name="module_tfe_project_variable_set"></a> [tfe\_project\_variable\_set](#module\_tfe\_project\_variable\_set) | schubergphilis-ep/mcaf-variable-set/tfe | ~> 0.2.0 |
| <a name="module_tfe_workspace"></a> [tfe\_workspace](#module\_tfe\_workspace) | schubergphilis-ep/mcaf-workspace/aws | ~> 6.0.0 |

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
| <a name="input_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#input\_additional\_tfe\_workspaces) | Additional TFE workspaces. Set `override_authentication_settings.scope` to "workspace" to give a workspace its own IAM roles while authentication\_settings.scope is "project"; leave it null to follow authentication\_settings.scope. | <pre>map(object({<br/>    agent_pool_id                                = optional(string)<br/>    allow_destroy_plan                           = optional(bool)<br/>    assessments_enabled                          = optional(bool)<br/>    auto_apply                                   = optional(bool, false)<br/>    auto_apply_run_trigger                       = optional(bool, false)<br/>    auto_destroy_activity_duration               = optional(string)<br/>    auto_destroy_at                              = optional(string)<br/>    branch                                       = optional(string)<br/>    clear_text_env_variables                     = optional(map(string), {})<br/>    clear_text_hcl_variables                     = optional(map(string), {})<br/>    clear_text_terraform_variables               = optional(map(string), {})<br/>    connect_vcs_repo                             = optional(bool, true)<br/>    default_region                               = optional(string)<br/>    description                                  = optional(string)<br/>    execution_mode                               = optional(string)<br/>    file_triggers_enabled                        = optional(bool, true)<br/>    force_delete                                 = optional(bool, false)<br/>    global_remote_state                          = optional(bool, false)<br/>    name                                         = optional(string)<br/>    project_id                                   = optional(string)<br/>    queue_all_runs                               = optional(bool)<br/>    remote_state_consumer_ids                    = optional(set(string))<br/>    repository_identifier                        = optional(string)<br/>    sensitive_env_variables                      = optional(map(string), {})<br/>    sensitive_hcl_variables                      = optional(map(object({ sensitive = string })), {})<br/>    sensitive_terraform_variables                = optional(map(string), {})<br/>    set_working_directory                        = optional(bool)<br/>    speculative_enabled                          = optional(bool, true)<br/>    ssh_key_id                                   = optional(string)<br/>    terraform_version                            = optional(string)<br/>    trigger_patterns                             = optional(list(string))<br/>    trigger_patterns_working_directory_recursive = optional(bool)<br/>    variable_set_ids                             = optional(map(string), {})<br/>    vcs_github_app_installation_id               = optional(string)<br/>    vcs_oauth_token_id                           = optional(string)<br/>    working_directory                            = optional(string)<br/>    workspace_tags                               = optional(map(string))<br/><br/>    override_authentication_settings = optional(object({<br/>      add_permissions_boundary         = optional(bool) # defaults to true when authentication_settings.permissions_boundaries is set, set to false to opt this workspace out<br/>      role_name                        = optional(string)<br/>      scope                            = optional(string) # only accepts "workspace", inherits authentication_settings.scope when null<br/>      set_terraform_role_arn_variables = optional(bool)<br/><br/>      roles = optional(object({<br/>        run = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>        plan = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>        apply = optional(object({<br/>          policy      = optional(string)<br/>          policy_arns = optional(set(string), [])<br/>        }))<br/>      }), {})<br/>    }), {})<br/><br/>    notification_configuration = optional(map(object({<br/>      destination_type = string<br/>      enabled          = optional(bool, true)<br/>      url              = string<br/>      triggers = optional(list(string), [<br/>        "run:created",<br/>        "run:planning",<br/>        "run:needs_attention",<br/>        "run:applying",<br/>        "run:completed",<br/>        "run:errored",<br/>      ])<br/>    })), null)<br/><br/>    team_access = optional(map(object({<br/>      access = optional(string, null),<br/>      permissions = optional(object({<br/>        run_tasks         = bool<br/>        runs              = string<br/>        sentinel_mocks    = string<br/>        state_versions    = string<br/>        variables         = string<br/>        workspace_locking = bool<br/>      }), null)<br/>    })), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_authentication_settings"></a> [authentication\_settings](#input\_authentication\_settings) | TFE AWS authentication settings. `scope` determines where the pipeline IAM roles are created: "project" creates a single set of roles shared by every workspace in the project, "workspace" creates a set of roles per workspace. | <pre>object({<br/>    role_name                        = optional(string)              # automatically set by the module if not provided<br/>    scope                            = optional(string, "workspace") # either "project" or "workspace"<br/>    set_terraform_role_arn_variables = optional(bool, true)<br/><br/>    permissions_boundaries = optional(object({<br/>      workspace_boundary      = string<br/>      workspace_boundary_name = optional(string, "pipeline_boundary")<br/>      workload_boundary       = string<br/>      workload_boundary_name  = optional(string, "workload_boundary")<br/>    }))<br/><br/>    roles = optional(object({<br/>      run = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      plan = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      apply = optional(object({<br/>        policy      = optional(string)<br/>        policy_arns = optional(set(string), [])<br/>      }))<br/>      }), {<br/>      run   = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }<br/>      plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }<br/>      apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }<br/>    })<br/>  })</pre> | `{}` | no |
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
| <a name="output_additional_tfe_workspaces"></a> [additional\_tfe\_workspaces](#output\_additional\_tfe\_workspaces) | Map of any additional HCP Terraform workspace names and IDs |
| <a name="output_environment"></a> [environment](#output\_environment) | The environment name |
| <a name="output_id"></a> [id](#output\_id) | The AWS account ID |
| <a name="output_name"></a> [name](#output\_name) | The AWS account name |
| <a name="output_repository_identifier"></a> [repository\_identifier](#output\_repository\_identifier) | The repository identifier if one is specified |
| <a name="output_tfe_project_id"></a> [tfe\_project\_id](#output\_tfe\_project\_id) | Project ID of default project when `tfe_project.enabled` is true |
| <a name="output_tfe_workspace_id"></a> [tfe\_workspace\_id](#output\_tfe\_workspace\_id) | Workspace ID of default workspace ID when `create_default_workspace` is true |
| <a name="output_tfe_workspaces"></a> [tfe\_workspaces](#output\_tfe\_workspaces) | List of HCP Terraform workspaces |
| <a name="output_workload_permissions_boundary_arn"></a> [workload\_permissions\_boundary\_arn](#output\_workload\_permissions\_boundary\_arn) | The ARN of the workload permissions boundary |
| <a name="output_workload_permissions_boundary_name"></a> [workload\_permissions\_boundary\_name](#output\_workload\_permissions\_boundary\_name) | The name of the workload permissions boundary |
| <a name="output_workspace_permissions_boundary_arn"></a> [workspace\_permissions\_boundary\_arn](#output\_workspace\_permissions\_boundary\_arn) | The ARN of the workspace permissions boundary |
| <a name="output_workspace_permissions_boundary_name"></a> [workspace\_permissions\_boundary\_name](#output\_workspace\_permissions\_boundary\_name) | The name of the workspace permissions boundary |
<!-- END_TF_DOCS -->
