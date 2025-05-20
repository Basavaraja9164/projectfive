variable "aws_region" {
  type    = string
  default = "us-east-1"
  description = "The AWS region to deploy to"
}

variable "blue_ami" {
  type    = string
  description = "The AMI ID for the Blue environment EC2 instances"
}

variable "green_ami" {
  type    = string
  description = "The AMI ID for the Green environment EC2 instances"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
  description = "The EC2 instance type to use"
}

variable "hosted_zone_id" {
  type    = string
  description = "The ID of your Route 53 hosted zone"
}

variable "blue_subdomain" {
  type    = string
  default = "blue.example.com"
  description = "The subdomain for the Blue environment"
}

variable "green_subdomain" {
  type    = string
  default = "green.example.com"
  description = "The subdomain for the Green environment"
}

variable "primary_domain" {
  type    = string
  default = "app.example.com"
  description = "The main application domain name"
}

variable "acm_certificate_arn_blue" {
  type        = string
  description = "The ARN of the ACM certificate for the Blue ALB"
}

variable "acm_certificate_arn_green" {
  type        = string
  description = "The ARN of the ACM certificate for the Green ALB"
}
