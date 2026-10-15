
# ea => assets that receive early-adopter rule versions (release:ea)
# ga => assets that receive generally available rule versions (release:ga)

locals {
  release_tag_key = "dtor-x"

  releases = {
    ea = {
      title       = "Early Adopters"
      description = "Assets that receive early-adopter (silent release) rule versions."
      tag_value   = "ea-group"
    }
    ga = {
      title       = "General Availability"
      description = "Assets that receive generally available rule versions."
      tag_value   = "ga-group"
    }
  }
}

resource "cortexcloud_asset_group" "release" {
  for_each = local.releases

  name        = "${local.name_prefix}${upper(each.key)} - ${each.value.title}"
  type        = "Dynamic"
  description = "${each.value.description} Membership: cloud tag ${local.release_tag_key}=${each.value.tag_value}."

  membership_predicate = {
    and = [
      {
        search_field = "xdm.asset.tags"
        search_type  = "JSON_WILDCARD"
        search_value = jsonencode({ key = local.release_tag_key, value = each.value.tag_value })
      },
    ]
  }
}

output "asset_groups" {
  description = "Release asset groups: release => { id, name }"
  value = {
    for release, group in cortexcloud_asset_group.release :
    release => { id = group.id, name = group.name }
  }
}
