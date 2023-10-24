# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "le_private_key" {
  algorithm = "RSA"
}

resource "tls_private_key" "boundary" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "boundary" {
  private_key_pem = tls_private_key.boundary.private_key_pem

  subject {
    common_name  = "boundary.dev"
    organization = "Boundary, dev."
  }
  dns_names = [
    aws_lb.controller.dns_name
  ]
  validity_period_hours = 720

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# resource "acme_registration" "registration" {
#   account_key_pem = tls_private_key.le_private_key.private_key_pem
#   email_address   = "systems@kheironmed.com" # TODO put your own email in here!
# }

# resource "acme_certificate" "certificate" {
#   account_key_pem = acme_registration.registration.account_key_pem
#   common_name     = aws_route53_zone.base_domain.name
#   # disable_complete_propagation = true
#   subject_alternative_names = [
#     "*.${aws_route53_zone.base_domain.name}",
#     "${aws_lb.controller.dns_name}"
#   ]

#   dns_challenge {
#     provider = "route53"

#     config = {
#       AWS_HOSTED_ZONE_ID = data.aws_route53_zone.primary.zone_id
#     }
#   }

#   depends_on = [acme_registration.registration]
# }

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.boundary.private_key_pem
  certificate_body = tls_self_signed_cert.boundary.cert_pem

  tags = {
    Name = "${var.tag}-${random_pet.test.id}"
  }
}

resource "aws_acm_certificate" "boundary_le_certificate" {
  certificate_body  = acme_certificate.boundary_certificate.certificate_pem
  private_key       = tls_private_key.cert_private_key.private_key_pem
  certificate_chain = acme_certificate.boundary_certificate.issuer_pem

  tags = {
    Name = "${var.tag}-boundary-LE-Cert"
  }
}

resource "tls_private_key" "reg_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_private_key.private_key_pem
  email_address   = "systems@kheironmed.com"
}

resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "req" {
  # key_algorithm   = "RSA"
  private_key_pem = tls_private_key.cert_private_key.private_key_pem
  dns_names       = [aws_route53_zone.boundary_base_domain.name]

  subject {
    common_name = aws_route53_zone.boundary_base_domain.name
  }
}

resource "acme_certificate" "boundary_certificate" {
  account_key_pem         = acme_registration.reg.account_key_pem
  certificate_request_pem = tls_cert_request.req.cert_request_pem
  # common_name               = aws_route53_zone.base_domain.name
  # subject_alternative_names = [aws_lb.controller.dns_name]

  dns_challenge {
    provider = "route53"
    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.primary.zone_id
    }
  }

  depends_on = [acme_registration.reg]
}

## Vault Certs

/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

# Generate a private key so you can create a CA cert with it.
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a CA cert with the private key you just generated.
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name = "ca.vault.server.com"
  }

  validity_period_hours = 720 # 30 days

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]

  is_ca_certificate = true

  #  provisioner "local-exec" {
  #    command = "echo '${tls_self_signed_cert.ca.cert_pem}' > ./vault-ca.pem"
  #  }
}

# Generate another private key. This one will be used
# To create the certs on your Vault nodes
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048

  #  provisioner "local-exec" {
  #    command = "echo '${tls_private_key.server.private_key_pem}' > ./vault-key.pem"
  #  }
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name = "vault.server.com"
  }

  dns_names = [
    var.shared_san,
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem   = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 720 # 30 days

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]

  #  provisioner "local-exec" {
  #    command = "echo '${tls_locally_signed_cert.server.cert_pem}' > ./vault-crt.pem"
  #  }
}

locals {
  tls_data = {
    # vault_ca   = base64encode(aws_acmpca_certificate.vault.certificate_pem)
    vault_cert = base64encode(acme_certificate.vault_certificate.issuer_pem)
    vault_pk   = base64encode(tls_private_key.cert_private_key.private_key_pem)
  }
}

locals {
  secret = jsonencode(local.tls_data)
}

## Vault Lets Encrypt Cert

resource "aws_acm_certificate" "vault_le_certificate" {
  certificate_body  = acme_certificate.vault_certificate.certificate_pem
  private_key       = tls_private_key.cert_private_key.private_key_pem
  certificate_chain = acme_certificate.vault_certificate.issuer_pem

  tags = {
    Name = "${var.tag}-vault-LE-Cert"
  }
}

resource "tls_cert_request" "vault_req" {
  # key_algorithm   = "RSA"
  private_key_pem = tls_private_key.cert_private_key.private_key_pem
  dns_names       = [aws_route53_zone.vault_base_domain.name]

  subject {
    common_name = aws_route53_zone.vault_base_domain.name
  }
}

resource "acme_certificate" "vault_certificate" {
  account_key_pem         = acme_registration.reg.account_key_pem
  certificate_request_pem = tls_cert_request.vault_req.cert_request_pem
  # common_name               = aws_route53_zone.base_domain.name
  # subject_alternative_names = [aws_lb.controller.dns_name]

  dns_challenge {
    provider = "route53"
    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.primary.zone_id
    }
  }

  depends_on = [acme_registration.reg]
}
