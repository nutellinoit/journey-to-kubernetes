/*HOSTNAMES*/

output "hostnames_nginxrancher" {
  value = ["${hcloud_server.host_nginxrancher.*.name}"]
}

output "hostnames_haproxy" {
  value = ["${hcloud_server.host_haproxy.*.name}"]
}

output "hostnames_kube" {
  value = ["${hcloud_server.host_kube.*.name}"]
}


/*PUBLIC IPS*/

output "public_ips_nginxrancher" {
  value = ["${hcloud_server.host_nginxrancher.*.ipv4_address}"]
}

output "public_ips_haproxy" {
  value = ["${hcloud_server.host_haproxy.*.ipv4_address}"]
}

output "public_ips_kube" {
  value = ["${hcloud_server.host_kube.*.ipv4_address}"]
}


/*PRIVATE IPS*/

output "private_ips" {
  value = ["${module.wireguard.vpn_ips}"]
}

output "private_network_interface" {
  value = "eth0"
}