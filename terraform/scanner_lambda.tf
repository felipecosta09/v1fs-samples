
resource "aws_lambda_function" "scanner" {
  depends_on = [ data.archive_file.scanner_lambda_zip, aws_lambda_layer_version.amaas-layer ]
  filename         = "${path.module}/zip/scanner/lambda.zip"
  function_name    = "scanner-${random_string.random.id}"
  description      = "Scanner to scan the bucket using the AMaaS"
  role             = "${aws_iam_role.scanner-role.arn}"
  handler          = "scanner_lambda.lambda_handler"
  runtime          = "python3.9"
  timeout          = "300"
  memory_size      = "512"
  architectures    = ["x86_64"]
  layers = [ aws_lambda_layer_version.amaas-layer.arn ]
  ephemeral_storage {
    size = 2048 # Min 512 MB and the Max 10240 MB
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
    Name = "scanner_lambda" 
  }
}

resource "aws_lambda_layer_version" "amaas-layer" {
  filename   = "${path.module}/lambda/scanner/layer/amaas_layer.zip"
  layer_name = "amaas-layer-${random_string.random.id}"
  compatible_architectures = [ "x86_64" ]
  compatible_runtimes = [ "python3.9" ]
}

resource "aws_iam_role" "scanner-role" {
  name = "scanner-role-${random_string.random.id}"
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
}

resource "aws_iam_policy" "scanner-policy" {
  name        = "scanner-policy-s3-${random_string.random.id}"
  description = "Policy for scanner to access the bucket"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject",
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
        "${aws_sqs_queue.scanner_queue.arn}"
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
}


resource "aws_iam_role_policy_attachment" "scanner-policy-exec" {
  role       = "${aws_iam_role.scanner-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_policy_attachment" {
  role       = "${aws_iam_role.scanner-role.name}"
  policy_arn = "${aws_iam_policy.scanner-policy.arn}"
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