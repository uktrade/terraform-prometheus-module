
module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v1.31.0"
//  version = "1.31.0"

  name = "prometheus-${var.environment}-vpc"

  cidr = "${var.vpc_cidr}"

  azs             = ["${data.aws_availability_zones.available.names}"]
  private_subnets = ["${var.private_subnets}"]
  public_subnets  = ["${var.public_subnets}"]

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "${var.environment}"
  }
}
