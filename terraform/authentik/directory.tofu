locals {
  authentik_groups = {
    admin = { name = "Admin" }
    users = { name = "Users" }
  }
}

data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "default" {
  for_each     = local.authentik_groups
  name         = each.value.name
  is_superuser = false
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = var.applications

  target = authentik_application.application[each.key].uuid
  group  = authentik_group.default[each.value.group].id
  order  = 0
}

# Update with your details
resource "authentik_user" "andrew" {
  username = "andrew"
  name     = "Andrew"
  email    = "andrew@${var.CLUSTER_DOMAIN}"
  groups = concat(
    [data.authentik_group.admins.id],
    values(authentik_group.default)[*].id
  )
}
