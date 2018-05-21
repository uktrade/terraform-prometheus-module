resource "aws_security_group" "es-sg" {
  name        = "${local.service}-es-sg"
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

data "aws_iam_policy_document" "es_vpc_management_access" {

  statement {
    actions = [
      "es:*",
    ]

    resources = [
      "${aws_elasticsearch_domain.es.arn}",
      "${aws_elasticsearch_domain.es.arn}/*",
    ]

    principals {
      type = "AWS"

      identifiers = ["*"]
    }
  }
}

resource "aws_elasticsearch_domain" "es" {

  domain_name           = "${local.es_domain}"
  elasticsearch_version = "5.5"

  cluster_config {
    instance_type            = "${var.es_instance_type}"  #external
    instance_count           = "3"
    dedicated_master_enabled = "false"
    dedicated_master_count   = "0"
    dedicated_master_type    = ""
    zone_awareness_enabled   = "false"
  }

  vpc_options = {
    security_group_ids = ["${aws_security_group.es-sg.id}"]
    subnet_ids = ["${var.private_subnets}"]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = "${var.es_volume_size}"
    volume_type = "gp2"
  }

  snapshot_options {
    automated_snapshot_start_hour = "0"
  }
}

resource "aws_elasticsearch_domain_policy" "es_vpc_management_access" {
  domain_name     = "${local.es_domain}"
  access_policies = "${data.aws_iam_policy_document.es_vpc_management_access.json}"
}
