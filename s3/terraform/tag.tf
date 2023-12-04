resource "aws_lambda_function" "scanner_tag" {
  filename         = "${path.module}/zip/tag/tag_lambda.zip"
  function_name    = "${var.prefix}-tag-lambda-${random_string.random.id}"
  description      = "Function to tag objects scanned by the scanner lambda"
  role             = aws_iam_role.tag-role.arn
  handler          = "tag_lambda.lambda_handler"
  runtime          = "python3.11"
  timeout          = "120"
  memory_size      = "128"
  architectures    = ["arm64"]
  tags = {
    Name = "${var.prefix}-tag-lambda-${random_string.random.id}" 
  }
}

resource "aws_iam_role" "tag-role" {
  name = "${var.prefix}-tag-role-${random_string.random.id}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "${var.prefix}-tag-role-${random_string.random.id}" 
  }
}

resource "aws_iam_policy" "tag-policy" {
  name        = "${var.prefix}-tag-policy-${random_string.random.id}"
  description = "Policy for the tag lambda"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowTagging",
      "Effect": "Allow",
      "Action": [
        "s3:PutObjectTagging",
        "s3:GetObjectTagging"
      ],
      "Resource": [
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Sid": "AllowSNS",
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": [
        "${aws_sns_topic.sns_topic.arn}"
      ]
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ] 
}
EOF
  tags = {
    Name = "${var.prefix}-tag-policy-${random_string.random.id}" 
  }
}

resource "aws_iam_role_policy_attachment" "tag-policy-attachment" {
  role       = aws_iam_role.tag-role.name
  policy_arn = aws_iam_policy.tag-policy.arn
}

resource "aws_sns_topic_subscription" "tag_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol = "lambda"
  endpoint = aws_lambda_function.scanner_tag.arn
}

resource "aws_lambda_permission" "tag_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner_tag.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}