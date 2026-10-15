# One policy per release: rules labelled release:<release> applied to that
# release's asset group. These never change when rules are added or released;
# rules.tf moves versions between releases by changing their labels.

resource "cortexcloud_cloudsec_policy" "release" {
  for_each = local.releases

  name        = "${local.name_prefix}${upper(each.key)} - ${each.value.title}"
  description = "Applies all rule versions labelled release:${each.key} to the ${each.value.title} asset group."
  enabled     = true

  rule_matching = {
    type = "RULE_FILTER"
    # The API requires an AND/OR group at the root, even for a single condition,
    # and "labels" only accepts ARRAY_CONTAINS (the provider docs say EQ).
    filter_criteria = {
      operator = "AND"
      criteria = [
        {
          field = "labels"
          type  = "ARRAY_CONTAINS"
          value = "release:${each.key}"
        },
      ]
    }
  }

  asset_matching = {
    type            = "ASSET_GROUPS"
    asset_group_ids = [cortexcloud_asset_group.release[each.key].id]
  }

  labels = ["release:${each.key}"]
}

output "policies" {
  description = "Release policies: release => { id, name }"
  value = {
    for release, policy in cortexcloud_cloudsec_policy.release :
    release => { id = policy.id, name = policy.name }
  }
}
