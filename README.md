# Cortex Cloud rule versioning with Terraform

Manages custom Cortex Cloud detection rules (`cortexcloud_cloudsec_rule`) as code, with versioning and a **silent release** of new versions to an early-adopter scope before they reach everyone.

## How it works

Each rule lives in its own folder:

```
rules/
  aws-sg-ssh-open/        # folder name = rule id
    rule.yaml             # metadata, per-version overrides, releases
    v1.xql                # one XQL file per version
    v2.xql
```

`rules.tf` reads every `rules/*/rule.yaml` and creates one Cortex rule per **deployed version**. You never edit `rules.tf` to add a rule.

### Releases

There are two releases:

| Release | Who gets it | Set by |
|---------|-------------|--------|
| `ga` | Everyone | `release.ga` |
| `ea` | Early adopters | `release.ea` (if omitted, same as `ga`) |

Only versions referenced in `release` are deployed. Each one is labelled with the release(s) it serves:

| `release` | v1 labels | v2 labels |
|-----------|-----------|-----------|
| `ga: v1` | `release:ga`, `release:ea` | not deployed |
| `ga: v1`, `ea: v2` | `release:ga` | `release:ea` |
| `ga: v2` | not deployed | `release:ga`, `release:ea` |

`release:ea` means "early adopters run this version", not "this is a preview". With no silent release in progress, early adopters run the GA version, so it carries both labels. Without `release:ea`, the EA policy would match nothing and early adopters would have no version of the rule.

When the next version enters early release (`ga: v2`, `ea: v3`), `release:ea` moves from v2 to v3. v2 keeps only `release:ga`.

Each release has one asset group (`asset_groups.tf`) and one policy (`policies.tf`). The policy selects rules by release label and is scoped to that release's asset group:

| Release | Asset group membership | Policy rule filter |
|---------|------------------------|--------------------|
| `ea` | cloud tag `dtor-x` = `ea-group` | label `release:ea` |
| `ga` | cloud tag `dtor-x` = `ga-group` | label `release:ga` |

To move an asset between releases, change its cloud tag.

> **Note:** The tag-based asset groups are a mock to demonstrate the scenario. In a real deployment, use membership filters that match how early adopters are actually chosen. For example, the EA group could be one or more specific cloud account IDs, and the GA group every account except those. The two groups must not overlap and must cover every asset together, so each asset runs exactly one version of each rule.

The policies never change. Releasing a version only changes labels, so every asset gets exactly one version of each rule.

### Naming and labels

Every deployed version gets:

- **Name:** `dtor - <title> [<version>]`. The prefix is set by `name_prefix` in `rules.tf`.
- **Labels:** the labels from `rule.yaml`, plus `<rule-id>`, `<rule-id>:<version>` and `release:<ea|ga>`.

## rule.yaml

```yaml
title: AWS Security Group allows SSH (22) from the internet
asset_type: EC2_SECURITY_GROUP
severity: high          # default for all versions
enabled: true           # default for all versions
labels: [network, aws]
description: |
  ...
recommendation: |
  ...

versions:               # optional per-version overrides (severity, enabled)
  v2:
    severity: medium

release:
  ga: v1
  ea: v2                # optional
```

The XQL's final `fields` stage must include `asset_type_id`.

## Workflows

**Add a new rule**
1. Create `rules/<rule-id>/` containing `rule.yaml` and `v1.xql`.
2. Set `release: { ga: v1 }`.

**Silent release of a new version**
1. Add `v2.xql`, plus any overrides under `versions.v2`.
2. Set `ea: v2`.

**Promote to everyone**
- Set `ga: v2` and remove `ea`. Terraform deletes v1 and adds `release:ga` to v2, which keeps `release:ea`.

**Roll back an early release**
- Remove `ea`. Terraform deletes v2.

**Disable without deleting**
- Set `enabled: false` at the top level for all versions, or under `versions.<v>` for one version.

Each change is a `terraform plan` / `terraform apply`. Review the plan to see exactly which rule versions are added, changed or removed.

## Setup

Credentials come from environment variables. The API key type (`standard`) is set in `provider.tf`.

```sh
export CORTEXCLOUD_API_URL="https://api-<tenant-fqdn>"
export CORTEXCLOUD_API_KEY="..."
export CORTEXCLOUD_API_KEY_ID="..."

terraform init
terraform plan
terraform apply
```

With many rules, use `terraform apply -parallelism=5` to avoid API errors from too many concurrent creates.
