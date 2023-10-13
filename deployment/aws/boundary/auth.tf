# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_auth_method" "password" {
  name        = "corp_password_auth_method"
  description = "Password auth method for Corp org"
  type        = "password"
  scope_id    = boundary_scope.org.id
}

resource "boundary_auth_method_oidc" "provider" {
  name                 = "OneLogin"
  description          = "OIDC auth method for OneLogin"
  scope_id             = boundary_scope.kmt_org.id
  issuer               = "https://kheironmedical.onelogin.com/oidc/2"
  client_id            = "2e2effb0-350e-013c-1ed2-3ad134cb9f8d38527"
  client_secret        = "db148f048119a6003da48f8b797ba4037cdb55d6adde2cd75e291ad6d51a5aa0"
  signing_algorithms   = ["RS256"]
  api_url_prefix       = "http://localhost:9200"
  is_primary_for_scope = true
  state                = "active-public"
  claims_scopes        = ["groups"]
}
