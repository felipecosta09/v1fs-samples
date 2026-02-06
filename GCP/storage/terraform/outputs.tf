output "scanner_function_name" {
  description = "Name of the scanner Cloud Function"
  value       = google_cloudfunctions2_function.scanner.name
}

output "scanner_function_url" {
  description = "URL of the scanner Cloud Function"
  value       = google_cloudfunctions2_function.scanner.service_config[0].uri
}

output "tag_function_name" {
  description = "Name of the tag Cloud Function"
  value       = var.enable_tag ? google_cloudfunctions2_function.tag[0].name : null
}

output "pubsub_topic" {
  description = "Pub/Sub topic for scan results"
  value       = google_pubsub_topic.scan_results.name
}

output "pubsub_topic_id" {
  description = "Full ID of the Pub/Sub topic"
  value       = google_pubsub_topic.scan_results.id
}

output "secret_name" {
  description = "Name of the Secret Manager secret storing the API key"
  value       = google_secret_manager_secret.v1fs_apikey.secret_id
}

output "scanner_service_account" {
  description = "Service account email for the scanner function"
  value       = google_service_account.scanner.email
}

output "monitored_buckets" {
  description = "GCS buckets being monitored for new objects"
  value       = var.gcs_bucket_names
}

output "eventarc_triggers" {
  description = "Eventarc trigger names for each bucket"
  value       = [for t in google_eventarc_trigger.scanner_bucket_trigger : t.name]
}
