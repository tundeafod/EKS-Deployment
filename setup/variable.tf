variable "private_keypair" {
  description = "private keypair"
  type        = string
  default     = "tls_private_key.keypair.private_key_pem"
}

variable "domain-name" {
  description = "domain name"
  default     = "tundeafod.click"
}

variable "jenkins_domain_name" {
  description = "jenkins_domain_name"
  default     = "jenkins.tundeafod.click"
}



