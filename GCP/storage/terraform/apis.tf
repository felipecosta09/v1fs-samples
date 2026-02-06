resource "google_project_service" "required" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "eventarc.googleapis.com",
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "storage-api.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
