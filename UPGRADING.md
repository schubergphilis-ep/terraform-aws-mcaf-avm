# UPGRADING

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v11.0.0

### Key Changes v11.0.0

The `schubergphilis-ep/mcaf-workspace/aws` child modules (the workspace module and its `modules/auth` submodule) are upgraded from `v5` to `v6`, which introduces **phase-specific IAM roles**: instead of one role per workspace, the plan and apply run phases can each get their own least-privilege role, with the `run` role acting as the fallback for any phase that has none.

To expose this, every authentication-related input of this module is consolidated into one new `var.authentication_settings` object:

- Role permissions are no longer a single `policy`/`policy_arns` pair but a `roles` object with a `run`, `plan` and `apply` entry.
- `authentication_settings.scope` decides where the roles are created: per workspace (`"workspace"`, the default) or once per TFE project (`"project"`).
- Per-workspace deviations move into `additional_tfe_workspaces.<name>.override_authentication_settings`, which falls back to `authentication_settings` field by field.

See the [Authentication section of the README](README.md#authentication) for the supported scenarios.

### Variables (v11.0.0)

#### Added (v11.0.0)

- `authentication_settings` — the new home for all authentication inputs:
  - `role_name` — base IAM role name, defaults to a module-generated name.
  - `scope` — `"workspace"` (default) or `"project"`.
  - `set_terraform_role_arn_variables` — also expose the role ARNs as Terraform-category variables, defaults to `true`.
  - `permissions_boundaries` — `workspace_boundary`, `workspace_boundary_name`, `workload_boundary`, `workload_boundary_name`.
  - `roles` — `run`, `plan` and `apply`, each accepting `policy` and `policy_arns`.
- `tfe_project.enable_project_scoped_authentication` — create project-scoped roles *in addition to* per-workspace roles, for workspaces not managed by this module.
- `additional_tfe_workspaces.<name>.override_authentication_settings` — per-workspace override of `add_permissions_boundary`, `role_name`, `scope`, `set_terraform_role_arn_variables` and `roles`. The default workspace has no counterpart by design: it is configured through `authentication_settings` directly, so there is nothing for it to override.

#### Moved (v11.0.0)

`<phase>` is one of `run`, `plan` or `apply`.

| Before (v10.0.0) | After (v11.0.0) |
| --- | --- |
| `permissions_boundaries` | `authentication_settings.permissions_boundaries` |
| `tfe_workspace.policy` | `authentication_settings.roles.<phase>.policy` |
| `tfe_workspace.policy_arns` | `authentication_settings.roles.<phase>.policy_arns` |
| `tfe_workspace.role_name` | `authentication_settings.role_name` |
| `additional_tfe_workspaces.<name>.policy` | `additional_tfe_workspaces.<name>.override_authentication_settings.roles.<phase>.policy` |
| `additional_tfe_workspaces.<name>.policy_arns` | `additional_tfe_workspaces.<name>.override_authentication_settings.roles.<phase>.policy_arns` |
| `additional_tfe_workspaces.<name>.role_name` | `additional_tfe_workspaces.<name>.override_authentication_settings.role_name` |
| `additional_tfe_workspaces.<name>.add_permissions_boundary` | `additional_tfe_workspaces.<name>.override_authentication_settings.add_permissions_boundary` |
| `tfe_project.auth.enabled` | `authentication_settings.scope = "project"`, or `tfe_project.enable_project_scoped_authentication = true` |
| `tfe_project.auth.policy` | `authentication_settings.roles.<phase>.policy` |
| `tfe_project.auth.policy_arns` | `authentication_settings.roles.<phase>.policy_arns` |
| `tfe_project.auth.role_name` | `authentication_settings.role_name` |

The `tfe_project.auth` object is removed entirely; project-scoped roles are now configured through `authentication_settings` like every other role.

#### Removed (v11.0.0)

- `tfe_workspace.enable_workspace_authentication` & `additional_tfe_workspaces.<name>.enable_workspace_authentication` — a workspace either gets its own roles or uses the project-scoped roles, decided by `authentication_settings.scope` and `override_authentication_settings.scope`. Switching authentication off entirely is no longer possible, and this is deliberate: an AVM-managed workspace exists to manage the account it belongs to, so it always needs a way to authenticate to it. There is no supported way to run this module without authentication.
- `tfe_workspace.add_permissions_boundary` & `tfe_project.auth.add_permissions_boundary` — the workspace boundary is now attached to every role this module creates whenever `authentication_settings.permissions_boundaries` is set. Individual additional workspaces can opt out via `override_authentication_settings.add_permissions_boundary = false`.

### Behaviour (v11.0.0)

1. **Three roles per workspace by default.** `authentication_settings.roles` defaults to `run` and `apply` with `AdministratorAccess` and `plan` with `ReadOnlyAccess`. Where v10 created one role per workspace, v11 creates three and sets `TFC_AWS_RUN_ROLE_ARN`, `TFC_AWS_PLAN_ROLE_ARN` and `TFC_AWS_APPLY_ROLE_ARN`. Terraform Cloud uses the phase-specific ARN when it is present and falls back to the run role otherwise.
2. **The default workspace's run role is renamed, by this module's new default rather than by the child module.** In the child module the run role is the unsuffixed one — `Plan` and `Apply` are appended for the new phase-specific roles only — and its state is migrated in place, so adding plan and apply roles is purely additive. What does change is the default that this module passes down: `tfe_workspace.role_name` defaulted to `TFEPipeline` in v10, while `authentication_settings.role_name` defaults to `null`, which lets the child module derive the name from the workspace name. For an account named `my-aws-account`, the default workspace's run role therefore becomes `TFEPipelineMyAwsAccountRole` instead of `TFEPipelineRole`. Because IAM role names cannot change in place, that **replaces the role** and changes its ARN. The new default is what makes [scenario 3](README.md#scenario-3-project-scoped-roles-alongside-per-workspace-roles) possible — in v10 the default workspace role and the project role were both named `TFEPipeline` and could not coexist. Additional workspaces are unaffected: their names were already derived this way. Set `authentication_settings.role_name = "TFEPipeline"` to keep the v10 name.
3. **Permissions boundaries are attached automatically.** In v10 you configured `permissions_boundaries` *and* opted in per workspace with `add_permissions_boundary = true`. In v11, configuring `authentication_settings.permissions_boundaries` attaches the workspace boundary to every role the module creates. If you previously configured boundaries but left the opt-in off, those roles now get a boundary.
4. **Both boundaries are now required together.** `workspace_boundary` and `workload_boundary` are mandatory fields inside `authentication_settings.permissions_boundaries`; in v10 either could be set on its own. `workspace_boundary_name` now defaults to `pipeline_boundary` and `workload_boundary_name` to `workload_boundary`.
5. **Role ARNs are also published as Terraform variables.** `authentication_settings.set_terraform_role_arn_variables` defaults to `true`, adding `tfc_aws_run_role_arn`, `tfc_aws_plan_role_arn` and `tfc_aws_apply_role_arn` Terraform-category variables next to the `TFC_AWS_*` environment variables. This is new in v11; set it to `false` to keep only the environment variables.
6. **`tfe_project.enabled` defaults to `true` when project-scoped authentication is enabled**, since those roles need a project. Setting it to `false` in that case is rejected. Otherwise it still defaults to `false`.

> [!WARNING]
> Anything outside this module that grants access to a pipeline role by ARN — S3 bucket policies, KMS key policies, cross-account trust policies, SCP conditions — breaks when a role is replaced. Check for such references before applying, and update them in the same change.

### How to upgrade v11.0.0

Pick one of the two paths below, then run `terraform init -upgrade` and review `terraform plan` before applying.

#### Option 1: keep the v10 behaviour (v11.0.0)

Reproduces one `AdministratorAccess` role per workspace, with the same names and the same workspace variables as v10.

Set `roles` to `run` only, and turn the new Terraform-category variables off:

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "~> 11.0"

  # ...

  authentication_settings = {
    set_terraform_role_arn_variables = false

    roles = {
      run = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    }
  }
}
```

If you configured permissions boundaries in v10, move the variable and keep in mind that the boundary now applies to every role:

```hcl
authentication_settings = {
  # ...
  permissions_boundaries = {
    workspace_boundary      = "${path.module}/workspace_boundary.json"
    workspace_boundary_name = "workspace_boundary"
    workload_boundary       = "${path.module}/workload_boundary.json"
    workload_boundary_name  = "workload_boundary"
  }
}
```

Additional workspaces that had `add_permissions_boundary = false` (the v10 default) and should stay without a boundary need to say so explicitly:

```hcl
additional_tfe_workspaces = {
  sandbox = {
    override_authentication_settings = {
      add_permissions_boundary = false
    }
  }
}
```

If you used `tfe_project.auth.enabled = true` next to workspace authentication, replace it with the escape hatch that keeps both sets of roles:

```hcl
authentication_settings = {
  scope = "workspace"
  # ...
}

