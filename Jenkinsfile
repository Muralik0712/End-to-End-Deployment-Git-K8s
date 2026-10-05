locals {
  ssm_prefix = "/${var.project_name}/jenkins"
}

# ---------------- Secrets (SSM Parameter Store) ----------------
resource "random_password" "jenkins_admin" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "jenkins_admin_password" {
  name  = "${local.ssm_prefix}/admin-password"
  type  = "SecureString"
  value = random_password.jenkins_admin.result
}

resource "aws_ssm_parameter" "docker_username" {
  name  = "${local.ssm_prefix}/docker-username"
  type  = "String"
  value = var.docker_username
}

resource "aws_ssm_parameter" "docker_password" {
  name  = "${local.ssm_prefix}/docker-password"
  type  = "SecureString"
  value = var.docker_password
}

# ---------------- IAM (replaces the manual console steps) ----------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Least privilege: Jenkins only deploys; Terraform owns the cluster.
data "aws_iam_policy_document" "jenkins" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "jenkins" {
  name   = "jenkins-deploy"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

# Session Manager access (shell without opening port 22)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

# ---------------- Network access ----------------
data "github_ip_ranges" "this" {
  count = var.create_github_webhook ? 1 : 0
}

locals {
  github_hook_cidrs = var.create_github_webhook ? data.github_ip_ranges.this[0].hooks_ipv4 : []
}

resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins"
  description = "Jenkins server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "Jenkins UI + GitHub webhooks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = distinct(concat(var.admin_cidrs, local.github_hook_cidrs))
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- EC2 ----------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Stable address so the GitHub webhook URL never changes
resource "aws_eip" "jenkins" {
  domain = "vpc"
}

locals {
  casc = templatefile("${path.module}/templates/casc.yaml.tftpl", {
    jenkins_url = "http://${aws_eip.jenkins.public_ip}:8080/"
    git_repo    = var.git_repo_url
    git_branch  = var.git_branch
    image_repo  = var.docker_image_repo
  })

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region          = var.region
    cluster_name    = module.eks.cluster_name
    cluster_version = var.cluster_version
    ssm_prefix      = local.ssm_prefix
    casc            = local.casc
  })
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.jenkins_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = var.jenkins_key_name

  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-jenkins" }

  # Cluster, node group, access entry and secrets must exist before Jenkins boots
  depends_on = [
    module.eks,
    aws_iam_role_policy.jenkins,
    aws_ssm_parameter.jenkins_admin_password,
    aws_ssm_parameter.docker_username,
    aws_ssm_parameter.docker_password,
  ]
}

resource "aws_eip_association" "jenkins" {
  instance_id   = aws_instance.jenkins.id
  allocation_id = aws_eip.jenkins.id
}
