resource "aws_security_group" "es-sg" {
  name        = "${var.environment}-prom-es-sg"
  description = "elasticsearch SG"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "es" {
  source                         = "github.com/terraform-community-modules/tf_aws_elasticsearch?ref=v0.1.0"
  domain_name                    = "${var.environment}-prometheus"
  vpc_options                    = {
    security_group_ids = ["${aws_security_group.es-sg.id}"]
    subnet_ids         = ["${module.vpc.private_subnets}"]
  }
  instance_count                 = "${var.es_instance_count}"
  instance_type                  = "${var.es_instance_type}"
  dedicated_master_type          = "${var.es_dedicated_master_type}"
  ebs_volume_size                = "${var.es_volume_size}"
  es_zone_awareness              = false
}
