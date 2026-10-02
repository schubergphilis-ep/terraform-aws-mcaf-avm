variable "account" {
  type = object({
    alias_prefix = optional(string)
    contact_billing = optional(object({
      email_address = string
      name          = string
      phone_number  = string
      title         = string
    }), null)
    contact_operations = optional(object({
      email_address = string
      name          = string
      phone_number  = string
      title         = string
    }), null)
    contact_security = optional(object({
      email_address = string
      name          = string
      phone_number  = string
      title         = string
    }), null)
    email                    = string
    environment              = optional(string)
    organizational_unit      = string
    provisioned_product_name = optional(string)
    sso_email                = string
    sso_firstname            = optional(string, "AWS Control Tower")
    sso_lastname             = optional(string, "Admin")
  })
  description = "AWS account settings"
}

variable "account_variable_set" {
  type = object({
    name                           = optional(string)
    clear_text_env_variables       = optional(map(string), {})
    clear_text_hcl_variables       = optional(map(string), {})
    clear_text_terraform_variables = optional(map(string), {})
  })
  default     = {}
  description = "Settings of variable set that is attached to each workspace"
}

variable "authentication_settings" {
  type = object({
    role_name                        = optional(string, "TFEPipeline") # base role name for the tfe_workspace or project, never inherited by additional workspaces
    scope                            = optional(string, "workspace")   # either "project" or "workspace"
    set_terraform_role_arn_variables = optional(bool, true)

    permissions_boundaries = optional(object({
      workspace_boundary      = string
      workspace_boundary_name = optional(string, "pipeline_boundary")
      workload_boundary       = string
      workload_boundary_name  = optional(string, "workload_boundary")
    }))

    roles = optional(object({
      run = optional(object({
        policy      = optional(string)
        policy_arns = optional(set(string), [])
      }))
      plan = optional(object({
        policy      = optional(string)
        policy_arns = optional(set(string), [])
      }))
      apply = optional(object({
        policy      = optional(string)
        policy_arns = optional(set(string), [])
      }))
      }), {
      run = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
      plan = {
        policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

        // ReadOnlyAccess grants no access to secret values or to decrypting, which a plan does need
        // whenever the configuration reads a secret or a KMS-encrypted resource.
        policy = <<-EOT
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Sid": "SensitiveDataReads",
                "Effect": "Allow",
                "Action": [
                  "secretsmanager:GetSecretValue",
                  "kms:Decrypt",
                  "kms:GenerateDataKey",
                  "kms:GenerateDataKeyPair"
                ],
                "Resource": "*"
              }
            ]
          }
        EOT
      }
      apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    })
  })
  default     = {}
  description = "TFE AWS authentication settings. `scope` determines where the pipeline IAM roles are created: \"project\" creates a single set of roles shared by every workspace in the project, \"workspace\" creates a set of roles per workspace. `role_name` is the base role name for the default workspace's roles and, unless `tfe_project.role_name` overrides it, for the project-scoped roles too."

  validation {
    condition     = contains(["project", "workspace"], var.authentication_settings.scope)
    error_message = "Authentication scope must be either \"project\" or \"workspace\"."
  }
}

