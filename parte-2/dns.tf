provider "aws" {
  region = "${var.region}"
}


resource "aws_route53_record" "nginx-rancher-staging" {
  zone_id = "${var.zone_id}"
  name    = "nginx-rancher-staging"
  type    = "A"
  ttl     = "${var.ttl}"
  records = ["${hcloud_server.host_nginxrancher.*.ipv4_address}"]
}

resource "aws_route53_record" "haproxy-staging" {
  zone_id = "${var.zone_id}"
  name    = "haproxy-staging"
  type    = "A"
  ttl     = "${var.ttl}"
  records = ["${hcloud_server.host_haproxy.*.ipv4_address}"]
}


resource "aws_route53_record" "kube-stage" {
  // same number of records as instances
  count = "${var.hosts_kube}"
  zone_id = "${var.zone_id}"
  name = "kube-staging-${count.index+1}"
  type = "A"
  ttl = "${var.ttl}"
  // matches up record N to instance N
  records = ["${element(hcloud_server.host_kube.*.ipv4_address, count.index)}"]
}