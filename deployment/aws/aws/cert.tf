# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

data "aws_route53_zone" "primary" {
  name         = "syslab.kmed.co"
  private_zone = false
}

resource "aws_route53_zone" "base_domain" {
  name = "boundary-poc.syslab.kmed.co" # TODO put your own DNS in here!
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
  validity_period_hours = 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_route53_record" "nlb" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "boundary-poc"
  type    = "A"

  alias {
    name                   = aws_lb.controller.dns_name
    zone_id                = aws_lb.controller.zone_id
    evaluate_target_health = true
  }
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
resource "aws_acm_certificate" "le_certificate" {
  certificate_body  = acme_certificate.certificate.certificate_pem
  private_key       = tls_private_key.cert_private_key.private_key_pem
  certificate_chain = acme_certificate.certificate.issuer_pem

  tags = {
    Name = "${var.tag}-LE-Cert"
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
  dns_names       = [aws_route53_zone.base_domain.name]

  subject {
    common_name = aws_route53_zone.base_domain.name
  }
}

resource "acme_certificate" "certificate" {
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

