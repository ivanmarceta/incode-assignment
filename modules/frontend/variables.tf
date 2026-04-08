variable "name_prefix" {
  description = "Prefix used for frontend resource names."
  type        = string
}

variable "tags" {
  description = "Tags applied to frontend resources."
  type        = map(string)
  default     = {}
}
