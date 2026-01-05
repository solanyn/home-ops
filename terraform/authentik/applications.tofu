locals {
  default_property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oauth2.ids,
    [authentik_property_mapping_provider_scope.email_verified.id]
  )
}

module "onepassword_application" {
  for_each = var.applications
  source   = "github.com/joryirving/terraform-1password-item"
  vault    = "kubernetes"
  item     = each.key
}

locals {
  app_credentials = {
    for k, v in var.applications : k => {
      client_secret = module.onepassword_application[k].fields["${upper(replace(k, "-", "_"))}_CLIENT_SECRET"]
    }
  }
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each              = var.applications
  name                  = each.key
  client_id             = each.key
  client_secret         = local.app_credentials[each.key].client_secret
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = authentik_flow.invalidation.uuid
  property_mappings     = local.default_property_mappings
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://${each.key}.${var.CLUSTER_DOMAIN}${each.value.redirect_uri}",
    }
  ]
}

resource "authentik_application" "application" {
  for_each           = var.applications
  name               = each.key
  slug               = lower(each.key)
  protocol_provider  = authentik_provider_oauth2.oauth2[each.key].id
  group              = authentik_group.default[each.value.group].name
  open_in_new_tab    = true
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/${each.value.icon}.png"
  meta_launch_url    = "https://${each.key}.${var.CLUSTER_DOMAIN}"
  policy_engine_mode = "all"
}
