// -----
// Private hosted zone
// -----

resource "aws_route53_zone" "prom-private-zone" {
  name = "${var.internal_hosted_zone}"
  vpc {
    vpc_id = "${module.vpc.vpc_id}"
  }
}

resource "aws_route53_record" "prom-internal-alias" {
  zone_id = "${aws_route53_zone.prom-private-zone.zone_id}"
  name    = "prom.${var.internal_hosted_zone}"
  type    = "A"

  alias {
    name                   = "${aws_elb.prom-internal-elb.dns_name}"
    zone_id                = "${aws_elb.prom-internal-elb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "grafana-internal-alias" {
  zone_id = "${aws_route53_zone.prom-private-zone.zone_id}"
  name    = "grafana.${var.internal_hosted_zone}"
  type    = "A"

  alias {
    name                   = "${aws_elb.grafana-internal-elb.dns_name}"
    zone_id                = "${aws_elb.grafana-internal-elb.zone_id}"
    evaluate_target_health = false
  }
}