variable "tfe_project" {
  type = object({
    enabled = optional(bool) # defaults to true when project-scoped authentication is enabled
    name    = optional(string)

    default_agent_pool_id                = optional(string)
    default_execution_mode               = optional(string)
    enable_project_scoped_authentication = optional(bool)   # defaults to true when authentication_settings.scope is "project"
    role_name                            = optional(string) # names the project-scoped roles, falls back to authentication_settings.role_name
    variable_set_ids                     = optional(map(string), {})

    variable_set = optional(object({
      clear_text_env_variables       = optional(map(string), {})
      clear_text_hcl_variables       = optional(map(string), {})
      clear_text_terraform_variables = optional(map(string), {})
    }), {})

    team_access = optional(map(object({
      access = optional(string, null),
      project_access = optional(object({
        settings      = optional(string, null),
        teams         = optional(string, null),
        variable_sets = optional(string, null),
      }), null),
      workspace_access = optional(object({
        create           = optional(bool, null),
        delete           = optional(bool, null),
        locking          = optional(bool, null),
        move             = optional(bool, null),
        policy_overrides = optional(bool, null),
        run_tasks        = optional(bool, null),
        runs             = optional(string, null),
        sentinel_mocks   = optional(string, null),
        state_versions   = optional(string, null),
        variables        = optional(string, null)
      }), null)
    })), {})
  })
  default     = {}
  description = "TFE project configuration including variable sets and authentication settings. If no name is provided, var.name will be used for the project name & variable set name. `enable_project_scoped_authentication` defaults to true when authentication_settings.scope is \"project\"; set it to true while the scope is \"workspace\" to create project-scoped roles in addition to the per-workspace roles. `enabled` defaults to true whenever project-scoped authentication is enabled. `role_name` names the project-scoped roles and falls back to `authentication_settings.role_name` when unset; it must be set explicitly when project-scoped roles are created alongside the default workspace's roles."

  validation {
    condition     = var.tfe_project.enable_project_scoped_authentication != false || var.authentication_settings.scope != "project"
    error_message = "tfe_project.enable_project_scoped_authentication cannot be set to false when authentication_settings.scope is \"project\"."
  }

  validation {
    condition     = var.tfe_project.enabled != false || !coalesce(var.tfe_project.enable_project_scoped_authentication, var.authentication_settings.scope == "project")
    error_message = "tfe_project.enabled cannot be set to false when project-scoped authentication is enabled, either through authentication_settings.scope or tfe_project.enable_project_scoped_authentication."
  }

  // The project roles fall back to `authentication_settings.role_name`, which also names the default
  // workspace's roles, so the two have to be told apart whenever both are created in the same account.
  validation {
    condition = (
      !coalesce(var.tfe_project.enable_project_scoped_authentication, false) ||
      var.authentication_settings.scope != "workspace" ||
      !var.create_default_workspace ||
      coalesce(var.tfe_project.role_name, var.authentication_settings.role_name) != var.authentication_settings.role_name
    )
    error_message = "tfe_project.role_name must be set to a name other than authentication_settings.role_name when project-scoped roles are created alongside the default workspace's roles, since both are IAM roles in the same account. Left unset it falls back to authentication_settings.role_name (\"TFEPipeline\" by default), so name it explicitly, for example tfe_project.role_name = \"TFEPipelineProject\"."
  }

  validation {
    condition = (
      var.tfe_project.default_execution_mode == null ||
      contains(["remote", "agent", "local"], var.tfe_project.default_execution_mode)
    )
    error_message = "Default execution mode must be one of 'remote', 'agent', or 'local'"
  }

  validation {
    condition = (
      var.tfe_project.default_agent_pool_id == null ||
      var.tfe_project.default_execution_mode == "agent"
    )
    error_message = "Default agent pool ID can only be set if default execution mode is 'agent'"
  }

  validation {
    condition = (
      var.tfe_project.team_access == null ||
      alltrue([
        for team, config in var.tfe_project.team_access : (
          (
            contains(["admin", "maintain", "read", "write"], config.access) &&
            config.project_access == null && config.workspace_access == null
          ) ||
          (
            config.access == "custom" &&
            (config.project_access != null && config.workspace_access != null)
          )
        )
      ])
    )

    error_message = "Team access configuration is invalid. Each team must have a valid access (allowed values are 'admin', 'maintain', 'read', 'write', 'custom'), both project_access and workspace_access must be set if access is 'custom' and null if using a predefined access level."
  }
}

variable "additional_tfe_workspaces" {
  type = map(object({
    agent_pool_id                                = optional(string)
    allow_destroy_plan                           = optional(bool)
    assessments_enabled                          = optional(bool)
    auto_apply                                   = optional(bool, false)
    auto_apply_run_trigger                       = optional(bool, false)
    auto_destroy_activity_duration               = optional(string)
    auto_destroy_at                              = optional(string)
    branch                                       = optional(string)
    clear_text_env_variables                     = optional(map(string), {})
    clear_text_hcl_variables                     = optional(map(string), {})
    clear_text_terraform_variables               = optional(map(string), {})
    connect_vcs_repo                             = optional(bool, true)
    default_region                               = optional(string)
    description                                  = optional(string)
    execution_mode                               = optional(string)
    file_triggers_enabled                        = optional(bool, true)
    force_delete                                 = optional(bool, false)
    global_remote_state                          = optional(bool, false)
    name                                         = optional(string)
    project_id                                   = optional(string)
    queue_all_runs                               = optional(bool)
    remote_state_consumer_ids                    = optional(set(string))
    repository_identifier                        = optional(string)
    sensitive_env_variables                      = optional(map(string), {})
    sensitive_hcl_variables                      = optional(map(object({ sensitive = string })), {})
    sensitive_terraform_variables                = optional(map(string), {})
    set_working_directory                        = optional(bool)
    speculative_enabled                          = optional(bool, true)
    ssh_key_id                                   = optional(string)
    terraform_version                            = optional(string)
    trigger_patterns                             = optional(list(string))
    trigger_patterns_working_directory_recursive = optional(bool)
    variable_set_ids                             = optional(map(string), {})
    vcs_github_app_installation_id               = optional(string)
    vcs_oauth_token_id                           = optional(string)
    working_directory                            = optional(string)
    workspace_tags                               = optional(map(string))

    override_authentication_settings = optional(object({
      add_permissions_boundary         = optional(bool)   # defaults to true when authentication_settings.permissions_boundaries is set, set to false to opt this workspace out
      role_name                        = optional(string) # derived from the workspace name when null, never inherited from authentication_settings
      scope                            = optional(string) # only accepts "workspace", inherits authentication_settings.scope when null
      set_terraform_role_arn_variables = optional(bool)

      roles = optional(object({
        run = optional(object({
          policy      = optional(string)
          policy_arns = optional(set(string), [])
        }))
        plan = optional(object({
          policy      = optional(string)
          policy_arns = optional(set(string), [])
        }))
        apply = optional(object({
          policy      = optional(string)
          policy_arns = optional(set(string), [])
        }))
      }), {})
    }), {})

    notification_configuration = optional(map(object({
      destination_type = string
      enabled          = optional(bool, true)
      url              = string
      triggers = optional(list(string), [
        "run:created",
        "run:planning",
        "run:needs_attention",
        "run:applying",
        "run:completed",
        "run:errored",
      ])
    })), null)

    team_access = optional(map(object({
      access = optional(string, null),
      permissions = optional(object({
        run_tasks         = bool
        runs              = string
        sentinel_mocks    = string
        state_versions    = string
        variables         = string
        workspace_locking = bool
      }), null)
    })), null)
  }))
  default     = {}
  description = "Additional TFE workspaces. Set `override_authentication_settings.scope` to \"workspace\" to give a workspace its own IAM roles while authentication_settings.scope is \"project\"; leave it null to follow authentication_settings.scope. Every field of `override_authentication_settings` falls back to `authentication_settings` when null, except `role_name`, which is derived from the workspace name instead so that role names stay unique."

  validation {
    condition = alltrue([
      for name, workspace in var.additional_tfe_workspaces :
      contains(["workspace"], coalesce(workspace.override_authentication_settings.scope, "workspace"))
    ])
    error_message = "override_authentication_settings.scope can only be set to \"workspace\"."
  }

  validation {
    condition = alltrue([
      for name, workspace in var.additional_tfe_workspaces :
      !coalesce(workspace.override_authentication_settings.add_permissions_boundary, false)
    ]) || var.authentication_settings.permissions_boundaries != null
    error_message = "override_authentication_settings.add_permissions_boundary can only be enabled when authentication_settings.permissions_boundaries is set."
  }
}

