     ______            _
    |___  /           | |
       / /  ___   ___ | | _____  ___ _ __   ___ _ __
      / /  / _ \ / _ \| |/ / _ \/ _ \ '_ \ / _ \ '__|
    ./ /__| (_) | (_) |   <  __/  __/ |_) |  __/ |
    \_____/\___/ \___/|_|\_\___|\___| .__/ \___|_|
                                    | |
                                    |_|

#### Introduction

This is a Terraform module for bringing up a fully-formed Zookeeper ensemble. It has the following features:

- Forces an odd number of nodes for quorum.
- Nodes are auto provisioning and auto healing. They will come up and cluster automatically.
- Data and log volumes are separate.
- CPU, memory, network and disk metrics are sent to CloudWatch metrics.
- Zookeeper logs are sent to CloudWatch logs.
- If a Zookeeper process becomes unresponsive, its AutoscalingGroup will replace it automatically.

#### TODO

- Backups
- Web frontend
- Maybe use exhibitor?
- Enable rolling updates on the AutoscalingGroup

#### Usage

```hcl
module "zookeeper" {
  source = "github.com/barryw/terraform-aws-zookeeper"

  # If empty, no keypair will be assigned to instances
  keypair_name              = var.keypair
  vpc_id                    = var.vpc_id
  # Zookeeper instance subnets. Should be private
  zookeeper_subnets         = [var.private_subnet1, var.private_subnet2]
  # defaults to false
  create_bastion            = true
  bastion_subnet            = [var.public_subnet1]
  bastion_ingress_cidrs     = ["0.0.0.0/0"]
  zookeeper_version         = "3.7.0"
  # Add any custom tags to include on created resources
  tags                      = {}
  # Gets added to the beginning of resource names
  name_prefix               = "my-zookeeper"
  # Must be odd
  cluster_size              = 3
  instance_type             = "m4.large"
  root_volume_size          = 32
  data_volume_type          = "gp2"
  data_volume_size          = 10
  log_volume_type           = "gp2"
  log_volume_size           = 10
  # Specify a zone to create records on
  route53_zone              = ""
  # Specify the security group id of the groups to allow connections to ZK. If not specified, use the VPC's CIDR
  client_security_group_id  = ""
  # The namespace to use for CloudWatch metrics
  cloudwatch_namespace      = "CWAgent"
  zookeeper_config = {
    clientPort = 2181,
    syncLimit  = 5,
    initLimit  = 10,
    tickTime   = 2000,
    zkHeap     = 4096
  }
}
```

#### License

This module is licensed under the MIT license: https://opensource.org/licenses/MIT
