module "vpc" {
  source               = "./modules/vpc"
  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region
}

module "ecr" {
  source      = "./modules/ecr"
  project     = var.project
  environment = var.environment
}

module "alb" {
  source            = "./modules/alb"
  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = var.app_port
}

module "ecs" {
  source             = "./modules/ecs"
  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_sg_id          = module.alb.alb_sg_id
  app_port           = var.app_port
  aws_region         = var.aws_region
}

module "autoscaling" {
  source       = "./modules/autoscaling"
  cluster_name = module.ecs.cluster_name
  service_name = module.ecs.service_name
}

module "monitoring" {
  source       = "./modules/monitoring"
  project      = var.project
  environment  = var.environment
  cluster_name = module.ecs.cluster_name
  service_name = module.ecs.service_name
  alb_arn      = module.alb.alb_arn
}