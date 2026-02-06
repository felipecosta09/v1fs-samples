# Cloud Monitoring alert for malware detection
resource "google_monitoring_alert_policy" "malware_detected" {
  display_name = "${var.prefix}-malware-detected"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Malware detected in logs"
    condition_matched_log {
      filter = <<-EOT
        resource.type="cloud_function"
        resource.labels.function_name=~"${var.prefix}-scanner-.*"
        jsonPayload.scanning_result.scanResult=1
      EOT
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }

  # Uncomment and add notification channel ID for email/Slack alerts
  # notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content   = "Malware was detected in a file uploaded to a monitored GCS bucket."
    mime_type = "text/markdown"
  }
}

# Optional: Email notification channel
# resource "google_monitoring_notification_channel" "email" {
#   display_name = "V1FS Alerts Email"
#   type         = "email"
#   project      = var.project_id
#   labels = {
#     email_address = "security-team@example.com"
#   }
# }

# Log-based metric for scan results
resource "google_logging_metric" "scan_results" {
  name    = "${var.prefix}-scan-results"
  project = var.project_id
  filter  = <<-EOT
    resource.type="cloud_function"
    resource.labels.function_name=~"${var.prefix}-scanner-.*"
    jsonPayload.scanning_result.scanResult!=""
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "scan_result"
      value_type  = "STRING"
      description = "Scan result: 0=clean, 1=malicious, 2=error"
    }
  }

  label_extractors = {
    "scan_result" = "EXTRACT(jsonPayload.scanning_result.scanResult)"
  }
}

# Alert for scanner function errors
resource "google_monitoring_alert_policy" "scanner_errors" {
  display_name = "${var.prefix}-scanner-errors"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Scanner function errors"
    condition_threshold {
      filter          = "resource.type=\"cloud_function\" AND resource.labels.function_name=monitoring.regex.full_match(\"${var.prefix}-scanner-.*\") AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status!=\"ok\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  # notification_channels = [google_monitoring_notification_channel.email.id]
}
