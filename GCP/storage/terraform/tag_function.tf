resource "google_service_account" "tag" {
  count        = var.enable_tag ? 1 : 0
  account_id   = "${var.prefix}-tag-${random_string.suffix.id}"
  display_name = "V1FS Tag Cloud Function"
  project      = var.project_id
}

resource "google_project_iam_member" "tag_run_invoker" {
  count   = var.enable_tag ? 1 : 0
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.tag[0].email}"
}

resource "google_project_iam_member" "tag_eventarc_receiver" {
  count      = var.enable_tag ? 1 : 0
  project    = var.project_id
  role       = "roles/eventarc.eventReceiver"
  member     = "serviceAccount:${google_service_account.tag[0].email}"
  depends_on = [google_project_iam_member.tag_run_invoker]
}

resource "google_project_iam_member" "tag_artifactregistry_reader" {
  count      = var.enable_tag ? 1 : 0
  project    = var.project_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.tag[0].email}"
  depends_on = [google_project_iam_member.tag_eventarc_receiver]
}

# Grant write access to ALL monitored buckets for tagging
resource "google_storage_bucket_iam_member" "tag_object_admin" {
  for_each = var.enable_tag ? toset(var.gcs_bucket_names) : toset([])
  bucket   = each.value
  role     = "roles/storage.objectUser"
  member   = "serviceAccount:${google_service_account.tag[0].email}"
}

# Grant write access to quarantine bucket (if specified)
resource "google_storage_bucket_iam_member" "tag_quarantine_write" {
  count  = var.enable_tag && var.quarantine_bucket != "" ? 1 : 0
  bucket = var.quarantine_bucket
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.tag[0].email}"
}

resource "google_project_iam_member" "tag_log_writer" {
  count   = var.enable_tag ? 1 : 0
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.tag[0].email}"
}

resource "google_cloudfunctions2_function" "tag" {
  count        = var.enable_tag ? 1 : 0
  name         = "${var.prefix}-tag-${random_string.suffix.id}"
  location     = var.region
  description  = "V1FS tag: applies scan result metadata to GCS objects"
  project      = var.project_id

  build_config {
    runtime     = "python312"
    entry_point = "tag"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.tag_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.tag[0].email
    environment_variables = {
      QUARANTINE_BUCKET = var.quarantine_bucket
      DELETE_MALICIOUS  = tostring(var.delete_malicious)
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
  }

  event_trigger {
    trigger_region     = var.region
    event_type         = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic       = google_pubsub_topic.scan_results.id
    retry_policy       = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.tag[0].email
  }

  depends_on = [
    google_project_iam_member.tag_artifactregistry_reader,
    google_storage_bucket_iam_member.tag_object_admin,
  ]
}
