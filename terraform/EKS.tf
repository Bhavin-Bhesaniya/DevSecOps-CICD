module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name = "Three-Tier-Cluster"
  cluster_version = "1.29"

  cluster_endpoint_public_access  = true

  vpc_id = aws_vpc.devsecops-jenkins-vpc.id
  subnet_ids = aws_subnet.subnets[*].id
 

  eks_managed_node_groups = {
    nodes = {
      min_size = 1
      max_size = 3
      desired_size = 2

      instance_type = ["t2.large"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform = "true"
  }

}

resource "aws_ecr_repository" "frontend" {
  name = "Frontend-Repo"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "backend" {
  name = "Backend-Repo"
  image_tag_mutability = "MUTABLE"
}