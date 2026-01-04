## Authentication stages
data "authentik_source" "inbuilt" {
  managed = "goauthentik.io/sources/inbuilt"
}

resource "authentik_stage_identification" "authentication-identification" {
  name                      = "authentication-identification"
  user_fields               = []
  case_insensitive_matching = false
  show_source_labels        = false
  show_matched_user         = false
  passwordless_flow         = authentik_flow.passwordless.uuid
  recovery_flow             = authentik_flow.recovery.uuid
  sources                   = [data.authentik_source.inbuilt.uuid]
}

resource "authentik_stage_authenticator_validate" "authentication-passkey-validation" {
  name                     = "authentication-passkey-validation"
  device_classes           = ["webauthn"]
  not_configured_action    = "deny"
  webauthn_user_verification = "preferred"
}

resource "authentik_stage_user_login" "authentication-login" {
  name = "authentication-login"
}

## Invalidation stages
resource "authentik_stage_user_logout" "invalidation-logout" {
  name = "invalidation-logout"
}

## Admin backup stages
resource "authentik_stage_identification" "admin-backup-identification" {
  name                      = "admin-backup-identification"
  user_fields               = ["username"]
  password_stage            = authentik_stage_password.admin-backup-password.id
  passwordless_flow         = authentik_flow.passwordless.uuid
  case_insensitive_matching = false
  show_source_labels        = false
  show_matched_user         = true
  sources                   = [data.authentik_source.inbuilt.uuid]
}

resource "authentik_stage_password" "admin-backup-password" {
  name     = "admin-password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_authenticator_validate" "admin-backup-totp" {
  name                  = "admin-backup-totp"
  device_classes        = ["totp"]
  not_configured_action = "skip"
}

## Recovery stages (admin-only password reset)
resource "authentik_stage_identification" "recovery-identification" {
  name                      = "recovery-identification"
  user_fields               = ["username", "email"]
  case_insensitive_matching = false
  show_source_labels        = false
  show_matched_user         = false
}

resource "authentik_stage_email" "recovery-email" {
  name                     = "recovery-email"
  activate_user_on_success = true
  use_global_settings      = true
  template                 = "email/password_reset.html"
  subject                  = "Account recovery"
}

## Invitation stages
resource "authentik_stage_invitation" "enrollment-invitation" {
  name                             = "enrollment-invitation"
  continue_flow_without_invitation = false
}

resource "authentik_stage_prompt" "source-enrollment-prompt" {
  name = "source-enrollment-prompt"
  fields = [
    resource.authentik_stage_prompt_field.username.id,
    resource.authentik_stage_prompt_field.name.id,
    resource.authentik_stage_prompt_field.email.id
    # No password fields - passkey only
  ]
}

resource "authentik_stage_authenticator_webauthn" "enrollment-passkey-setup" {
  name                        = "enrollment-passkey-setup"
  user_verification           = "required"
  authenticator_attachment    = "cross-platform"
  resident_key_requirement    = "required"
}

resource "authentik_stage_user_write" "enrollment-user-write" {
  name                     = "enrollment-user-write"
  create_users_as_inactive = false
  create_users_group       = authentik_group.default["users"].id
}

resource "authentik_stage_user_login" "source-enrollment-login" {
  name             = "source-enrollment-login"
  session_duration = "seconds=0"
}

## User settings stages
resource "authentik_stage_prompt" "user-settings" {
  name = "user-settings"
  fields = [
    resource.authentik_stage_prompt_field.username.id,
    resource.authentik_stage_prompt_field.name.id,
    resource.authentik_stage_prompt_field.email.id,
    resource.authentik_stage_prompt_field.locale.id
  ]
  validation_policies = [
    resource.authentik_policy_expression.user-settings-authorization.id
  ]
}

resource "authentik_stage_user_write" "user-settings-write" {
  name                     = "user-settings-write"
  create_users_as_inactive = false
}
