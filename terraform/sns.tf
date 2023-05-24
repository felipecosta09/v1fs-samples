resource "aws_sns_topic" "sns_topic" {
  name = "topic-${random_string.random.id}"
}