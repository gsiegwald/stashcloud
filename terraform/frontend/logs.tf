resource "aws_cloudwatch_log_group" "stashcloud" {
  name              = "/stashcloud/containers"
  retention_in_days = 1
  tags = { Project = "stashcloud" }
}
