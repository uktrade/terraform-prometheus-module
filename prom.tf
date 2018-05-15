// -----
// Internal ELB
// -----

resource "aws_security_group" "prom-internal-elb-sg" {
  name        = "${var.environment}-prom-internal-elb-sg"
  description = "Prometheus ELB security group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 9090
    to_port     = 9090
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

# TODO: migrate to ALB
resource "aws_elb" "prom-internal-elb" {
  name = "prom-internal-elb"
  subnets = ["${module.vpc.private_subnets}"]
  internal = true
  security_groups = ["${aws_security_group.prom-internal-elb-sg.id}"]

  listener {
    instance_port     = 9090
    instance_protocol = "http"
    lb_port           = 9090
    lb_protocol       = "http"
  }
}

// -----
// ALB
// -----

resource "aws_security_group" "prom-alb-sg" {
  name        = "${var.environment}-prom-alb-sg"
  description = "Prometheus security group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}

module "prom-alb" {
  source                        = "terraform-aws-modules/alb/aws"
  alb_name                      = "${var.environment}-prom-alb"
  alb_protocols                 = ["HTTPS"]
  alb_security_groups           = ["${aws_security_group.prom-alb-sg.id}"]
  backend_protocol              = "HTTPS"
  backend_port                  = 443
  certificate_arn               = "arn:aws:acm:eu-west-2:177122686904:certificate/58d0e335-afc1-47e6-a025-3cef69a01a88"
  create_log_bucket             = true
  enable_logging                = true
  deregistration_delay          = 10
  health_check_path             = "/healthcheck"
  log_bucket_name               = "${var.environment}-logs-prometheus"
  log_location_prefix           = "prometheus"
  subnets                       = ["${module.vpc.public_subnets}"]
  vpc_id                        = "${module.vpc.vpc_id}"
}

// -----
// ECS cluster
// -----

# TODO: tighten SG
resource "aws_security_group" "prom-lc-sg" {
  name        = "${var.environment}-prom-sg"
  description = "Prometheus security group"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "prom-ecs-cluster" {
  source              = "github.com/lgarvey/tf_aws_ecs"
  name                = "${var.environment}-prometheus"
  servers             = "${var.prometheus_ecs_instance_count}"
  instance_type       = "${var.prometheus_ecs_instance_type}"
  subnet_id           = ["${module.vpc.private_subnets}"]
  vpc_id              = "${module.vpc.vpc_id}"
  docker_storage_size = 25
  security_group_ids = ["${aws_security_group.prom-lc-sg.id}"]
  key_name            = "${var.environment}-prom"
  associate_public_ip_address = false

  additional_user_data_script = "file(${path.module}/files/prom_volume_setup.sh)"
}

// -----
// Prometheus ECS Service
// -----

data "template_file" "prom-task-definition-template" {
  template = "${file("${path.module}/tasks/prom.json")}"

  vars = {
    es_url = "${module.es.endpoint}"

    paas_exporter_url = "${var.paas_exporter_url}"
    pass_exporter_username = "${var.pass_exporter_username}"
    pass_exporter_password = "${var.pass_exporter_password}"

    region = "${data.aws_region.current}"
    log_group = "${aws_cloudwatch_log_group.prometheus-cwl-log-group.name}"
    stream_prefix = "awslogs-${var.environment}-prometheus"
  }
}

resource "aws_ecs_task_definition" "prom-task-definition" {
  family                = "prometheus"
  container_definitions = "${data.template_file.prom-task-definition-template.rendered}"

  volume {
    name = "prometheus_data"
    host_path = "/data/prometheus"
  }
}

resource "aws_ecs_service" "prom-ecs-service" {
  name            = "prom-ecs-service"
  cluster         = "${module.prom-ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.prom-task-definition.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.prom-ecs-service-role.arn}"
  health_check_grace_period_seconds = 10

  load_balancer {
    elb_name = "${aws_elb.prom-internal-elb.name}"
    container_name   = "prometheus"
    container_port   = 9090
  }
}

// ----
// Auth proxy service
// ----

data "template_file" "auth-proxy-definition-template" {
  template = "${file("${path.module}/tasks/prom-auth.json")}"

  vars {
    authbroker_url = "${var.authbroker_url}"
    authbroker_client_id = "${var.authbroker_client_id}"
    authbroker_client_secret = "${var.authbroker_client_secret}"
    authbroker_proxy_redirect_url = "${var.prometheus_authbroker_proxy_redirect_url}"

    region = "${data.aws_region.current}"
    log_group = "${aws_cloudwatch_log_group.prometheus-cwl-log-group.name}"
    stream_prefix = "awslogs-${var.environment}-prometheus"
  }
}

resource "aws_ecs_task_definition" "auth-proxy-task-definition" {
  family                = "auth-proxy"
  container_definitions = "${data.template_file.auth-proxy-definition-template.rendered}"
}

resource "aws_ecs_service" "auth-proxy-ecs-service" {
  name            = "auth-proxy-ecs-service"
  cluster         = "${module.prom-ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.auth-proxy-task-definition.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.prom-ecs-service-role.arn}"
  health_check_grace_period_seconds = 10

  load_balancer {
    target_group_arn = "${module.prom-alb.target_group_arn}"
    container_name   = "authbroker_proxy_nginx"
    container_port   = 443
  }

  depends_on = [
    "aws_iam_role.prom-ecs-service-role",
    "aws_iam_role_policy.prom-ecs-service-role-policy"
  ]
}
