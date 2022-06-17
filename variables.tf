variable "keypair_name" {
  description = "The name of an existing keypair to assign to the Zookeeper nodes"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy resources to"
  type        = string
}

variable "zookeeper_subnets" {
  description = "The list of subnets to deploy resources to. Must exist within the selected VPC"
  type        = list(string)
}

variable "create_bastion" {
  description = "Whether to create a bastion instance or not"
  default     = false
  type        = bool
}

variable "bastion_subnet" {
  description = "The subnet to put the bastion on if one is being created. Should be public."
  type        = string
}

variable "bastion_ingress_cidrs" {
  description = "A list of CIDR ranges that will be allowed to SSH into the bastion. Defaults to the world."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "zookeeper_version" {
  description = "The version of Zookeeper to install"
  default     = "3.7.0"
}

variable "tags" {
  description = "A map of tags that you want associated with all of the resources created"
  type        = map(any)
}

variable "name_prefix" {
  description = "The string to prefix to the name of the Zookeeper resources"
  type        = string
  default     = ""
}

variable "cluster_size" {
  description = "The number of Zookeeper nodes to provision and keep in service. Must be an odd number"
  default     = 3

  validation {
    condition     = var.cluster_size % 2 == 1
    error_message = "The number of Zookeeper nodes in the ensemble must be odd."
  }
}

variable "instance_type" {
  description = "The instance type to use for the Zookeeper nodes"
  type        = string
  default     = "m4.large"
}

variable "data_volume_type" {
  description = "The EBS volume type for each Zookeeper node's data volume"
  default     = "gp2"
}

variable "root_volume_size" {
  description = "The size in GB of the Zookeeper node's root filesystem"
  default     = 32
}

variable "data_volume_size" {
  description = "The size in GB of each Zookeeper node's data volume"
  default     = 10
}

variable "log_volume_type" {
  description = "The EBS volume type for each Zookeeper node's log volume"
  default     = "gp2"
}

variable "log_volume_size" {
  description = "The size in GB of each Zookeeper node's log volume"
  default     = 10
}

variable "route53_zone" {
  description = "The Route53 zone to create the Zookeeper DNS records on"
  type        = string
}

variable "route53_zone_is_private" {
  description = "If the Route53 zone for Zookeeper DNS records is private"
  default     = false
  type        = bool
}

variable "client_security_group_id" {
  description = "The security group id to grant access to the zookeeper nodes on port 2181"
  type        = string
}

variable "zookeeper_config" {
  description = "Settings for Zookeeper"
  default = {
    clientPort = 2181,
    syncLimit  = 5,
    initLimit  = 10,
    tickTime   = 2000,
    zkHeap     = 4096
  }
}

variable "cloudwatch_namespace" {
  description = "The namespace for Cloudwatch Metrics"
  default     = "CWAgent"
}
