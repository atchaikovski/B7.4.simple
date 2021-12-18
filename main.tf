# ---------------------- allowed ports --------------------------------------
locals {
  master_start = [22, 2379, 6443, 10250, 10257, 10259] # from_ports
  master_end   = [22, 2380, 6443, 10250, 10257, 10259] # to_ports
}

locals {
  worker_start = [22, 10250, 30000] # from_ports
  worker_end   = [22, 10250, 32767] # to_ports
} 

# ------------------- EC2 resources ---------------------------------

resource "aws_instance" "master" {
  ami                         = "ami-0affd4508a5d2481b"
  #ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.master.id]
  key_name                    = "aws_adhoc"
  count                       = 1
  associate_public_ip_address = true
  
  # provision by ansible as master using public IP
  
  provisioner "local-exec" {
      command = "sleep 90"
  }

  provisioner "local-exec" {
      command = "ansible-playbook -i '${element(aws_instance.master.*.public_ip, 0)},' --private-key ${var.private_key} -e 'pub_key=${var.public_key}' master.yaml"
  }

  tags = { 
    Name = "Master Server"
    ansibleFilter = "K8S01"
    ansibleNodeType = "master"
    ansibleNodeName = "master${count.index}"
  }

}

resource "aws_instance" "worker" {
  # got Centos 7 image directly from Amazon
  ami                         = "ami-0affd4508a5d2481b"
  #ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.worker.id]
  key_name                    = "aws_adhoc"
  count                       = 1
  associate_public_ip_address = true

  # provision by ansible as worker using public IP
  provisioner "local-exec" {
      command = "sleep 90"
  }
  
  provisioner "local-exec" {
      command = "ansible-playbook -i '${element(aws_instance.worker.*.public_ip, 0)},' --private-key ${var.private_key} -e 'pub_key=${var.public_key}' worker.yaml"
  }
 
 tags = {
    Name = "Worker Server"
    ansibleFilter = "K8S01"
    ansibleNodeType = "worker"
    ansibleNodeName = "worker${count.index}"
 }
}

# --------------- write inventory file ---------------------
resource "local_file" "inventory" {
  filename           = "hosts.ini"
  file_permission    = "0644"
  sensitive_content  = <<-EOF
master0 ansible_host=${element(aws_instance.master.*.public_ip, 0)}
worker0 ansible_host=${element(aws_instance.worker.*.public_ip, 0)}

[control]
master0

[node]
worker0

[k8s_cluster:children]
master0
worker0

EOF
}

# --------------- get static IP addresses ------------------

resource "aws_eip" "master_static_ip" {
  instance = aws_instance.master[0].id
  tags = { Name = "master Server IP" }
}


resource "aws_eip" "worker_static_ip" {
  instance = aws_instance.worker[0].id
  tags = { Name = "worker Server IP" }
}