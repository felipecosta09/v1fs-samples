# Zip the scanner lambda function
data "archive_file" "scanner_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/zip/scanner/lambda.zip"
  source_dir  = "${path.module}/lambda/scanner/src"
}

# Zip the tag lambda function
data "archive_file" "tag_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/zip/tag/tag_lambda.zip"
  source_dir  = "${path.module}/lambda/tag/src"
}