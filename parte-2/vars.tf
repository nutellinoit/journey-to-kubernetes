/* SERVER NUMBERS */
variable "hosts_kube" {
  default = 8
}

variable "hosts_nginxrancher" {
  default = 1
}

variable "hosts_haproxy" {
  default = 1
}


/* HOSTNAMES FORMAT */

variable "hostname_format_kube" {
  default= "kube-staging-%d"
  type = "string"
}

variable "hostname_format_nginxrancher" {
  default= "nginx-rancher-staging-%d"
  type = "string"
}

variable "hostname_format_haproxy" {
  default= "haproxy-staging-%d"
  type = "string"
}




/* HCLOUD SETTINGS */
variable "hcloud_token" {
  default = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
variable "hcloud_ssh_keys" {
  type = "list"
  default = ["name@example.com"]
}

variable  "hcloud_datacenter" {
  type = "list"
  default = ["fsn1-dc8", "fsn1-dc14"]

}


variable "hcloud_type" {
  default = "cx21"
  type = "string"

}

variable "hcloud_type_nginxrancher" {
  default = "cx21-ceph"
  type = "string"

}

variable "hcloud_type_haproxy" {
  default = "cx21-ceph"
  type = "string"

}

variable "image" {
  type    = "string"
  default = "ubuntu-16.04"
}



/* AWS DNS SETTING AND KEYS */

variable "region" {
  default = "us-east-1"
}

variable "ttl" {
  default = 30
}


variable "zone_id" {
  default = "XYZZZZZZZZZZ"
}


/* PACKAGES INSTALLED DURING PROVISIONING */

// HAPROXY
variable "apt_packages_haproxy" {
  type    = "list"
  default = ["ansible","python"]
}

// NGINX REVERSE
variable "apt_packages_nginxrancher" {
  type    = "list"
  default = ["nginx","git-core","apache2-utils"]
}

// KUBE NODES
variable "apt_packages_kubes" {
  type    = "list"
  default = ["ansible","python","open-iscsi","software-properties-common"]
}
