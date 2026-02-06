data "archive_file" "scanner_zip" {
  type        = "zip"
  output_path = "${path.module}/build/scanner.zip"
  source_dir  = "${path.module}/../functions/scanner"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache"]
}

data "archive_file" "tag_zip" {
  type        = "zip"
  output_path = "${path.module}/build/tag.zip"
  source_dir  = "${path.module}/../functions/tag"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache"]
}

resource "google_storage_bucket" "function_source" {
  name                        = "${var.prefix}-fn-source-${random_string.suffix.id}"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access  = true
  force_destroy               = true
  depends_on                  = [google_project_service.required]
}

resource "google_storage_bucket_object" "scanner_zip" {
  name   = "scanner-${data.archive_file.scanner_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.scanner_zip.output_path
}

resource "google_storage_bucket_object" "tag_zip" {
  name   = "tag-${data.archive_file.tag_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.tag_zip.output_path
}
