variable "cloudflare_api_token" {
  description = "API token with Zero Trust, DNS, and SSL/Certificates edit permissions."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for the Zero Trust organization."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID that serves the OpenClaw hostname."
  type        = string
}

variable "cloudflare_zero_trust_team_name" {
  description = "Existing Zero Trust team name, without the .cloudflareaccess.com suffix."
  type        = string
}

variable "openclaw_access_app_name" {
  description = "Display name for the Access application."
  type        = string
  default     = "openclaw"
}

variable "openclaw_access_email" {
  description = "Exact email address allowed to access the OpenClaw portal."
  type        = string
}

variable "openclaw_hostname" {
  description = "Public hostname protected by Cloudflare Access."
  type        = string
}

variable "openclaw_access_session_duration" {
  description = "Cloudflare Access session duration."
  type        = string
  default     = "24h"
}

variable "existing_one_time_pin_idp_id" {
  description = "Existing account-level One-Time PIN identity provider ID to reuse instead of creating a new one."
  type        = string
  default     = ""
}

variable "manage_openclaw_dns_record" {
  description = "Whether Terraform should manage the proxied OpenClaw DNS record."
  type        = bool
  default     = false
}

variable "openclaw_origin_ip" {
  description = "Origin IP for the proxied OpenClaw DNS record when DNS management is enabled."
  type        = string
  default     = ""

  validation {
    condition     = !var.manage_openclaw_dns_record || trimspace(var.openclaw_origin_ip) != ""
    error_message = "openclaw_origin_ip must be set when manage_openclaw_dns_record is true."
  }
}

variable "openclaw_origin_ca_request_type" {
  description = "Origin CA certificate key type."
  type        = string
  default     = "origin-ecc"

  validation {
    condition = contains(
      ["origin-rsa", "origin-ecc"],
      var.openclaw_origin_ca_request_type
    )
    error_message = "openclaw_origin_ca_request_type must be either origin-rsa or origin-ecc."
  }
}

variable "openclaw_origin_ca_requested_validity" {
  description = "Requested validity period in days for the OpenClaw Origin CA certificate."
  type        = number
  default     = 5475

  validation {
    condition = contains(
      [7, 30, 90, 365, 730, 1095, 5475],
      var.openclaw_origin_ca_requested_validity
    )
    error_message = "openclaw_origin_ca_requested_validity must be one of the Cloudflare-supported durations."
  }
}

variable "openclaw_origin_ca_certificate_filename" {
  description = "Local file name for the generated Origin CA certificate."
  type        = string
  default     = "openclaw-origin-ca.crt.pem"
}

variable "openclaw_origin_ca_private_key_filename" {
  description = "Local file name for the generated Origin CA private key."
  type        = string
  default     = "openclaw-origin-ca.key.pem"
}
