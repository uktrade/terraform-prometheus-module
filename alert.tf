////// -----
////// Internal ELB
////// -----
//
//resource "aws_security_group" "alert-internal-elb-sg" {
//  name        = "${var.environment}-alertmanager-internal-elb-sg"
//  description = "CrateDB ELB security group"
//  vpc_id      = "${module.vpc.vpc_id}"
//
//  ingress {
//    from_port   = 9093
//    to_port     = 9094
//    protocol    = "tcp"
//    cidr_blocks = ["${var.vpc_cidr}"]
//  }
//
//  egress {
//    from_port   = 0
//    to_port     = 0
//    protocol    = "-1"
//    cidr_blocks = ["0.0.0.0/0"]
//  }
//}
//
//resource "aws_route53_record" "alertmanager-internal-alias" {
//  zone_id = "${aws_route53_zone.prom-private-zone.zone_id}"
//  name    = "alertmanager.${var.internal_hosted_zone}"
//  type    = "A"
//
//  alias {
//    name                   = "${aws_elb.prom-internal-elb.dns_name}"
//    zone_id                = "${aws_elb.prom-internal-elb.zone_id}"
//    evaluate_target_health = false
//  }
//}
////
////// -----
////// Alertmanager ECS Service
////// -----
//
//data "template_file" "alertmanager-task-definition-template" {
//  template = "${file("${path.module}/tasks/alert.json")}"
//}
//
//resource "aws_ecs_task_definition" "alertmanager-task-definition" {
//  family                = "alertmanager"
//  container_definitions = "${data.template_file.alertmanager-task-definition-template.rendered}"
//}
//
//resource "aws_ecs_service" "alertmanager-ecs-service" {
//  name            = "alertmanager-ecs-service"
//  cluster         = "${module.grafana-ecs-cluster.cluster_id}"
//  task_definition = "${aws_ecs_task_definition.alertmanager-task-definition.arn}"
//  desired_count   = 1
//}
