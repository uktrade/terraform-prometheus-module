
module "grafana-db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.environment}-grafana"

  engine            = "postgres"
  engine_version    = "${var.grafana_db_version}"
  instance_class    = "${var.grafana_db_instance_size}"
  allocated_storage = "${var.grafana_db_storage}"
  storage_encrypted = "${var.grafana_db_encrypted}"

  name = "${var.grafana_db_name}"
  username = "${var.grafana_db_user}"
  password = "${var.grafana_db_password}"
  port     = "5432"

  vpc_security_group_ids = ["${module.vpc.default_security_group_id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  backup_retention_period = 7

  # DB subnet group
  subnet_ids = ["${module.vpc.private_subnets}"]

  # DB parameter group
  family = "postgres9.6"
}

// -----
// ALB
// -----

resource "aws_security_group" "grafana-alb-sg" {
  name        = "${var.environment}-grafana-alb-sg"
  description = "Grafana security group"
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
      "${var.vpc_cidr}"
    ]
  }
}

module "grafana-alb" {
  source                        = "terraform-aws-modules/alb/aws"
  alb_name                      = "${var.environment}-grafana-alb"
  alb_protocols                 = ["HTTPS"]
  alb_security_groups           = ["${aws_security_group.prom-alb-sg.id}"]
  backend_protocol              = "HTTPS"
  backend_port                  = 443
  certificate_arn               = "arn:aws:acm:eu-west-2:177122686904:certificate/58d0e335-afc1-47e6-a025-3cef69a01a88"
  create_log_bucket             = true
  enable_logging                = true
  deregistration_delay          = 10
  health_check_path             = "/healthcheck"
  log_bucket_name               = "${var.environment}-logs-grafana"
  log_location_prefix           = "grafana"
  subnets                       = ["${module.vpc.public_subnets}"]
//  tags                          = "${map("Environment", "test")}"
  vpc_id                        = "${module.vpc.vpc_id}"
}

// -----
// ECS cluster
// -----

# TODO: tighten this SG!
resource "aws_security_group" "grafana-lc-sg" {
  name        = "${var.environment}-prom-core-sg"
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

module "grafana-ecs-cluster" {
  source              = "github.com/terraform-community-modules/tf_aws_ecs"
  name                = "${var.environment}-grafana"
  servers             = "${var.grafana_ecs_instance_count}"
  instance_type       = "${var.grafana_ecs_instance_type}"
  subnet_id           = ["${module.vpc.private_subnets}"]
  vpc_id              = "${module.vpc.vpc_id}"
  docker_storage_size = 25
  security_group_ids = ["${aws_security_group.grafana-lc-sg.id}"]
  key_name            = "${var.environment}-prom"
}

// -----
// ECS Service
// -----

data "template_file" "grafana-task-definition-template" {
  template = "${file("${path.module}/tasks/grafana.json")}"

  vars {
    authbroker_url = "${var.authbroker_url}"
    authbroker_client_id = "${var.authbroker_client_id}"
    authbroker_client_secret = "${var.authbroker_client_secret}"
    authbroker_proxy_redirect_url = "${var.grafana_authbroker_proxy_redirect_url}"
    db_host = "${module.grafana-db.this_db_instance_endpoint}"
    db_user = "${var.grafana_db_user}"
    db_name = "${var.grafana_db_name}"
    db_password = "${var.grafana_db_password}"
  }
}

resource "aws_ecs_task_definition" "grafana-task-definition" {
  family                = "${var.environment}-grafana"
  container_definitions = "${data.template_file.grafana-task-definition-template.rendered}"
}

resource "aws_ecs_service" "grafana-ecs-service" {
  name            = "${var.environment}-grafana-ecs-service"
  cluster         = "${module.grafana-ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.grafana-task-definition.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.prom-ecs-service-role.arn}"
  health_check_grace_period_seconds = 10

  load_balancer {
    target_group_arn = "${module.grafana-alb.target_group_arn}"
    container_name   = "authbroker_proxy_nginx"
    container_port   = 443
  }

  depends_on = [
    "aws_iam_role.prom-ecs-service-role",
    "aws_iam_role_policy.prom-ecs-service-role-policy"
  ]
}