tfe_project = {
  enable_project_scoped_authentication = true
}
```

Workspaces that had `enable_workspace_authentication = false` have no equivalent, by design — see the removed variables above. Either let them get roles, or move the whole module to `authentication_settings.scope = "project"` so a single set of project roles serves every workspace.

#### Option 2: adopt the new features (v11.0.0)

Accept the defaults and let plan run read-only. The only required change is moving your v10 inputs to their new location; everything else is default:

```hcl
module "aws_account" {
  source  = "schubergphilis-ep/mcaf-avm/aws"
  version = "~> 11.0"

  # ...

  authentication_settings = {
    permissions_boundaries = {
      workspace_boundary = "${path.module}/workspace_boundary.json"
      workload_boundary  = "${path.module}/workload_boundary.json"
    }
  }
}
```

To share one set of roles across every workspace in the project instead, switch the scope — this also enables the TFE project:

```hcl
authentication_settings = {
  scope = "project"
}
```

Recommended rollout when you are moving from a single role to phase-specific roles, so the switch stays reversible:

1. Keep `run` set alongside `plan` and `apply` (the default). Plan and apply assume their own roles, while the run role remains provisioned as a safety net.
2. Verify a plan and an apply in each workspace.
3. Optionally drop `run` once the phase-specific roles are proven, leaving each phase with exactly its own role. Keep `run` if you want a permanent fallback — a phase only falls back to it when its own ARN is absent.

Constraints inherited from the child module: `plan` and `apply` must be set together, and at least one of `run`, `plan` or `apply` must be set.

## Upgrading to v10.0.0

### Key Changes v10.0.0

The `schubergphilis-ep/mcaf-workspace/aws` child modules (the workspace module and its `modules/auth` submodule) are upgraded from `v4` to `v5`, which is **OIDC-only**. IAM-role (external-id / agent) and IAM-user workspace authentication are no longer supported.

### Variables (v10.0.0)

The following variables are removed, as OIDC is now the only authentication method:

- `tfe_workspace.auth_method`, `tfe_workspace.username`, `tfe_workspace.agent_role_arns`
- `additional_tfe_workspaces.auth_method`, `additional_tfe_workspaces.username`, `additional_tfe_workspaces.agent_role_arns`
- `tfe_project.auth.method`, `tfe_project.auth.username`, `tfe_project.auth.agent_role_arns`

### How to upgrade v10.0.0

1. Remove the variables listed above from your module inputs.
2. Ensure any workspace or project that needs AWS access uses OIDC authentication (`enable_workspace_authentication = true`, which is the default).
3. Run `terraform init -upgrade`, then `terraform plan`. Workspaces that previously used IAM-user or IAM-role (external-id / agent) authentication will have their auth resources replaced with an OIDC role trust.

## Upgrading to v9.0.0

### Key Changes v9.0.0

The Terraform provider source for `mcaf` has moved:

- Old source: `schubergphilis/mcaf`
- New source: `schubergphilis-ep/mcaf`

### How to upgrade v9.0.0

1. Update your root module provider configuration to use the new source address.
2. Reinitialize providers: `terraform init -upgrade`
3. Run `terraform plan` and confirm no unexpected recreation caused by provider address drift.

## Upgrading to v8.0.0

### Variables (v8.0.0)

- Variable renamed `tfe_workspace.project_name` & `additional_tfe_workspaces.project_name` -> `tfe_workspace.project_id` & `additional_tfe_workspaces.project_id`.

## Upgrading to v7.0.0

### Variables (v7.0.0)

- Variable removed `tfe_workspace.workspace_tags` & `additional_tfe_workspaces.workspace_tags`.
- Variable renamed `tfe_workspace.workspace_map_tags` & `additional_tfe_workspaces.workspace_map_tags` -> `tfe_workspace.workspace_tags` & `additional_tfe_workspaces.workspace_tags`.
- Variable renamed `tfe_workspace.project_id` & `additional_tfe_workspaces.project_id` -> `tfe_workspace.project_name` & `additional_tfe_workspaces.project_name`.

## Upgrading to v6.0.0

`v6.0.0` introduces a change that is not backwards compatible when the `name` property of `var.additional_tfe_workspaces` is specified and a different key is used in the provided map. Currently, the key is utilized to generate the role name, ignoring the specified `name` property. To correctly override the name field, it should also be used to create the `role_name`. To upgrade without any issues, ensure that the key matches the name in the provided `additional_tfe_workspaces`.

## Upgrading to v5.0.0

`v5.0.0` is not backwards compatible with `v4.4.0` due to the deprecation of `tfe_workspace.trigger_prefixes` & `additional_tfe_workspaces.trigger_prefixes`.

### Variables (v5.0.0)

- Variable removed: `tfe_workspace.trigger_prefixes` & `additional_tfe_workspaces.trigger_prefixes`.
- Default value added: `tfe_workspace.trigger_patterns`. `null` -> `["modules/**/*"]`.

### Behaviour (v5.0.0)

Terraform Cloud now defaults to **trigger patterns** instead of **trigger prefixes**. Trigger prefixes will be deprecated in the future, so migration is recommended.
Trigger patterns provide greater flexibility, efficiency, and control over how your workspaces respond to changes in your repositories. To simplify the module and avoid unnecessary complexity, support for `trigger_prefixes` has been removed.

#### What You Need to Do

If you are using the module's defaults for these variables, you do not need to do anything. The workspaces will automatically be modified to use trigger patterns.
If you have modified the defaults, you will need to take action otherwise Terraform will fail.

#### How to migrate to `trigger_patterns`

1. **Remove** the `trigger_prefixes` input when using this module
2. **Set** equivalent values in `trigger_patterns`

**Example:**

```hcl
# Before
tfe_workspace.trigger_prefixes = ["envs/prod/"]

