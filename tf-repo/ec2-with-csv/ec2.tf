#
variable "common_tags" {
  default = {
    "environment" = "dev"
    "role"        = "app"
  }
}
#
variable "name" {
  default = "win00"
}

#
variable "key_id" {
  default = "arn:aws:kms:<ergion>:<account>:key/<key-id>"
}

variable "ec2_iam_profile" {
  default = "iam-xxx"
}

variable "ec2_sg" {
  default = ["sg-xxx"]
}

locals {
  ec2s_csv = csvdecode(file("inst.csv"))
  nics = { for ec2 in local.ec2s_csv : ec2.Name => {
    Name = "${ec2.Name}"
    private_ip = "${ec2.PrivateIP}"
    subnet_id = "${ec2.SubnetId}"
  }}
  ec2s = { for ec2 in local.ec2s_csv : ec2.Name => {
    ami = ec2.AMI
    instance_type = ec2.InstanceType
    az = ec2.AZ
    root_volume_size = ec2.rootVolume
    volume_type = ec2.VolumeType
  }}

  vols = flatten([ 
    for ec2 in local.ec2s_csv : [
      for ebs in split(",",ec2.EbsVolume) : {
        instance = ec2.Name
        size = element(split(";",ebs),0)
        device = element(split(";",ebs),1)
        volume   = ec2.VolumeType
        vol_az   = ec2.AZ
      }
    ]
  ])

}

resource "aws_network_interface" "nic" {
  for_each = local.nics
  subnet_id       = each.value.subnet_id
  private_ips     = [each.value.private_ip]
  security_groups = var.ec2_sg
  tags = merge(var.common_tags, {
    Name = "nic-${each.value.Name}"
  }) 
}

resource "aws_instance" "ec2" {
  for_each = local.ec2s
  ami                  = each.value.ami
  instance_type        = each.value.instance_type
  availability_zone    = each.value.az
  iam_instance_profile = var.ec2_iam_profile
  #associate_public_ip_address = false
  key_name = "k-xxx"

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.key_id
    volume_size           = each.value.root_volume_size
    volume_type           = each.value.volume_type
    tags                  = merge(var.common_tags, { Name = "rootVol-${each.key}" })
  }

  primary_network_interface {
    network_interface_id = aws_network_interface.nic["${each.key}"].id 
  }


  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.common_tags, {
    Name = "${each.key}"
  })
}

resource "aws_ebs_volume" "vol" {
  for_each = { for vol in local.vols : "${vol.instance}-${vol.device}" => vol }
  availability_zone = each.value.vol_az
  size              = each.value.size
  type = each.value.volume
  
  encrypted = true
  kms_key_id = var.key_id

  tags = merge(var.common_tags, {
    Name = "ebsVol-${each.value.instance}"
  })
}

resource "aws_volume_attachment" "vol_att" {
  for_each = { for vol in local.vols : "${vol.instance}-${vol.device}" => vol }
  device_name = each.value.device
  volume_id   = aws_ebs_volume.vol["${each.key}"].id
  instance_id = aws_instance.ec2["${each.value.instance}"].id
}


