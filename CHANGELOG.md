# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [9.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v8.2.0...v9.0.0) (2026-07-07)


### ⚠ BREAKING CHANGES

* migrate MCAF module & provider sources ([#2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/issues/2))

### 🐛 Fixes

* migrate MCAF module & provider sources ([#2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/issues/2)) ([d09a40f](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/d09a40f3bf24b87719eb4684d459807b25790293))

## [8.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v8.1.1...v8.2.0) (2026-06-08)


### 🚀 Features

* support for attaching additional variable sets to a project ([#84](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/84)) ([53f0d96](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/53f0d96df077ffe2ca2322e1376bcac3e724719d))

## [8.1.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v8.1.0...v8.1.1) (2026-06-02)


### 🐛 Fixes

* project variable set is not attached to workspaces ([#83](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/83)) ([1f90834](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/1f90834b55235ebccc374b3d4586f52cda1d1446))

## [8.1.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v8.0.0...v8.1.0) (2026-06-02)


### 🚀 Features

* support for tfe_project settings ([#82](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/82)) ([30bbc24](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/30bbc24fe885ccc23a08779bc4a47b58e832ca46))

### 🐛 Fixes

* Correct optional alias variable ([#81](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/81)) ([c93c607](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/c93c607e7e0773613f44e17be05281a76b7f0876))

## [8.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v7.0.0...v8.0.0) (2026-04-01)


### ⚠ BREAKING CHANGES

* known after apply issues with tfe project ([#80](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/80))

### 🐛 Fixes

* known after apply issues with tfe project ([#80](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/80)) ([4c190b0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/4c190b0c9257041199ba1b55661b7dce78b277cd))

## [7.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.4.0...v7.0.0) (2026-03-19)


### ⚠ BREAKING CHANGES

* remove deprecated var `workspace_tags`, rename `project_id` to `project_name`, add support for TFE Project scoped AWS access ([#79](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/79))

### 🚀 Features

* remove deprecated var `workspace_tags`, rename `project_id` to `project_name`, add support for TFE Project scoped AWS access ([#79](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/79)) ([c466541](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/c466541fc411768b9f3beb7e5173d6d116ad4073))

## [6.4.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.3.0...v6.4.0) (2025-11-24)


### 🚀 Features

* Improve trigger pattern flexibility ([#78](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/78)) ([498b2b2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/498b2b2258b48fa20c66038e9fc92fc16639910a))

### 🐛 Fixes

* set file_triggers_enabled to false when no vcs is connected instead to null to comply with underlying module structure ([#77](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/77)) ([ed91059](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/ed910598aa596bdd8b905a151be9d2374b4550d4))

## [6.3.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.2.2...v6.3.0) (2025-11-19)


### 🚀 Features

* upgrade mcaf-workspace to v2.6.0 ([#76](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/76)) ([21d68af](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/21d68af7f400d960a8f07e2b78b00e9e62a950b2))

## [6.2.2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.2.1...v6.2.2) (2025-04-29)


### 🐛 Fixes

* output permission boundary names ([#73](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/73)) ([94ccc34](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/94ccc34451e680d53ee4217246fce5813e8a45aa))

## [6.2.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.2.0...v6.2.1) (2025-03-28)


### 🐛 Fixes

* set default for var.tfe_workspace.set_working_directory to true ([#72](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/72)) ([200bf09](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/200bf09aded2433794e02a6f4ebc16fa2f37ea7e))

## [6.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.1.0...v6.2.0) (2025-03-26)


### 🚀 Features

* enhancement: Ignore terraform_version when "" is provided in var.additional_tfe_workspaces.terraform_version ([#71](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/71)) ([5a30bdf](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/5a30bdfdb4afbd0faefb0c0553f9387c79016d19))

## [6.1.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.0.1...v6.1.0) (2025-03-17)


### 🚀 Features

* enhancement: bump aws-mcaf-workspace to 2.5.x ([#70](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/70)) ([4701d5d](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/4701d5dfe05404fdd55a6403bc37e9d4878a70da))

## [6.0.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v6.0.0...v6.0.1) (2025-02-27)


### 🐛 Fixes

* bug: allow the working directory to not be set ([#69](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/69)) ([c555218](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/c5552188f94b855ef96f5d51502aafc9d4a1d977))

## [6.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v5.0.0...v6.0.0) (2025-02-26)


### 🚀 Features

* breaking: generate the role from name if supplied ([#68](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/68)) ([6b292d1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/6b292d195dafd1b2e809f4621abd05a7d721997b))

## [5.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.4.0...v5.0.0) (2025-02-24)


### 🚀 Features

* breaking: deprecate trigger_prefixes ([#67](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/67)) ([55cbc52](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/55cbc52b4e04a41ddca4d9c14e465ddbed10deec))

## [4.4.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.3.1...v4.4.0) (2025-01-28)


### 🚀 Features

* Add speculative_enabled option ([#66](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/66)) ([8815393](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/881539360181d2fe8f65ce08795ef2cb1d0decb2))

## [4.3.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.3.0...v4.3.1) (2025-01-10)


### 🐛 Fixes

* solve issue with using coalesce on null values ([#65](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/65)) ([5ec1e77](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/5ec1e7731953bd8419817fbe60e8f2d2ab117283))

## [4.3.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.2.0...v4.3.0) (2025-01-10)


### 🚀 Features

* Support GitHub app for VCS connections, solve deprecation warnings ([#64](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/64)) ([d9c7c4f](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/d9c7c4f998c2252aa598e5f77c0d5dda0de550e5))

## [4.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.1.0...v4.2.0) (2024-10-29)


### 🚀 Features

* add the region environmental variable to the variable set instead of to each workspace ([#63](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/63)) ([b7eb028](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/b7eb028f291133abf13849169d32988fe3f2505d))

## [4.1.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.0.3...v4.1.0) (2024-09-19)


### 🚀 Features

* enhancement: bumps aws-mcaf-workspace module, note this version recreates the variable AWS_DEFAULT_REGION. ([#62](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/62)) ([f95e9cc](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/f95e9cc21b1905a6ca3fdf11a52e9f50439da6dc))

## [4.0.3](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.0.2...v4.0.3) (2024-08-08)


### 🐛 Fixes

* resolving an error in the inheritance behaviour of `notification_configuration` and `team_access` ([#61](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/61)) ([0b35c0d](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/0b35c0d1d19906f9d08b556f936bd8ad16c7d26e))

## [4.0.2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.0.1...v4.0.2) (2024-08-07)


### 🐛 Fixes

* modify notification-settings behaviour to take "tfe_workspace"  value ([#60](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/60)) ([b081e51](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/b081e510f863b02fb5ea96df053a225d93d5604e))

## [4.0.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v4.0.0...v4.0.1) (2024-08-06)


### 🐛 Fixes

* merge var.account_variable_set.clear_text_terraform_variables into local ([#59](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/59)) ([31e12ee](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/31e12eecada2d296b3dcc5c800e28a71c5f1e991))

## [4.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v3.0.3...v4.0.0) (2024-08-05)


### 🚀 Features

* breaking: solve bug where `notification_configuration` can not contain sensitive values or values known after apply ([#58](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/58)) ([369f0f9](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/369f0f912b4c6a1e60bbf4cabc2bacf5422be2f3))
* account variable set ([#55](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/55)) ([3e83deb](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/3e83deb4a246019ae3e54e54b82684d480c59596))
* breaking: set default auth mode from 'iam_user' to 'iam_role_oidc' and modify outputs ([#57](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/57)) ([f0c9bfb](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/f0c9bfb30931fc0672e1cf691bd3482e0e644dd1))
* add support for the newest variables in mcaf-workspace, set `assessments_enabled` to true by default as is best practise, optimize optionals ([#56](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/56)) ([a1ffe67](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/a1ffe67e0b5c7d549c8c4ae3be7bbc5157d54bd2))

### 🐛 Fixes

* breaking: solve bug where `notification_configuration` can not contain sensitive values or values known after apply ([#58](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/58)) ([369f0f9](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/369f0f912b4c6a1e60bbf4cabc2bacf5422be2f3))

## [3.0.3](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v3.0.2...v3.0.3) (2024-05-16)


### 🐛 Fixes

* add workspace_permissions_boundary_arn output ([#53](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/53)) ([d12cbba](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/d12cbba6b6e3db2373a29d0a8037dcea2711b537))

## [3.0.2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v3.0.1...v3.0.2) (2024-04-30)


### 🐛 Fixes

* Setting `working_directory` shouldn't depend on a VCS connection ([#49](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/49)) ([00c2508](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/00c2508972e6995832c4b7231807bf3679022329))

## [3.0.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v3.0.0...v3.0.1) (2024-03-04)


### 🐛 Fixes

* Add outputs for other modules to consume ([#52](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/52)) ([15be1e8](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/15be1e81e6f30565d601439abf45f8da1680e441))

## [3.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.12.0...v3.0.0) (2024-03-01)


### 🚀 Features

* breaking: update notification variables & add workspace tags for workspace submodule ([#51](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/51)) ([fb7adf6](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/fb7adf648f30ca54147b455bad8aa2f5246f093b))

## [2.12.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.11.0...v2.12.0) (2024-02-22)


### 🚀 Features

* make all runs configurable ([#50](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/50)) ([f738ae6](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/f738ae652989377610034088a60442089e5865d3))

## [2.11.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.10.0...v2.11.0) (2023-09-07)


### 🚀 Features

* Add OIDC support ([#48](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/48)) ([f2f734f](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/f2f734f6a1e6467d51e18c723940907f93cd0871))

## [2.10.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.9.0...v2.10.0) (2023-06-07)


### 🚀 Features

* make permissions boundary conditional for workspaces ([#47](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/47)) ([5602557](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/560255748bd26f85c3ea4cd445b1e5bb15704620))
* make permissions boundary conditional for workspaces ([#47](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/47)) ([5602557](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/560255748bd26f85c3ea4cd445b1e5bb15704620))

## [2.9.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.8.0...v2.9.0) (2023-05-26)


### 🚀 Features

* do not set certain vcs related values when `connect_vcs_repo` has been set to false ([#46](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/46)) ([d8b13ab](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/d8b13ab547638e82cee03d9b55a9333ea7fcf1fd))

## [2.8.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.7.1...v2.8.0) (2023-04-24)


### 🚀 Features

* make the creation of TFE repositories optional ([#44](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/44)) ([3756dc1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/3756dc1b80bcca32198577837b7e2d228344171b))
* make the creation of TFE repositories optional ([#44](https://github.com/schubergphilis/terraform-aws-mcaf-avm/pull/44)) ([3756dc1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/commit/3756dc1b80bcca32198577837b7e2d228344171b))

## [2.7.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.7.0...v2.7.1) (2023-04-03)

## [2.7.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.6.0...v2.7.0) (2023-02-02)

## [2.6.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.5.0...v2.6.0) (2023-01-24)

## [2.5.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.4.0...v2.5.0) (2023-01-20)

## [2.4.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.3.1...v2.4.0) (2023-01-18)

## [2.3.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.3.0...v2.3.1) (2023-01-17)

## [2.3.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.2.0...v2.3.0) (2023-01-16)

## [2.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.1.1...v2.2.0) (2023-01-12)

## [2.1.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.1.0...v2.1.1) (2023-01-11)

## [2.1.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.0.1...v2.1.0) (2023-01-03)

## [2.0.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v2.0.0...v2.0.1) (2022-12-12)

## [2.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v1.2.1...v2.0.0) (2022-11-15)

## [1.2.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v1.2.0...v1.2.1) (2022-01-27)

## [1.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v1.1.0...v1.2.0) (2022-01-14)

## [1.1.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v1.0.0...v1.1.0) (2021-12-29)

## [1.0.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.4.1...v1.0.0) (2021-11-16)

## [0.4.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.4.0...v0.4.1) (2021-10-13)

## [0.4.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.3.2...v0.4.0) (2021-09-16)

## [0.3.2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.3.0...v0.3.2) (2021-04-07)

## [0.3.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.3.1...v0.3.0) (2021-04-02)

## [0.3.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.2.3...v0.3.1) (2021-04-02)

## [0.2.3](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.2.2...v0.2.3) (2021-03-26)

## [0.2.2](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.2.0...v0.2.2) (2021-03-24)

## [0.2.0](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.2.1...v0.2.0) (2021-03-23)

## [0.2.1](https://github.com/schubergphilis-ep/terraform-aws-mcaf-avm/compare/v0.1.0...v0.2.1) (2021-03-23)

## 0.1.0 (2021-02-26)
