resource "random_string" "random" {
  length           = 8
  special          = false
  override_special = "/@£$"
}