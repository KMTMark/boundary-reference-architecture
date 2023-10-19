# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Allows anonymous (un-authenticated) users to list and authenticate against any
# auth method, list the global scope, and read and change password on their account ID
# at the global scope
resource "boundary_role" "global_anon_listing" {
  scope_id = boundary_scope.global.id
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "type=scope;actions=list",
    "id={{account.id}};actions=read,change-password"
  ]
  principal_ids = ["u_anon"]
}

# Allows anonymous (un-authenticated) users to list and authenticate against any
# auth method, list the global scope, and read and change password on their account ID
# at the org level scope
resource "boundary_role" "org_anon_listing" {
  scope_id = boundary_scope.org.id
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "type=scope;actions=list",
    "id={{account.id}};actions=read,change-password"
  ]
  principal_ids = ["u_anon"]
}

# Allows anonymous (un-authenticated) users to list and authenticate against any
# auth method, list the global scope, and read and change password on their account ID
# at the org level scope
resource "boundary_role" "kmt_org_anon_listing" {
  scope_id    = boundary_scope.kmt_org.id
  name        = "List KMT Org for login"
  description = "Show org on login page"
  grant_strings = [
    "id=*;type=auth-method;actions=list,authenticate",
    "type=scope;actions=list",
    "id={{account.id}};actions=read,change-password"
  ]
  principal_ids = ["u_anon"]
}

# Creates a role in the global scope that's granting administrative access to 
# resources in the org scope for all backend users
resource "boundary_role" "org_admin" {
  scope_id       = boundary_scope.global.id
  grant_scope_id = boundary_scope.org.id
  grant_strings = [
    "id=*;type=*;actions=*"
  ]
  principal_ids = concat(
    [for user in boundary_user.backend : user.id],
    [for user in boundary_user.frontend : user.id],
  )
}

# Adds a read-only role in the global scope granting read-only access
# to all resources within the org scope and adds principals from the 
# leadership team to the role
resource "boundary_role" "org_readonly" {
  name        = "readonly"
  description = "Read-only role"
  principal_ids = [
    boundary_group.leadership.id
  ]
  grant_strings = [
    "id=*;type=*;actions=read"
  ]
  scope_id       = boundary_scope.global.id
  grant_scope_id = boundary_scope.org.id
}

# Adds an org-level role granting administrative permissions within the core_infra project
resource "boundary_role" "project_admin" {
  name           = "core_infra_admin"
  description    = "Administrator role for core infra"
  scope_id       = boundary_scope.org.id
  grant_scope_id = boundary_scope.core_infra.id
  grant_strings = [
    "id=*;type=*;actions=*"
  ]
  principal_ids = concat(
    [for user in boundary_user.backend : user.id],
    [for user in boundary_user.frontend : user.id],
  )
}

resource "boundary_role" "default_grants" {
  description    = "Role created to provide default grants to users of scope at its creation time"
  grant_scope_id = boundary_scope.kmt_project.id
  grant_strings = [
    "id=*;type=session;actions=list,read:self,cancel:self",
    "type=target;actions=list"
  ]
  name = "Default org Grants"
  principal_ids = [
    boundary_managed_group.oidc_group_default.id
  ]
  scope_id = boundary_scope.kmt_org.id
}

resource "boundary_role" "kmt_proj_admin" {
  description    = "Role created for administration of KMT - Local Dev Test project0"
  grant_scope_id = boundary_scope.kmt_project.id
  grant_strings = [
    "id=*;type=*;actions=*",
  ]
  name = "Administration"
  principal_ids = [
    boundary_managed_group.oidc_group_systems.id
  ]
  scope_id = boundary_scope.kmt_project.id
}

resource "boundary_role" "kmt_org_admin" {
  description    = "Role created for administration of KMT Org unit"
  grant_scope_id = boundary_scope.kmt_org.id
  grant_strings = [
    "id=*;type=*;actions=*",
  ]
  name = "Administration"
  principal_ids = [
    boundary_managed_group.oidc_group_systems.id
  ]
  scope_id = boundary_scope.kmt_org.id
}

## OIDC Groups and Roles

# Default Group and Role

resource "boundary_managed_group" "oidc_group_default" {
  name           = "KMT-OneLogin"
  description    = "OIDC managed group for OneLogin"
  auth_method_id = boundary_auth_method_oidc.onelogin.id
  filter         = "\"kheironmed\" in \"/userinfo/email\""
}

resource "boundary_role" "oidc_role_default" {
  name          = "List and Read"
  description   = "List and read role"
  principal_ids = [boundary_managed_group.oidc_group_default.id]
  grant_strings = ["id=*;type=role;actions=list,read"]
  scope_id      = boundary_scope.kmt_org.id
}

# Systems Group and Role

resource "boundary_managed_group" "oidc_group_systems" {
  name           = "Systems Team"
  description    = "OIDC managed group for Systems team"
  auth_method_id = boundary_auth_method_oidc.onelogin.id
  filter         = "\";Systems;\" in \"/userinfo/groups\""
}

resource "boundary_role" "oidc_role_systems" {
  name          = "Systems Scope Admin"
  description   = "Systems Admin role - Scope"
  principal_ids = [boundary_managed_group.oidc_group_systems.id]
  grant_strings = ["id=*;type=*;actions=*"]
  scope_id      = boundary_scope.kmt_org.id
}

resource "boundary_role" "oidc_project_role_systems" {
  name          = "Systems Project Admin"
  description   = "Systems Admin role - Project"
  principal_ids = [boundary_managed_group.oidc_group_systems.id]
  grant_strings = ["id=*;type=*;actions=*"]
  scope_id      = boundary_scope.kmt_project.id
}
