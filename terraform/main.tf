provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["${var.aws_region}a", "${var.aws_region}b"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source       = "./modules/vpc"
  aws_region   = var.aws_region
  azs          = local.azs
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
}

module "security_groups" {
  source               = "./modules/security-groups"
  vpc_id               = module.vpc.vpc_id
  project_name         = var.project_name
  private_subnet_cidrs = module.vpc.private_subnet_cidrs
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "acm" {
  source          = "./modules/acm"
  domain_name     = var.domain_name
  hosted_zone_id  = var.hosted_zone_id
  aws_region      = var.aws_region
  providers = {
    aws         = aws
    aws.us_east_1 = aws.us_east_1
  }
}

module "jenkins_slave" {
  source               = "./modules/jenkins-slave"
  project_name         = var.project_name
  subnet_id            = module.vpc.private_subnet_ids[1]
  security_group_id    = module.security_groups.jenkins_slave_sg_id
  iam_instance_profile = module.iam.jenkins_instance_profile_name
}

module "jenkins_master" {
  source                = "./modules/jenkins-master"
  project_name          = var.project_name
  subnet_id             = module.vpc.private_subnet_ids[0]
  security_group_id     = module.security_groups.jenkins_master_sg_id
  iam_instance_profile  = module.iam.jenkins_instance_profile_name
  domain_name           = var.domain_name
  ecr_repository_url    = module.ecr.repository_url
  depends_on            = [module.jenkins_slave]
}

module "alb" {
  source              = "./modules/alb"
  project_name        = var.project_name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_id   = module.security_groups.alb_sg_id
  certificate_arn     = module.acm.alb_certificate_arn
  domain_name         = var.domain_name
  jenkins_target_ip   = module.jenkins_master.private_ip
  depends_on          = [module.jenkins_master, module.acm]
}

module "ecs" {
  source                = "./modules/ecs"
  project_name          = var.project_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_task_sg_id        = module.security_groups.ecs_tasks_sg_id
  ecr_repository_url    = module.ecr.repository_url
  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn     = module.iam.ecs_task_role_arn
  alb_dev_tg_arn        = module.alb.dev_target_group_arn
  alb_staging_tg_arn    = module.alb.staging_target_group_arn
  alb_prod_tg_arn       = module.alb.prod_target_group_arn
  depends_on            = [module.alb, module.ecr]
}

module "cloudfront" {
  source          = "./modules/cloudfront"
  domain_name     = var.domain_name
  alb_domain_name = module.alb.dns_name
  certificate_arn = module.acm.cloudfront_certificate_arn
  depends_on      = [module.alb, module.acm]
}

module "route53" {
  source                      = "./modules/route53"
  domain_name                 = var.domain_name
  hosted_zone_id              = var.hosted_zone_id
  alb_dns_name                = module.alb.dns_name
  alb_zone_id                 = module.alb.zone_id
  cloudfront_domain_name      = module.cloudfront.domain_name
  cloudfront_zone_id          = module.cloudfront.hosted_zone_id
  acm_alb_validation_records  = module.acm.alb_validation_records
  acm_cf_validation_records   = module.acm.cloudfront_validation_records
  depends_on                  = [module.alb, module.cloudfront, module.acm]
}
