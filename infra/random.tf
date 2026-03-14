resource "random_string" "openai_suffix" {
  length  = 6
  upper   = false
  special = false
}
