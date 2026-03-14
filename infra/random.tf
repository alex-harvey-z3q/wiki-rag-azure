resource "random_string" "openai_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "storage_suffix" {
  length  = 10
  upper   = false
  special = false
}

resource "random_string" "acr_suffix" {
  length  = 8
  upper   = false
  special = false
}
