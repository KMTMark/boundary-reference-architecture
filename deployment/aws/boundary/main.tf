# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.9"
    }
  }
}

provider "boundary" {
  addr             = var.url
  recovery_kms_hcl = <<EOT
kms "awskms" {
	purpose    = "recovery"
        kms_key_id = "${var.kms_recovery_key_id}"
  region     = "eu-west-1"      
}
EOT
}
