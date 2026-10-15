dataset = asset_inventory | filter xdm.asset.provider = "aws" | filter xdm.asset.type.id = "EC2_SECURITY_GROUP"
| alter isShared = json_extract_scalar(xdm.asset.raw_fields, "$.Platform Discovery.isShared") | filter isShared = "false"
| alter ipPermissions = json_extract_array(xdm.asset.raw_fields, "$.Platform Discovery.ipPermissions")
| filter ipPermissions != null
| arrayexpand ipPermissions
| alter fromPort = json_extract_scalar(ipPermissions, "$.fromPort"), toPort = json_extract_scalar(ipPermissions, "$.toPort")
| filter (to_integer(fromPort) = 22 or to_integer(toPort) = 22) or (to_integer(fromPort) < 22 and to_integer(toPort) > 22)
| alter ipRanges = json_extract_scalar_array(ipPermissions, "$.ipRanges")
| alter cidrIpv4 = array_any(ipRanges, "@element"="0.0.0.0/0")
| alter ipv6Ranges = json_extract_array(ipPermissions, "$.ipv6Ranges")
| alter cidrIpV6 = array_any(ipv6Ranges, json_extract_scalar("@element", "$.cidrIpv6") = "::/0")
| filter cidrIpv4 = true or cidrIpV6 = true
| fields xdm.asset.id as asset_id, xdm.asset.type.class as class_name, xdm.asset.type.id as asset_type_id, xdm.asset.name as asset_name, xdm.asset.realm as asset_account_id
