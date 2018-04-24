resource "aws_cloudwatch_log_group" "prometheus-cwl-log-group" {
  name = "proemtheus-${var.environment}"

  tags {
    Serivce = "prometheus"
  }
}
