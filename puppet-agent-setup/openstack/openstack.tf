terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {
  cloud  = "bw-cloud" # cloud defined in cloud.yml file
}

variable "network" {
  type    = string
  default = "public-belwue" # default network to be used
}

# Variables
variable "keypair" {
  type    = string
  default = "BWCloud"   # name of keypair created 
}

variable "security_groups" {
  type    = list(string)
  default = ["default"]  # Name of default security group
}

data "openstack_compute_flavor_v2" "flavor" {
  name = "m1.small" # flavor to be used
}

data "openstack_images_image_v2" "image" {
  name        = "Ubuntu 20.04" # Name of image to be used
  most_recent = true
}

# Create an instance
resource "openstack_compute_instance_v2" "server" {
  name            = "Terraform"  #Instance name
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = var.security_groups

  network {
    name = var.network
  }
}

# Output VM IP Address
output "serverip" {
 value = openstack_compute_instance_v2.server.access_ip_v4
}