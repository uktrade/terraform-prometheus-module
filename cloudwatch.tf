resource "aws_cloudwatch_log_group" "prometheus-cwl-log-group" {
  name = "${local.service}"
  retention_in_days = 7

  tags {
    Service = "prometheus"
  }
}
