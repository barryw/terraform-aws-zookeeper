terraform {
  required_version = ">=0.13.0"
}

locals {
  prefix   = var.name_prefix == "" ? "" : "${var.name_prefix}-"
  asg_arns = jsonencode([for arn in aws_autoscaling_group.zookeeper.*.arn : arn])
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "base" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  most_recent = true
}

data "aws_route53_zone" "zone" {
  name = "${var.route53_zone}."
}

resource "aws_iam_role" "assume_role" {
  name = "${local.prefix}zookeeper-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "zookeeper" {
  name = "${local.prefix}zookeeper-policy"
  role = aws_iam_role.assume_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:SetInstanceHealth"
      ],
      "Effect": "Allow",
      "Resource": ${local.asg_arns}
    },
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:CreateLogGroup",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData",
        "ec2:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "zookeeper" {
  name = "${local.prefix}zookeeper-instance-proile"
  role = aws_iam_role.assume_role.name
}

resource "aws_network_interface" "zookeeper" {
  count           = var.cluster_size
  subnet_id       = element(var.zookeeper_subnets, count.index)
  security_groups = [aws_security_group.zookeeper-internal.id, aws_security_group.zookeeper-external.id]
}

resource "aws_autoscaling_group" "zookeeper" {
  count                     = var.cluster_size
  name                      = "${local.prefix}zookeeper${count.index + 1}"
  availability_zones        = [element(data.aws_availability_zones.available.names, count.index)]
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"

  launch_template {
    id = element(aws_launch_template.zookeeper.*.id, index(aws_launch_template.zookeeper.*.name,
    "${local.prefix}zookeeper-${element(data.aws_availability_zones.available.names, count.index)}"))
    version = "$Latest"
  }
}

resource "aws_launch_template" "zookeeper" {
  count         = var.cluster_size
  name          = "${local.prefix}zookeeper-${element(data.aws_availability_zones.available.names, count.index)}"
  image_id      = data.aws_ami.base.id
  instance_type = var.instance_type
  key_name      = var.keypair_name
  user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yml", {
    version              = var.zookeeper_version
    nodes                = range(1, var.cluster_size + 1)
    domain               = var.route53_zone
    index                = count.index + 1
    zk_heap              = var.zookeeper_config["zkHeap"]
    client_port          = var.zookeeper_config["clientPort"]
    tick_time            = var.zookeeper_config["tickTime"]
    sync_limit           = var.zookeeper_config["syncLimit"]
    init_limit           = var.zookeeper_config["initLimit"]
    cloudwatch_namespace = var.cloudwatch_namespace
  }))

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.root_volume_size
    }
  }

  /* Data Volume */
  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      volume_size = var.data_volume_size
    }
  }

  /* Log Volume */
  block_device_mappings {
    device_name = "/dev/xvdc"

    ebs {
      volume_size = var.log_volume_size
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.zookeeper.name
  }

  network_interfaces {
    delete_on_termination = false
    device_index          = 0
    network_interface_id  = element(aws_network_interface.zookeeper.*.id, count.index)
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${local.prefix}zookeeper-${count.index + 1}"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${local.prefix}zookeeper-${count.index + 1}"
    })
  }
}

resource "aws_security_group" "zookeeper-internal" {
  name   = "${local.prefix}zookeeper-internal"
  vpc_id = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}zookeeper-internal"
  })
}

resource "aws_security_group" "zookeeper-external" {
  name   = "${local.prefix}zookeeper-external"
  vpc_id = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}zookeeper-external"
  })
}

resource "aws_security_group_rule" "zookeeper1" {
  type              = "ingress"
  from_port         = 3888
  to_port           = 3888
  protocol          = "tcp"
  security_group_id = aws_security_group.zookeeper-internal.id
  self              = true
}

resource "aws_security_group_rule" "zookeeper2" {
  type              = "ingress"
  from_port         = 2888
  to_port           = 2888
  protocol          = "tcp"
  security_group_id = aws_security_group.zookeeper-internal.id
  self              = true
}

resource "aws_security_group_rule" "zookeeper-client-sg" {
  count                    = var.client_security_group_id == "" ? 0 : 1
  type                     = "ingress"
  from_port                = var.zookeeper_config["clientPort"]
  to_port                  = var.zookeeper_config["clientPort"]
  protocol                 = "tcp"
  security_group_id        = aws_security_group.zookeeper-external.id
  source_security_group_id = var.client_security_group_id
}

resource "aws_security_group_rule" "zookeeper-client-cidr" {
  count             = var.client_security_group_id == "" ? 1 : 0
  type              = "ingress"
  from_port         = var.zookeeper_config["clientPort"]
  to_port           = var.zookeeper_config["clientPort"]
  protocol          = "tcp"
  security_group_id = aws_security_group.zookeeper-external.id
  cidr_blocks       = [data.aws_vpc.vpc.cidr_block]
}

resource "aws_security_group_rule" "zookeeper-bastion" {
  count                    = var.create_bastion == true ? 1 : 0
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.zookeeper-external.id
  source_security_group_id = aws_security_group.bastion[count.index].id
}

resource "aws_security_group_rule" "zookeeper-internal-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.zookeeper-internal.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "zookeeper-external-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.zookeeper-external.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "bastion" {
  count  = var.create_bastion == true ? 1 : 0
  name   = "${local.prefix}zookeeper-bastion"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}zookeeper-bastion"
  })
}

resource "aws_instance" "bastion" {
  count                       = var.create_bastion == true ? 1 : 0
  ami                         = data.aws_ami.base.id
  instance_type               = "t2.nano"
  associate_public_ip_address = true
  key_name                    = var.keypair_name
  subnet_id                   = var.bastion_subnet
  vpc_security_group_ids      = [aws_security_group.bastion[count.index].id]

  tags = merge(
    var.tags,
    {
      Name = "${local.prefix}zookeeper-bastion"
    }
  )
}

resource "aws_route53_record" "zookeeper" {
  count   = var.cluster_size
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "zk${count.index + 1}"
  type    = "A"
  ttl     = 60
  records = element(aws_network_interface.zookeeper.*.private_ips, count.index)
}

resource "aws_route53_record" "bastion" {
  count   = var.create_bastion == true ? 1 : 0
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "bastion"
  type    = "A"
  ttl     = 60
  records = [aws_instance.bastion[0].public_ip]
}
