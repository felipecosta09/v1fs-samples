resource "aws_lambda_function" "scanner" {
  depends_on = [ data.archive_file.scanner_lambda_zip, aws_lambda_layer_version.amaas-layer ]
  filename         = "${path.module}/zip/scanner/lambda.zip"
  function_name    = "${var.prefix}-${random_string.random.id}"
  description      = "Function to scan the EFS files using the AMaaS"
  role             = aws_iam_role.scanner-role.arn
  handler          = "scanner_lambda.lambda_handler"
  runtime          = "python3.11"
  timeout          = "40"
  memory_size      = "512"
  architectures    = ["arm64"]
  layers = [ aws_lambda_layer_version.amaas-layer.arn ]
  file_system_config {
    local_mount_path = "/mnt/efs"
    arn              = data.aws_efs_access_point.efs-access-point.arn
  }
  vpc_config {
    subnet_ids = [ var.subnet ]
    security_group_ids = [ var.security_group ]
  }
  environment {
    variables = {
      topic_arn = aws_sns_topic.sns_topic.arn
      v1_region = var.v1_region
      secret_name = aws_secretsmanager_secret.apikey.name
    }
  }
  tags = {
    Name = "${var.prefix}-lambda-${random_string.random.id}" 
  }
}

resource "aws_lambda_layer_version" "amaas-layer" {
  filename   = "${path.module}/lambda/scanner/layer/v1fs-python311-arm64.zip"
  layer_name = "${var.prefix}-layer-${random_string.random.id}"
  compatible_architectures = [ "arm64" ]
  compatible_runtimes = [ "python3.11" ]
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
    Name = "${var.prefix}-role-${random_string.random.id}" 
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
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Effect": "Allow",
      "Resource": [
        "${data.aws_efs_file_system.efs.arn}"
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
        "sns:Publish"
      ],
      "Effect": "Allow",
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
    Name = "${var.prefix}-policy-${random_string.random.id}" 
  }
}


resource "aws_iam_role_policy_attachment" "scanner-policy-exec" {
  role       = aws_iam_role.scanner-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_vpc_policy_attachment" {
  role       = aws_iam_role.scanner-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_policy_attachment" {
  role       = aws_iam_role.scanner-role.name
  policy_arn = aws_iam_policy.scanner-policy.arn
}

resource "aws_lambda_permission" "sns_publish_permission" {
  statement_id  = "AllowSNSPublish"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scanner.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}