variable "create_default_workspace" {
  type        = bool
  default     = true
  description = "Set to false to skip creating default workspace"
}

variable "name" {
  type        = string
  description = "Name of the account and default TFE workspace"
}

variable "path" {
  type        = string
  default     = "/"
  description = "Optional path for all IAM users, user groups, roles, and customer managed policies created by this module"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to all resources"
}

variable "tfe_workspace" {
  type = object({
    agent_pool_id                                = optional(string)
    allow_destroy_plan                           = optional(bool, true)
    assessments_enabled                          = optional(bool, true)
    auto_apply                                   = optional(bool, false)
    auto_apply_run_trigger                       = optional(bool, false)
    auto_destroy_activity_duration               = optional(string)
    auto_destroy_at                              = optional(string)
    branch                                       = optional(string, "main")
    clear_text_env_variables                     = optional(map(string), {})
    clear_text_hcl_variables                     = optional(map(string), {})
    clear_text_terraform_variables               = optional(map(string), {})
    connect_vcs_repo                             = optional(bool, true)
    default_region                               = string
    description                                  = optional(string)
    execution_mode                               = optional(string, "remote")
    file_triggers_enabled                        = optional(bool, true)
    force_delete                                 = optional(bool, false)
    global_remote_state                          = optional(bool, false)
    name                                         = optional(string)
    organization                                 = optional(string)
    project_id                                   = optional(string)
    queue_all_runs                               = optional(bool)
    remote_state_consumer_ids                    = optional(set(string))
    repository_identifier                        = optional(string)
    sensitive_env_variables                      = optional(map(string), {})
    sensitive_hcl_variables                      = optional(map(object({ sensitive = string })), {})
    sensitive_terraform_variables                = optional(map(string), {})
    set_working_directory                        = optional(bool, true)
    speculative_enabled                          = optional(bool, true)
    ssh_key_id                                   = optional(string)
    terraform_version                            = optional(string)
    trigger_patterns                             = optional(list(string), ["modules/**/*"])
    trigger_patterns_working_directory_recursive = optional(bool)
    variable_set_ids                             = optional(map(string), {})
    vcs_github_app_installation_id               = optional(string)
    vcs_oauth_token_id                           = optional(string)
    working_directory                            = optional(string)
    workspace_tags                               = optional(map(string))

    notification_configuration = optional(map(object({
      destination_type = string
      enabled          = optional(bool, true)
      url              = string
      triggers = optional(list(string), [
        "run:created",
        "run:planning",
        "run:needs_attention",
        "run:applying",
        "run:completed",
        "run:errored",
      ])
    })), {})

    team_access = optional(map(object({
      access = optional(string, null),
      permissions = optional(object({
        run_tasks         = bool
        runs              = string
        sentinel_mocks    = string
        state_versions    = string
        variables         = string
        workspace_locking = bool
      }), null)
    })), {})
  })
  description = "TFE workspace settings"
}
