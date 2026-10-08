variable "environment" {
  type        = string
  default     = "local-test"
  description = "Target execution environment scope"
}

variable "enable_cloudtrail" {
  type        = bool
  default     = false
  description = "Set true for live AWS deployment; false for LocalStack Community Edition"
}
