resource "aws_secretsmanager_secret" "tls" {
  name        = "${var.tag}-${random_pet.test.id}-tls-secret"
  description = "contains TLS certs and private keys"
  #   kms_key_id              = var.kms_key_id
  recovery_window_in_days = 0
  tags                    = {Vault = "tls-data"}
}

resource "aws_secretsmanager_secret_version" "tls" {
  secret_id     = aws_secretsmanager_secret.tls.id
  secret_string = local.secret
}
