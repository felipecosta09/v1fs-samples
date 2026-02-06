resource "aws_sqs_queue" "scanner_queue" {
  name = "${var.prefix}-queue-${random_string.random.id}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 3600
  visibility_timeout_seconds = 720
  tags = {
    Name = "${var.prefix}-queue-${random_string.random.id}"
  }
  redrive_policy            = jsonencode({
    deadLetterTargetArn    = aws_sqs_queue.scanner_dlq.arn
    maxReceiveCount        = 3
  })
}

resource "aws_sqs_queue" "scanner_dlq" {
  name                      = "${var.prefix}-dlq-${random_string.random.id}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 3600
  visibility_timeout_seconds = 720
  tags = {
    Name = "${var.prefix}-dlq-${random_string.random.id}"
  }
}

resource "aws_sqs_queue_policy" "scanner_queue_policy" {
  queue_url = aws_sqs_queue.scanner_queue.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "sqs_policy",
  "Statement": [
    {
      "Sid": "sqs_policy",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.scanner_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_cloudwatch_event_rule.event_bridge_rule.arn}"
        }
      }
    }
  ]
}
EOF
}