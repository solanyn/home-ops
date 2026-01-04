## Passwordless authentication flow (usernameless)
resource "authentik_flow" "passwordless" {
  name               = "passwordless-flow"
  title              = "Passwordless Login"
  slug               = "passwordless-flow"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_flow_stage_binding" "passwordless-flow-binding-00" {
  target = authentik_flow.passwordless.uuid
  stage  = authentik_stage_authenticator_validate.authentication-passkey-validation.id
  order  = 0
}

resource "authentik_flow_stage_binding" "passwordless-flow-binding-100" {
  target = authentik_flow.passwordless.uuid
  stage  = authentik_stage_user_login.authentication-login.id
  order  = 100
}

## Authentication flow (username + passkey)
resource "authentik_flow" "authentication" {
  name               = "authentication-flow"
  title              = "Welcome!"
  slug               = "authentication-flow"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_flow_stage_binding" "authentication-flow-binding-00" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_identification.authentication-identification.id
  order  = 0
}

resource "authentik_flow_stage_binding" "authentication-flow-binding-10" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_authenticator_validate.authentication-passkey-validation.id
  order  = 10
}

resource "authentik_flow_stage_binding" "authentication-flow-binding-100" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_user_login.authentication-login.id
  order  = 100
}

## Invalidation flow
resource "authentik_flow" "invalidation" {
  name               = "invalidation-flow"
  title              = "Invalidation Flow"
  slug               = "invalidation-flow"
  policy_engine_mode = "any"
  designation        = "invalidation"
  denied_action      = "continue"
}

resource "authentik_flow_stage_binding" "invalidation-flow-binding-00" {
  target = authentik_flow.invalidation.uuid
  stage  = authentik_stage_user_logout.invalidation-logout.id
  order  = 0
}

## Admin backup authentication flow (password-based)
resource "authentik_flow" "admin-backup" {
  name               = "admin-backup-flow"
  title              = "Admin Backup Login"
  slug               = "admin-backup"
  designation        = "authentication"
  policy_engine_mode = "any"
}

resource "authentik_flow_stage_binding" "admin-backup-flow-binding-00" {
  target = authentik_flow.admin-backup.uuid
  stage  = authentik_stage_identification.admin-backup-identification.id
  order  = 0
}

resource "authentik_flow_stage_binding" "admin-backup-flow-binding-10" {
  target = authentik_flow.admin-backup.uuid
  stage  = authentik_stage_password.admin-backup-password.id
  order  = 10
}

resource "authentik_flow_stage_binding" "admin-backup-flow-binding-20" {
  target = authentik_flow.admin-backup.uuid
  stage  = authentik_stage_authenticator_validate.admin-backup-totp.id
  order  = 20
}

resource "authentik_flow_stage_binding" "admin-backup-flow-binding-100" {
  target = authentik_flow.admin-backup.uuid
  stage  = authentik_stage_user_login.authentication-login.id
  order  = 100
}

## Recovery flow (admin-initiated only)
resource "authentik_flow" "recovery" {
  name               = "recovery-flow"
  title              = "Account recovery"
  slug               = "account-recovery"
  designation        = "recovery"
  compatibility_mode = true
}

resource "authentik_flow_stage_binding" "recovery-flow-binding-00" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_identification.recovery-identification.id
  order  = 0
}

resource "authentik_flow_stage_binding" "recovery-flow-binding-10" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_email.recovery-email.id
  order  = 10
}

## Invitation enrollment flow (passkey setup)
resource "authentik_flow" "enrollment-invitation" {
  name               = "enrollment-invitation-flow"
  title              = "Set up your account"
  slug               = "enrollment-invitation"
  designation        = "enrollment"
  compatibility_mode = true
}

resource "authentik_flow_stage_binding" "enrollment-invitation-flow-binding-00" {
  target = authentik_flow.enrollment-invitation.uuid
  stage  = authentik_stage_invitation.enrollment-invitation.id
  order  = 0
}

resource "authentik_flow_stage_binding" "enrollment-invitation-flow-binding-10" {
  target = authentik_flow.enrollment-invitation.uuid
  stage  = authentik_stage_prompt.source-enrollment-prompt.id
  order  = 10
}

resource "authentik_flow_stage_binding" "enrollment-invitation-flow-binding-20" {
  target = authentik_flow.enrollment-invitation.uuid
  stage  = authentik_stage_authenticator_webauthn.enrollment-passkey-setup.id
  order  = 20
}

resource "authentik_flow_stage_binding" "enrollment-invitation-flow-binding-30" {
  target = authentik_flow.enrollment-invitation.uuid
  stage  = authentik_stage_user_write.enrollment-user-write.id
  order  = 30
}

resource "authentik_flow_stage_binding" "enrollment-invitation-flow-binding-40" {
  target = authentik_flow.enrollment-invitation.uuid
  stage  = authentik_stage_user_login.source-enrollment-login.id
  order  = 40
}

## User settings flow
resource "authentik_flow" "user-settings" {
  name               = "User settings"
  title              = "Update your info"
  slug               = "user-settings-flow"
  policy_engine_mode = "any"
  denied_action      = "message_continue"
  designation        = "stage_configuration"
}

resource "authentik_flow_stage_binding" "user-settings-flow-binding-20" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_prompt.user-settings.id
  order  = 20
}

resource "authentik_flow_stage_binding" "user-settings-flow-binding-100" {
  target = authentik_flow.user-settings.uuid
  stage  = authentik_stage_user_write.user-settings-write.id
  order  = 100
}

## Authorization flow
resource "authentik_flow" "provider-authorization-implicit-consent" {
  name               = "Authorize Application"
  title              = "Redirecting to %(app)s"
  slug               = "provider-authorization-implicit-consent"
  policy_engine_mode = "any"
  denied_action      = "message_continue"
  designation        = "authorization"
}