# After
tfe_workspace.trigger_patterns = ["envs/prod/**/*"]
```

See [documentation on trigger runs when files in specified paths change](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/vcs#only-trigger-runs-when-files-in-specified-paths-change).

## Upgrading to v4.0.0

### Variables (v4.0.0)

- The variable `assessments_enabled` has been introduced with default set to `true`.
- The default `auth_method` has been modified from `iam_user` to `iam_role_oidc`.
- The variable `notification_configuration` has been modified from a `list(object)` to a `map(object)`. They key should be the name of the notification configuration as it will be displayed in Terraform Cloud.

### Outputs (v4.0.0)

- `additional_tfe_workspace` has been renamed to `additional_tfe_workspaces`.

### Behaviour (v4.0.0)

- The variables `account`, `environment`, and `workload_permissions_boundary_arn` are now consolidated into a single variable set per account.
This change reduces the total number of Terraform resources needed by allowing this set to be linked to workspaces, rather than duplicating variables for each one.
Upgrading to this version will recreate these variables.
To add more account-specific variables, use the `account_variable_set` resource.

## Upgrading to v3.0.0

3.0.0 introduces new optional variables and removes existing optional variables. Upgrading requires changes if you currently use the `slack_notification_triggers` or `slack_notification_url` variables.

### Variables (v3.0.0)

In both `var.additional_tfe_workspaces` and `var.tfe_workspaces`:

- Added `workspace_tags`
- The `slack_notification_triggers` & `slack_notification_url` variables have been merged into `notification_configuration`. This allows to easily configure notifications for both slack and teams.

## Upgrading to v2.0.0

2.0.0 is a major refactor to make use of `optional`. This commit also introduces breaking changes while we consolidate variables that previously were optional but could not be part of an object (because we had no way to make specific object keys optional).

### Variables (v2.0.0)

- Renamed `var.account_settings` to `var.account`
- Renamed `var.tfe_workspace_settings` to `var.tfe_workspace`
- Renamed `var.tfe_workspace_settings.terraform_organization` to `var.tfe_workspace.organization`
- Moved variables with a `tfe_workspace_` prefix into `var.tfe_workspace` (and removed the prefix)

### Behaviour (v2.0.0)

- `var.account.environment` (was `var.account_settings.environment`) is now an optional value
- The region configured in the workspace is now set using `var.tfe_workspace.default_region` (was `var.region`) and has been made mandatory
- `var.tfe_workspace.branch` now defaults to `main` to follow the community standard, if using `master` be sure to set this in your workspace configurations
- `var.tfe_workspace.global_remote_state` now defaults to `false`, you will now need to set any workspace IDs that need access to this state
- Additional workspaces now inherit the following values from the default workspace unless specified:
  - `auth_method`
  - `branch`
  - `execution_mode`
  - `oauth_token_id`
  - `region`
  - `repository_identifier`
  - `slack_notification_triggers`
  - `slack_notification_url`
  - `ssh_key_id`
  - `team_access`
  - `terraform_version`
  - `trigger_prefixes`
  - `working_directory`
- [terraform-aws-mcaf-account module](https://github.com/schubergphilis/terraform-aws-mcaf-account) updated to v0.5.1: Fixes deprecation warning by using `organizational_unit_path` instead of `organizational_unit`. This will generate a change in plan and will attempt to update the account via Service Catalog. Service Catalog will "re-enrol" the account as it is not smart enough to realise the current OU and target OU are the same, so a ~10 min apply while this happens is expected and a one time event.

Updated requirements:

- Minimum terraform version has been set to v1.3.0
- Minimum MCAF provider version has been set to v0.4.2 to be compatible with the latest version of service catalogue

## Upgrading to v1.1.0

`v1.1.0` is not backwards compatible with `v1.0.0`. First follow the steps to upgrade to `v1.0.0`. The option to automatically create email address with Office 365 has been removed.

### Variables (v1.1.0)
This upgrade requires the following changes:

- variable `account_settings` no longer supports a field called `create_email_address`.

## Upgrading to v1.0.0

`v1.0.0` is not backward compatible with `v0.4.1` because terraform-aws-mcaf-workspace changed the variables it uses to connect Terraform workspaces to a VCS.

### Variables (v1.0.0)
This upgrade requires the following changes:

- Variable `tfe_workspace_settings` requires an additional field called `global_remote_state`, either enabling or disabling global remote state on the workspace.
- Variable `tfe_workspace_settings` requires an additional field called `remote_state_consumer_ids`, containing a set of workspace ID's that are allowed access to the global remote state. Set to `null` to share with everyone.
- Variable `tfe_workspace_settings` requires an additional field called `working_directory`, sets the working directory for a workspace. Set to `null` to fall back to module defaults.
- The fields `repository_owner` and `repository_name` have been replaced by a single field called `repository_identifier`, combining the two values into a single field. Set to `null` to disable VCS connection.
- Additional workspaces require fields `global_remote_state` and `remote_state_consumer_ids` to be present.
- Within additional workspaces, the fields `repository_owner` and `repository_name` have been replaced by a single field called `repository_identifier`, combining the two values into a single field. Set to `null` to disable VCS connection.
