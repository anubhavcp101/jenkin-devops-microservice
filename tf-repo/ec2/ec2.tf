#
variable "common_tags" {
  default = {
    "environment" = "dev"
    "role"        = "web"
  }
}
#
variable "name" {
  default = "win00"
}

#
variable "key_id" {
  default = ""
}

variable "instance_az" {
  default = ""
}

variable "subnet_id" {
  default = ""
}

variable "vol_type" {
  default = ""
}

resource "aws_network_interface" "nic" {
  subnet_id       = var.subnet_id
  private_ips     = [""]
  security_groups = [""]
  tags = merge(var.common_tags, {
    Name = "nic-${var.name}"
  }) 
}

resource "aws_instance" "ec2" {
  ami                  = "ami-xxx"
  instance_type        = "t3.micro"
  availability_zone    = var.instance_az
  iam_instance_profile = "xxx"
  #associate_public_ip_address = false
  key_name = "xxx"

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.key_id
    volume_size           = 8
    volume_type           = var.vol_type
    tags                  = merge(var.common_tags, { Name = "rootVol-${var.name}" })
  }

  primary_network_interface {
    network_interface_id = aws_network_interface.nic.id
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.common_tags, {
    Name = var.name
  })
}

resource "aws_ebs_volume" "vol" {
  availability_zone = var.instance_az
  size              = 30
  type = var.vol_type
  
  encrypted = true
  kms_key_id = var.key_id

  tags = merge(var.common_tags, {
    Name = "dataVol-${var.name}"
  })
}

resource "aws_volume_attachment" "vol_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.vol.id
  instance_id = aws_instance.ec2.id
}
