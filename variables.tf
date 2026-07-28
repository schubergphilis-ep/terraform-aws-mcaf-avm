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
    role_name_prefix                 = optional(string)                     # automatically set by the module if not provided
    scope                            = optional(set(string), ["workspace"]) # "project", "workspace", or both
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
      run   = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
      plan  = { policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"] }
      apply = { policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    })
  })
  default     = {}
  description = "TFE AWS authentication settings. `scope` determines where the pipeline IAM roles are created: \"project\" creates a single set of roles shared by every workspace in the project, \"workspace\" creates a set of roles per workspace, and both can be combined."

  validation {
    condition     = length(setsubtract(var.authentication_settings.scope, ["project", "workspace"])) == 0
    error_message = "Authentication scope may only contain \"project\" and/or \"workspace\"."
  }

  validation {
    condition     = length(var.authentication_settings.scope) > 0
    error_message = "Authentication scope must contain at least one of \"project\" or \"workspace\"."
  }
}

variable "tfe_project" {
  type = object({
    enabled = optional(bool) # defaults to true when authentication_settings.scope contains "project".
    name    = optional(string)

    default_agent_pool_id  = optional(string)
    default_execution_mode = optional(string)
    variable_set_ids       = optional(map(string), {})

    variable_set = optional(object({
      clear_text_env_variables       = optional(map(string), {})
      clear_text_hcl_variables       = optional(map(string), {})
      clear_text_terraform_variables = optional(map(string), {})
    }), {})
  })
  default     = {}
  description = "TFE project configuration including variable sets and authentication settings. If no name is provided, var.name will be used for the project name & variable set name. `enabled` defaults to true when authentication_settings.scope contains \"project\", since project-scoped authentication requires a project, and false otherwise."

  validation {
    condition     = var.tfe_project.enabled != false || !contains(var.authentication_settings.scope, "project")
    error_message = "tfe_project.enabled cannot be set to false when authentication_settings.scope contains \"project\"."
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
      enabled = optional(bool)

      role_add_permissions_boundary    = optional(bool)
      role_name_prefix                 = optional(string)
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
  description = "Additional TFE workspaces"

  validation {
    condition = alltrue([
      for name, workspace in var.additional_tfe_workspaces :
      !coalesce(workspace.override_authentication_settings.role_add_permissions_boundary, false)
    ]) || var.authentication_settings.permissions_boundaries != null
    error_message = "override_authentication_settings.role_add_permissions_boundary can only be enabled when authentication_settings.permissions_boundaries is set."
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
