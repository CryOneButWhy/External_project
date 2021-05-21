#Defining local variables
locals {
ssh_user = "ubuntu"
key_name = "project"
#The path to a private key for IAM user
private_key_path = "~/EPAM/Final/Terraform/project.pem"
#VPC and subnet are created on AWS end.
vpc = "vpc-0ecde7ebbbb135859"
subnet = "subnet-0eb762e211f822148"
}

#Loading AWS provider
provider "aws" {
  profile = "terraform"
  region = "eu-central-1"
  shared_credentials_file = "/home/vlados/EPAM/Final/Terraform/credentials"
}

#Creating security group with opened ports
resource "aws_security_group" "project"{
  name = "project_sec"
  vpc_id = local.vpc
  ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    from_port = 8080
    to_port = 8081
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#Creatnig S3 profile to allow EC2 instance to download Jenkins folder
resource "aws_iam_instance_profile" "S3_profile"{
 name = "S3_profile"
 role = "Project_s3"
}

#Creating instance for Docker
resource "aws_instance" "Docker" {
ami = "ami-0767046d1677be5a0"
subnet_id = local.subnet
instance_type = "t2.micro"
associate_public_ip_address = true
security_groups = [aws_security_group.project.id]
key_name = local.key_name
private_ip = "10.0.0.125"

#Making the first SSH connection to make sure it is ready and updating repos
provisioner "remote-exec" {
  connection {
  host = self.public_ip
  type = "ssh"
  user = local.ssh_user
  private_key = file(local.private_key_path)
  }
  inline = [
    "sudo apt update -y",
    "mkdir /home/ubuntu/jenkins"
     ]
   }
   #Setting up Docker via Ansible in order to run containers
  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.Docker.public_ip}, -u ubuntu --private-key ${local.private_key_path} playbook_docker.yml"
  }
}

#Creating instance for Jenkins
resource "aws_instance" "Jenkins" {
ami = "ami-0767046d1677be5a0"
subnet_id = local.subnet
instance_type = "t2.micro"
associate_public_ip_address = true
security_groups = [aws_security_group.project.id]
key_name = local.key_name
iam_instance_profile = aws_iam_instance_profile.S3_profile.id
private_ip = "10.0.0.126"

#Making the first SSH connection to make sure it is ready and updating repos
provisioner "remote-exec" {
  connection {
  host = self.public_ip
  type = "ssh"
  user = local.ssh_user
  private_key = file(local.private_key_path)
  }
  inline = [
    "sudo apt update -y"
     ]
   }
   #Setting up Jenkins using Ansible playbook
  provisioner "local-exec" {
    command = "ansible-playbook -i ${aws_instance.Jenkins.public_ip}, -u ubuntu --private-key ${local.private_key_path} playbook.yml"
  }

}
#Giving outputs
output "docker_public" {
  value = aws_instance.Docker.public_ip
}

output "jenkins_public" {
  value = aws_instance.Jenkins.public_ip
}
