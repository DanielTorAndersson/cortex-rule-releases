terraform {
  required_providers {
    cortexcloud = {
      source  = "paloaltonetworks/cortexcloud"
      version = "1.0.13"
    }
  }
}

# Credentials are read from the environment:
#   CORTEXCLOUD_API_URL, CORTEXCLOUD_API_KEY, CORTEXCLOUD_API_KEY_ID
provider "cortexcloud" {
  api_key_type = "standard" # Possible values are "standard" or "advanced". Defaults to "advanced".
}
