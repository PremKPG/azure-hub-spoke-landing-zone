variable "subscription_id" {
  description = "Full resource ID in the form /subscriptions/<guid>"
  type        = string
}

variable "spoke_resource_group_ids" { type = map(string) }
variable "allowed_locations" { type = list(string) }
variable "required_tag" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "operator_principal_id" {
  description = "Optional Entra object ID to receive the custom VM operator role"
  type        = string
  default     = null
}