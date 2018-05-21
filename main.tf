
locals {
  service = "${var.environment}-prometheus"
  es_domain = "${var.environment}-prometheus-storage"
}
