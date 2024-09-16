provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
#****** VPC Start ******#

resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"

}

resource "aws_subnet" "some_public_subnet" {
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = "10.0.1.0/24"

}

resource "aws_internet_gateway" "external_gateway" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "K8S Internet Gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.external_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.external_gateway.id
  }

}

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.some_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "k8s_sg" {
  name   = "K8S Ports"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#****** VPC END ******#
resource "aws_instance" "ec2_instance_msr" {
    ami = var.ami_id
    subnet_id = aws_subnet.some_public_subnet.id
    instance_type = var.instance_type
    key_name = var.ami_key_pair_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]

    tags = {
        Name = "k8s_manager_1"
    }


    provisioner "local-exec" {
    
    # Create the Ansible hosts file and add master and worker nodes
    command = <<EOT
        echo "" > ansible/hosts
        echo '[masters]' >> ./ansible/hosts
        echo 'master ansible_host=${self.public_ip} ansible_ssh_user=ec2-user ansible_ssh_private_key_file=/home/luca/Desktop/challenge/test2/kirachallenge.pem ansible_ssh_extra_args="-o StrictHostKeyChecking=no -o IdentitiesOnly=yes"' >> ./ansible/hosts
        echo '\n' >> ./ansible/hosts
        echo '[workes]' >> ./ansible/hosts
    EOT
    }


    provisioner "local-exec" {
        command = "ansible-playbook -i ./ansible/hosts ./ansible/playbooks/general.yml"
    }

    provisioner "local-exec" {
        command = "ansible-playbook -i ./ansible/hosts ./ansible/playbooks/master.yml --extra-vars 'cidr=${aws_subnet.some_public_subnet.cidr_block}'"
    }
    
} 

resource "aws_instance" "ec2_instance_wrk" {
    ami = var.ami_id
    count = var.number_of_worker
    subnet_id = aws_subnet.some_public_subnet.id
    instance_type = var.instance_type
    key_name = var.ami_key_pair_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]

    tags = {
        Name = "k8s_wrk_${count.index + 1}"
    }


    provisioner "local-exec" {

        // Create hosts file in local machine under ./ansible/hosts
        command = <<EOT
            echo 'worker_${count.index + 1} ansible_host=${self.public_ip} ansible_ssh_user=ec2-user ansible_ssh_private_key_file=/home/luca/Desktop/challenge/test2/kirachallenge.pem ansible_ssh_extra_args="-o StrictHostKeyChecking=no -o IdentitiesOnly=yes"' >> ./ansible/hosts
        EOT
    }
    
    provisioner "local-exec" {
        command = "ansible-playbook -i ./ansible/hosts ./ansible/playbooks/general.yml"
    }

    provisioner "local-exec" {
    
    # Read the join command from the file
    command = <<EOT
        join_command=$(cat ./tmp/join_command.sh)
        ansible-playbook -i ./ansible/hosts ./ansible/playbooks/worker.yml --extra-vars "join_command=$join_command"
    EOT
    }

}