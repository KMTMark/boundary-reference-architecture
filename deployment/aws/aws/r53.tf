data "aws_route53_zone" "primary" {
  name         = "syslab.kmed.co"
  private_zone = false
}

resource "aws_route53_zone" "boundary_base_domain" {
  name = "boundary-poc.syslab.kmed.co" # TODO put your own DNS in here!
}

resource "aws_route53_record" "boundary_lb" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "boundary-poc"
  type    = "A"

  alias {
    name                   = aws_lb.controller.dns_name
    zone_id                = aws_lb.controller.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_zone" "vault_base_domain" {
  name = "vault-poc.syslab.kmed.co" # TODO put your own DNS in here!
}

resource "aws_route53_record" "vault_lb" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "vault-poc"
  type    = "A"

  alias {
    name                   = aws_lb.vault_lb.dns_name
    zone_id                = aws_lb.vault_lb.zone_id
    evaluate_target_health = true
  }
}
