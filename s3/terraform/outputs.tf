output "lambda_arn" {
  value = aws_lambda_function.scanner.arn
}

output "sqs_arn" {
  value = aws_sqs_queue.scanner_queue.arn
}

output "sns_arn" {
  value = aws_sns_topic.sns_topic.arn
}

output "event_bridge_rule_arn" {
  value = aws_cloudwatch_event_rule.event_bridge_rule.arn
}

output "secret_arn" {
  value = aws_secretsmanager_secret.apikey.arn
}
