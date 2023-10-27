# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.10"
    }    
  }
}

module "aws" {
  source            = "./aws"
  boundary_bin      = var.boundary_bin
  pub_ssh_key_path  = var.pub_ssh_key_path
  priv_ssh_key_path = var.priv_ssh_key_path
}

module "boundary" {
  source              = "./boundary"
  url                 = "https://boundary-poc.syslab.kmed.co"
  target_ips          = module.aws.target_ips
  kms_recovery_key_id = module.aws.kms_recovery_key_id
  aws_lb_dns_name     = module.aws.boundary_lb
}

