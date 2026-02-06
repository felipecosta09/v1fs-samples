data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

# GCS service account must be able to publish to Eventarc (Pub/Sub) for storage triggers
resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project    = var.project_id
  role       = "roles/pubsub.publisher"
  member     = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
  depends_on = [google_project_service.required]
}

resource "google_service_account" "scanner" {
  account_id   = "${var.prefix}-scanner-${random_string.suffix.id}"
  display_name = "V1FS Scanner Cloud Function"
  project      = var.project_id
}

resource "google_project_iam_member" "scanner_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scanner.email}"
}

resource "google_project_iam_member" "scanner_eventarc_receiver" {
  project    = var.project_id
  role       = "roles/eventarc.eventReceiver"
  member     = "serviceAccount:${google_service_account.scanner.email}"
  depends_on = [google_project_iam_member.scanner_run_invoker]
}

resource "google_project_iam_member" "scanner_artifactregistry_reader" {
  project    = var.project_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.scanner.email}"
  depends_on = [google_project_iam_member.scanner_eventarc_receiver]
}

# Grant read access to ALL monitored buckets
resource "google_storage_bucket_iam_member" "scanner_read_objects" {
  for_each = toset(var.gcs_bucket_names)
  bucket   = each.value
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.scanner.email}"
}

resource "google_pubsub_topic_iam_member" "scanner_publish" {
  topic  = google_pubsub_topic.scan_results.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.scanner.email}"
}

resource "google_secret_manager_secret_iam_member" "scanner_apikey" {
  secret_id = google_secret_manager_secret.v1fs_apikey.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scanner.email}"
}

resource "google_project_iam_member" "scanner_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.scanner.email}"
}

# Cloud Function (Gen 2) - no inline trigger, triggers created separately
resource "google_cloudfunctions2_function" "scanner" {
  name        = "${var.prefix}-scanner-${random_string.suffix.id}"
  location    = var.region
  description = "V1FS scanner: scans new GCS objects and publishes results to Pub/Sub"
  project     = var.project_id

  build_config {
    runtime     = "python312"
    entry_point = "scanner"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.scanner_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = google_service_account.scanner.email
    environment_variables = {
      V1FS_REGION  = var.v1fs_region
      PUBSUB_TOPIC = google_pubsub_topic.scan_results.id
      SDK_TAGS     = join(",", var.sdk_tags)
    }
    secret_environment_variables {
      key        = "V1FS_APIKEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.v1fs_apikey.secret_id
      version    = "latest"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
  }

  depends_on = [
    google_project_iam_member.scanner_artifactregistry_reader,
    google_secret_manager_secret_version.v1fs_apikey,
    google_storage_bucket_iam_member.scanner_read_objects,
  ]
}

# Create an Eventarc trigger for EACH bucket
resource "google_eventarc_trigger" "scanner_bucket_trigger" {
  for_each = toset(var.gcs_bucket_names)

  name     = "${var.prefix}-scanner-${replace(each.value, "_", "-")}-${random_string.suffix.id}"
  location = var.region
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = each.value
  }

  destination {
    cloud_run_service {
      service = google_cloudfunctions2_function.scanner.name
      region  = var.region
    }
  }

  service_account = google_service_account.scanner.email

  depends_on = [
    google_cloudfunctions2_function.scanner,
    google_project_iam_member.gcs_pubsub_publisher,
    google_project_iam_member.scanner_eventarc_receiver,
  ]
}
