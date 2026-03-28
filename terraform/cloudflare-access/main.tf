locals {
  zero_trust_team_domain = "${var.cloudflare_zero_trust_team_name}.cloudflareaccess.com"
  one_time_pin_idp_id = (
    trimspace(var.existing_one_time_pin_idp_id) != ""
    ? trimspace(var.existing_one_time_pin_idp_id)
    : cloudflare_zero_trust_access_identity_provider.one_time_pin[0].id
  )
  openclaw_origin_ca_certificate_path = "${path.module}/${var.openclaw_origin_ca_certificate_filename}"
  openclaw_origin_ca_private_key_path = "${path.module}/${var.openclaw_origin_ca_private_key_filename}"
}

resource "cloudflare_zero_trust_access_identity_provider" "one_time_pin" {
  count      = trimspace(var.existing_one_time_pin_idp_id) == "" ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "One-time PIN login"
  type       = "onetimepin"
  config     = {}
}

resource "cloudflare_zero_trust_access_policy" "openclaw_allow_email" {
  account_id = var.cloudflare_account_id
  name       = "Allow ${var.openclaw_access_app_name} admin email"
  decision   = "allow"

  include = [
    {
      email = {
        email = var.openclaw_access_email
      }
    }
  ]

  require = [
    {
      login_method = {
        id = local.one_time_pin_idp_id
      }
    }
  ]
}

resource "cloudflare_zero_trust_access_application" "openclaw" {
  account_id           = var.cloudflare_account_id
  name                 = var.openclaw_access_app_name
  domain               = var.openclaw_hostname
  type                 = "self_hosted"
  session_duration     = var.openclaw_access_session_duration
  app_launcher_visible = false
  allowed_idps         = [local.one_time_pin_idp_id]

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.openclaw_allow_email.id
      precedence = 1
    }
  ]
}

resource "tls_private_key" "openclaw_origin_ca" {
  algorithm   = var.openclaw_origin_ca_request_type == "origin-rsa" ? "RSA" : "ECDSA"
  rsa_bits    = var.openclaw_origin_ca_request_type == "origin-rsa" ? 2048 : null
  ecdsa_curve = var.openclaw_origin_ca_request_type == "origin-ecc" ? "P256" : null
}

resource "tls_cert_request" "openclaw_origin_ca" {
  private_key_pem = tls_private_key.openclaw_origin_ca.private_key_pem

  subject {
    common_name = var.openclaw_hostname
  }

  dns_names = [var.openclaw_hostname]
}

resource "cloudflare_origin_ca_certificate" "openclaw" {
  csr                = tls_cert_request.openclaw_origin_ca.cert_request_pem
  hostnames          = [var.openclaw_hostname]
  request_type       = var.openclaw_origin_ca_request_type
  requested_validity = var.openclaw_origin_ca_requested_validity
}

resource "local_sensitive_file" "openclaw_origin_ca_certificate" {
  filename = local.openclaw_origin_ca_certificate_path
  content  = cloudflare_origin_ca_certificate.openclaw.certificate
}

resource "local_sensitive_file" "openclaw_origin_ca_private_key" {
  filename = local.openclaw_origin_ca_private_key_path
  content  = tls_private_key.openclaw_origin_ca.private_key_pem
}

resource "cloudflare_dns_record" "openclaw" {
  count   = var.manage_openclaw_dns_record ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = var.openclaw_hostname
  type    = "A"
  content = var.openclaw_origin_ip
  proxied = true
  ttl     = 1
}
