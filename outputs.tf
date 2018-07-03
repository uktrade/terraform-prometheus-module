output "grafana_internal_elb_dns_name" {
  value = "${aws_elb.grafana-internal-elb.dns_name}"
}

output "prom_internal_elb_dns_name" {
  value = "${aws_elb.prom-internal-elb.dns_name}"
}
