resource "aws_cloudwatch_log_group" "prometheus-cwl-log-group" {
  name = "${local.service}"

  tags {
    Service = "prometheus"
  }
}
