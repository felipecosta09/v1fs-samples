resource "aws_cloudwatch_event_rule" "schedule" {
  count               = var.schadule_scan ? 1 : 0
  name                = "${var.prefix}-schedule-${random_string.random.id}"
  description         = "Schedule for the scan"
  schedule_expression = var.scan_frequency
}

resource "aws_cloudwatch_event_target" "run_scheduled_lambda_on_schedule" {
  count     = var.schadule_scan ? 1 : 0
  rule      = aws_cloudwatch_event_rule.schedule[0].name
  target_id = "${var.prefix}-lambda-schedule"
  arn       = aws_lambda_function.scanner.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_scheduled_lambda" {
  count         = var.schadule_scan ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}
