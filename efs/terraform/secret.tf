# Create a secret for the API key
resource "aws_secretsmanager_secret" "apikey" {
  name = "${var.prefix}-apikey-${random_string.random.id}"
  tags = {
    Name = "${var.prefix}-apikey-${random_string.random.id}"
  }
}

# Store the API key in the secret
resource "aws_secretsmanager_secret_version" "apikey" {
  depends_on = [ aws_secretsmanager_secret.apikey ]
  secret_id     = aws_secretsmanager_secret.apikey.id
  secret_string = var.apikey
}

data "aws_secretsmanager_secret_version" "retrive_secret" {
  depends_on = [ aws_secretsmanager_secret_version.apikey, aws_secretsmanager_secret.apikey ]
  secret_id = aws_secretsmanager_secret.apikey.id
}