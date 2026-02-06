resource "google_pubsub_topic" "scan_results" {
  name    = "${var.prefix}-scan-results-${random_string.suffix.id}"
  project = var.project_id
}
