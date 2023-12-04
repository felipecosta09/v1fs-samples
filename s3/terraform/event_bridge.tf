resource "aws_cloudwatch_event_rule" "event_bridge_rule" {
  name        = "${var.prefix}-eventbridgerule-${random_string.random.id}"
  description = "Event rule for file uploads"
  event_pattern = <<PATTERN
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"]
}
PATTERN
  tags = {
    Name = "${var.prefix}-eventbridge-rule-${random_string.random.id}"
  }
}

resource "aws_cloudwatch_event_target" "event_bridge_target" {
  rule      = aws_cloudwatch_event_rule.event_bridge_rule.name
  target_id = "sqs_target"
  arn = aws_sqs_queue.scanner_queue.arn
}