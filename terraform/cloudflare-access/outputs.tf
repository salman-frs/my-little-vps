output "openclaw_access_application_id" {
  value       = cloudflare_zero_trust_access_application.openclaw.id
  description = "Cloudflare Access application ID for the OpenClaw portal."
}

output "openclaw_access_policy_id" {
  value       = cloudflare_zero_trust_access_policy.openclaw_allow_email.id
  description = "Cloudflare Access allow policy ID for the OpenClaw portal."
}

output "cloudflare_zero_trust_team_domain" {
  value       = local.zero_trust_team_domain
  description = "Zero Trust team domain used for the Access login flow."
}

output "one_time_pin_identity_provider_id" {
  value       = local.one_time_pin_idp_id
  description = "Account-level One-Time PIN identity provider used by the OpenClaw Access app."
}

output "openclaw_hostname" {
  value       = var.openclaw_hostname
  description = "Protected public hostname for the OpenClaw portal."
}

output "openclaw_origin_ca_certificate_path" {
  value       = local.openclaw_origin_ca_certificate_path
  description = "Local path to the generated OpenClaw Origin CA certificate PEM."
}

output "openclaw_origin_ca_private_key_path" {
  value       = local.openclaw_origin_ca_private_key_path
  description = "Local path to the generated OpenClaw Origin CA private key PEM."
}

output "openclaw_origin_ca_expires_on" {
  value       = cloudflare_origin_ca_certificate.openclaw.expires_on
  description = "Expiration timestamp for the OpenClaw Origin CA certificate."
}
