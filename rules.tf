# Every folder under rules/ is one rule:
#   rules/<rule-id>/rule.yaml   shared metadata, per-version overrides, releases
#   rules/<rule-id>/<version>.xql
#
# Only versions referenced by release.ga / release.ea are deployed. Each
# deployed version is labelled with the release(s) it serves (release:ga, release:ea),
# so policies select by release label and never change when a rule is released.

locals {
  # Prepended to the name of every object this config creates.
  name_prefix = "dtor - "

  rules = {
    for f in fileset(path.module, "rules/*/rule.yaml") :
    basename(dirname(f)) => yamldecode(file("${path.module}/${f}"))
  }

  # "<rule-id>/<version>" => normalized settings for that deployed version.
  rule_versions = merge([
    for id, r in local.rules : {
      for v in distinct([r.release.ga, coalesce(try(r.release.ea, null), r.release.ga)]) :
      "${id}/${v}" => {
        rule_id        = id
        version        = v
        title          = r.title
        asset_type     = r.asset_type
        description    = trimspace(r.description)
        recommendation = try(trimspace(r.recommendation), null)
        labels         = try(r.labels, [])
        severity       = try(r.versions[v].severity, r.severity)
        enabled        = try(r.versions[v].enabled, try(r.enabled, true))
        releases = compact([
          v == r.release.ga ? "ga" : "",
          v == coalesce(try(r.release.ea, null), r.release.ga) ? "ea" : "",
        ])
      }
    }
  ]...)
}

resource "cortexcloud_cloudsec_rule" "this" {
  for_each = local.rule_versions

  name        = "${local.name_prefix}${each.value.title} [${each.value.version}]"
  description = "${each.value.description}\n\nRule: ${each.value.rule_id} | Version: ${each.value.version}"
  class       = "config"
  asset_types = [each.value.asset_type]
  severity    = each.value.severity
  enabled     = each.value.enabled

  query = {
    xql = file("${path.module}/rules/${each.value.rule_id}/${each.value.version}.xql")
  }

  metadata = each.value.recommendation == null ? null : {
    issue = { recommendation = each.value.recommendation }
  }

  labels = concat(
    each.value.labels,
    [each.value.rule_id, "${each.value.rule_id}:${each.value.version}"],
    [for release in each.value.releases : "release:${release}"],
  )
}

output "rules" {
  description = "Deployed rule versions: <rule-id>/<version> => { id, name, releases }"
  value = {
    for k, rule in cortexcloud_cloudsec_rule.this :
    k => { id = rule.id, name = rule.name, releases = local.rule_versions[k].releases }
  }
}
