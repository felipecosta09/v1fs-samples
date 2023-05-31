
resource "aws_lambda_function" "scanner" {
  depends_on = [ data.archive_file.scanner_lambda_zip, aws_lambda_layer_version.amaas-layer ]
  filename         = "${path.module}/zip/scanner/lambda.zip"
  function_name    = "${var.prefix}-${random_string.random.id}"
  description      = "Function to scan the bucket using the AMaaS"
  role             = "${aws_iam_role.scanner-role.arn}"
  handler          = "scanner_lambda.lambda_handler"
  runtime          = "python3.9"
  timeout          = "300"
  memory_size      = "512"
  architectures    = ["x86_64"]
  dynamic "vpc_config" {
    for_each = var.vpc != null ? [1] : []
    content {
      subnet_ids         = var.vpc.subnet_ids
      security_group_ids = var.vpc.security_group_ids
    }
  }
  layers = [ aws_lambda_layer_version.amaas-layer.arn ]
  ephemeral_storage {
    size = 512
  }
  environment {
    variables = {
      cloudone_region = var.cloudone_region
      topic_arn = aws_sns_topic.sns_topic.arn
      secret_name = aws_secretsmanager_secret.apikey.name
      queue_url = aws_sqs_queue.scanner_queue.url
    }
  }
  tags = {
    Name = "${var.prefix}-lambda" 
  }
}

resource "aws_lambda_layer_version" "amaas-layer" {
  filename   = "${path.module}/lambda/scanner/layer/amaas_layer.zip"
  layer_name = "${var.prefix}-layer-${random_string.random.id}"
  compatible_architectures = [ "x86_64" ]
  compatible_runtimes = [ "python3.9" ]
}

resource "aws_iam_role" "scanner-role" {
  name = "${var.prefix}-role-${random_string.random.id}"
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
    Name = "${var.prefix}-role" 
  }
}

resource "aws_iam_policy" "scanner-policy" {
  name        = "${var.prefix}-policy-${random_string.random.id}"
  description = "Policy for scanner to access the resources"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListObjects"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::*/*",
        "arn:aws:s3:::*"
      ]
    },
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_sqs_queue.scanner_queue.arn}",
        "${aws_sqs_queue.scanner_dlq.arn}"
      ]
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_sns_topic.sns_topic.arn}"
      ]
    },
    {
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_secretsmanager_secret.apikey.arn}"
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
    Name = "${var.prefix}-policy" 
  }
}


resource "aws_iam_role_policy_attachment" "scanner-policy-exec" {
  role       = "${aws_iam_role.scanner-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_policy_attachment" {
  role       = "${aws_iam_role.scanner-role.name}"
  policy_arn = "${aws_iam_policy.scanner-policy.arn}"
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_vpc_policy_attachment" {
  count     = var.vpc != null ? 1 : 0
  role       = "${aws_iam_role.scanner-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_permission" "sns_publish_permission" {
  statement_id  = "AllowSNSPublish"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}

resource "aws_lambda_event_source_mapping" "connect_sqs" {
  event_source_arn = aws_sqs_queue.scanner_queue.arn
  function_name    = aws_lambda_function.scanner.arn
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "connect_dlq" {
  event_source_arn = aws_sqs_queue.scanner_dlq.arn
  function_name    = aws_lambda_function.scanner.arn
  enabled          = true
}