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
  default = ""
}

variable "instance_az" {
  default = "ap-south-1b"
}

variable "subnet_id" {
  default = ""
}

variable "vol_type" {
  default = "gp3"
}

variable "ec2_private_ip" {
  default = "10.0.0.9"
}

variable "ec2_iam_profile" {
  default = ""
}

variable "ec2_sg" {
  default = [""]
}

variable "defaults" {
  default = {
    VolumeType   = "gp3"
    AZ           = "ap-south-1b"
    AMI          = "ami-xxx"
    InstanceType = "t3.micro"
    rootVolume   = 9
    count        = 1
  }
}

locals {

  ec2s_csv  = csvdecode(file("inst.csv"))
  ec2_index = [for ec2_ind in range(length(local.ec2s_csv)) : merge(local.ec2s_csv[ec2_ind], { "type-id" = ec2_ind }, {
    count = contains(keys(local.ec2s_csv[ec2_ind]),"count") ? coalesce(local.ec2s_csv[ec2_ind].count,var.defaults.count) : var.defaults.count 
  })]
  ec2s = flatten([
    for ec2_type in local.ec2_index : [
      for item in range(ec2_type.count) : merge(ec2_type,
        { ind = "${ec2_type.type-id}-${item}" }
      )
    ]
  ])


  nics = [
    for ec2 in local.ec2s : {
      private_ip = length(split(",",ec2.PrivateIP)) == tonumber(ec2.count) ? element(split(",",ec2.PrivateIP),(split("-",ec2.ind)[1])) : "${join(".", slice(split(".", ec2.PrivateIP), 0, 3))}.${element(split(".",ec2.PrivateIP),3)+(split("-",ec2.ind)[1])}"
      subnet_id = ec2.SubnetId
      count = ec2.count
      ind = ec2.ind
      ec2_type = ec2.type-id
      ec2Name = ec2.Name
    }
  ]

  vols = flatten([
    for ec2 in local.ec2s : [
      for ebs in split(",",ec2.EbsVolume) : {
        instance = ec2.Name
        size = split(";",ebs)[0]
        device = split(";",ebs)[1]
        volType = ec2.VolumeType
        vol_az = ec2.AZ
        ec2_ind = ec2.ind
        ec2_type = ec2.type-id
      }
    if length(split(";",ebs))==2]
  if contains(keys(ec2),"EbsVolume") && ec2.EbsVolume != ""])

}

resource "aws_network_interface" "nic" {
  for_each        = { for nic in local.nics : nic.ind => nic}
  subnet_id       = each.value.subnet_id
  private_ips     = [ each.value.private_ip] # [each.value.private_ip]
  security_groups = var.ec2_sg
  tags = merge(var.common_tags, {
    Name = "nic-${each.value.ec2Name}"
  })
}

resource "aws_instance" "ec2" {
  for_each             = { for ec2 in local.ec2s : ec2.ind => ec2}
  ami                  = each.value.AMI
  instance_type        = each.value.InstanceType
  availability_zone    = each.value.AZ
  iam_instance_profile = var.ec2_iam_profile
  #associate_public_ip_address = false
  key_name = ""

  root_block_device {
    delete_on_termination = true
    encrypted             = false # true
    kms_key_id            = null  #var.key_id
    volume_size           = each.value.rootVolume
    volume_type           = each.value.VolumeType
    tags                  = merge(var.common_tags, { Name = "rootVol-${each.value.ind}" })
  }

  primary_network_interface {
    network_interface_id = aws_network_interface.nic[each.value.ind].id
  }



  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.common_tags, {
    Name = "${each.value.ind}"
  })
}

resource "aws_ebs_volume" "vol" {
  for_each          = { for vol in local.vols : "${vol.ec2_ind}-${vol.device}" => vol }
  availability_zone = each.value.vol_az
  size              = each.value.size
  type              = each.value.volType

  encrypted  = false # true
  kms_key_id = null  #var.key_id

  tags = merge(var.common_tags, {
    Name = "ebsVol-${each.value.ec2_ind}"
  })
}

resource "aws_volume_attachment" "vol_att" {
  for_each    = { for vol in local.vols : "${vol.ec2_ind}-${vol.device}" => vol }
  device_name = each.value.device
  volume_id   = aws_ebs_volume.vol["${each.key}"].id
  instance_id = aws_instance.ec2["${each.value.ec2_ind}"].id
}
