# Importing the KMS key
data "aws_kms_key" "scanner_kms_key_bucket" {
  count = var.kms_key_bucket != null ? 1 : 0
  key_id = var.kms_key_bucket
}

resource "aws_iam_policy" "scanner-kms-policy" {
  name        = "${var.prefix}-kmspolicy-${random_string.random.id}"
  description = "Policy for scanner to access the resources using a kms key"
  count = var.kms_key_bucket != null ? 1 : 0
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"

      ],
      "Effect": "Allow",
      "Resource": [
        "${var.kms_key_bucket}"
      ]
    }
  ]
}
EOF
  tags = {
    Name = "${var.prefix}-kms-policy-${random_string.random.id}" 
  }
}

resource "aws_iam_role_policy_attachment" "scanner_lambda_kmspolicy_attachment" {
  count      = var.kms_key_bucket != null ? 1 : 0
  role       = aws_iam_role.scanner-role.name
  policy_arn = aws_iam_policy.scanner-kms-policy[0].arn
}