variable "environment" {
  type        = string
  description = "Execution environment scope"
}

variable "enable_cloudtrail" {
  type        = bool
  description = "Toggle CloudTrail infrastructure provisioning"
}

variable "vpc_id" {
  type        = string
  description = "Target VPC ID for 2-tier integration"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Target private subnets for app/data tier"
}

variable "mandatory_tags" {
  type        = map(string)
  default     = {
    Project         = "Project-Daedalus-V2"
    ManagedBy       = "Terraform"
    DataTaxonomy    = "Confidential-Deception"
    PCI-Scope       = "CDE-Out-Of-Scope-Tripwire"
    HIPAA-Safeguard = "Technical-164.312"
  }
}
