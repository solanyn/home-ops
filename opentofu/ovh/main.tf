data "ovh_me" "account" {}

resource "ovh_vps" "edge" {
    display_name = var.vps_display_name
    ovh_subsidiary = data.ovh_me.account.ovh_subsidiary
    plan = [
        {
            duration     = "P1M"
            plan_code    = var.vps_plan_code
            pricing_mode = "default"
            configuration = [
                {
                    label = "vps_datacenter"
                    value = var.vps_datacenter
                },
                {
                    label = "vps_os"
                    value = var.vps_os
                }
            ]
        }
    ]
}
