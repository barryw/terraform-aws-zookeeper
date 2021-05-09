output "zookeeper_asg_arns" {
  value = [aws_autoscaling_group.zookeeper.*.arn]
}

output "zookeeper_internal_sg_id" {
  value = aws_security_group.zookeeper-internal.id
}

output "zookeeper_external_sg_id" {
  value = aws_security_group.zookeeper-external.id
}
