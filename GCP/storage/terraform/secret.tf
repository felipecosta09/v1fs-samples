resource "google_secret_manager_secret" "v1fs_apikey" {
  secret_id = "${var.prefix}-apikey-${random_string.suffix.id}"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "v1fs_apikey" {
  secret      = google_secret_manager_secret.v1fs_apikey.id
  secret_data = var.v1fs_apikey
}
