resource "aws_cloudwatch_log_group" "prometheus-cwl-log-group" {
  name = "prometheus-${var.environment}"

  tags {
    Serivce = "prometheus"
  }
}
