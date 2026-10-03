variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Short prefix used to name and tag resources"
  type        = string
  default     = "urlshortener"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet, holds the EC2 instance"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "Private subnet A, for RDS (needs at least two AZs)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "Private subnet B, for RDS"
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zone_a" {
  type    = string
  default = "eu-north-1a"
}

variable "availability_zone_b" {
  type    = string
  default = "eu-north-1b"
}

variable "instance_type" {
  type    = string
  default = "t3.small" # t3.micro works but gets tight with Docker plus two containers plus the CloudWatch agent
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "shortener"
}

variable "db_username" {
  type    = string
  default = "app_admin"
}

variable "db_password" {
  description = "RDS master password, set in terraform.tfvars, never committed"
  type        = string
  sensitive   = true
}

variable "key_pair_name" {
  type    = string
  default = "urlshortener-key"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/urlshortener_key.pub"
}

variable "allowed_ssh_cidr" {
  description = "Who can SSH in. Restrict this to your own IP for anything beyond learning"
  type        = string
  default     = "0.0.0.0/0"
}

variable "domain_name" {
  description = "Root domain, e.g. example.com"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for domain_name, leave blank if Terraform should create it"
  type        = string
  default     = ""
}
