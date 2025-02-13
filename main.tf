// Definindo apenas variáveis necessárias. Todo restante pode ser modificado diretamente neste arquivo
variable "access_key" {}
variable "secret_key" {}
variable "k8s_subnet_cidr" {
  default = "172.31.32.0/20" // Altere esse valor para o correspondente com sua VPC
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

terraform {
  backend "s3" {
    bucket = "dhiegobastelli-k8s" // Passe o nome do Bucket que você criou para armazenar o state
    key    = "terraform/k8s-PICK-state"
    region = "us-east-1"
  }
}

module "k8s_provisioner" {
  source        = "./modules/k8s-provisioner"
  ami           = "ami-04b70fa74e45c3917" // Ubuntu Server 24.04 LTS (HVM), SSD Volume Type
  instance_type = "t3.small"              // A recomendação para k8s é 2vCPU x 2GiB RAM, a mais barata seria uma t3a.small
  // Como é apenas para testes, estou criando uma t2.micro por ser grátis no "free tier"
  volume_cp_size        = 14 // Espaço maior para o NFS no Control Plane
  volume_workers_size   = 8
  instance_count        = 3                       // Número de instâncias
  vpc_id                = "vpc-02536da71580bccce" // ID da sua VPC
  k8s_subnet_cidr       = var.k8s_subnet_cidr
  k8s_subnet_az         = "us-east-1a" // AZ para a subnet que será criada
  AWS_ACCESS_KEY_ID     = var.access_key
  AWS_SECRET_ACCESS_KEY = var.secret_key
  private_key           = file("${path.module}/id_rsa")
  public_key            = file("${path.module}/id_rsa.pub")
  security_group_rules = [
    // PORTAS NECESSÁRIAS PARA O K8S
    {
      protocol    = "tcp"
      from_port   = 6443
      to_port     = 6443
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 10250
      to_port     = 10255
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 30000
      to_port     = 32767
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 2379
      to_port     = 2380
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "tcp"
      from_port   = 6783
      to_port     = 6783
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      protocol    = "udp"
      from_port   = 6783
      to_port     = 6784
      cidr_blocks = ["0.0.0.0/0"]
    },
    //PORTAS NECESSÁRIAS PARA O NFS
    {
      protocol    = "tcp"
      from_port   = 111
      to_port     = 111
      cidr_blocks = [var.k8s_subnet_cidr]
    },
    {
      protocol    = "tcp"
      from_port   = 2049
      to_port     = 2049
      cidr_blocks = [var.k8s_subnet_cidr]
    },
    {
      protocol    = "udp"
      from_port   = 111
      to_port     = 111
      cidr_blocks = [var.k8s_subnet_cidr]
    },
    {
      protocol    = "udp"
      from_port   = 2049
      to_port     = 2049
      cidr_blocks = [var.k8s_subnet_cidr]
    }
  ]
}

output "control_plane_public_ip" {
  value = module.k8s_provisioner.control_plane_public_ip
}

output "worker_public_ips" {
  value = module.k8s_provisioner.worker_public_ips
}