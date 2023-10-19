# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_auth_method" "password" {
  name        = "corp_password_auth_method"
  description = "Password auth method for Corp org"
  type        = "password"
  scope_id    = boundary_scope.org.id
}

resource "boundary_auth_method_oidc" "onelogin" {
  name                 = "OneLogin"
  description          = "OIDC auth method for OneLogin"
  scope_id             = boundary_scope.kmt_org.id
  issuer               = "https://kheironmedical.onelogin.com/oidc/2"
  client_id            = "2e2effb0-350e-013c-1ed2-3ad134cb9f8d38527"
  client_secret        = "7261b06beaf2bdfc8fc92b0dcabaaa072abef701948edcabf6c3eec528f293a9"
  signing_algorithms   = ["RS256"]
  api_url_prefix       = var.url
  is_primary_for_scope = true
  state                = "active-public"
  claims_scopes        = ["groups"]
}

resource "boundary_auth_method_oidc" "demo_org" {
  api_url_prefix = "https://boundary-poc.syslab.kmed.co"
  # callback_url   = "https://boundary-poc.syslab.kmed.co//v1/auth-methods/oidc:authenticate:callback"
  claims_scopes = [
    "groups",
  ]
  client_id     = "2e2effb0-350e-013c-1ed2-3ad134cb9f8d38527"
  client_secret = "7261b06beaf2bdfc8fc92b0dcabaaa072abef701948edcabf6c3eec528f293a9"
  issuer        = "https://kheironmedical.onelogin.com/oidc/2"
  name          = "OneLogin-Test"
  scope_id      = boundary_scope.org.id
  signing_algorithms = [
    "RS256",
  ]
  state                = "active-public"
  is_primary_for_scope = true
  type                 = "oidc"
}
