/*INIT PROVIDER HCLOUD*/

provider "hcloud" {
  token = "${var.hcloud_token}"
}


/*KUBERNETES NODES PREP*/

resource "hcloud_server" "host_kube" {
  name        = "${format(var.hostname_format_kube, count.index + 1)}"
  datacenter  = "${element(var.hcloud_datacenter,count.index)}"
  image       = "${var.image}"
  server_type = "${var.hcloud_type}"
  ssh_keys    = ["${var.hcloud_ssh_keys}"]


  count = "${var.hosts_kube}"



  provisioner "remote-exec" {
    inline = [
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-add-repository -y ppa:ansible/ansible",
      "apt-get install -yq ufw ${join(" ", var.apt_packages_kubes)}",
      "curl https://releases.rancher.com/install-docker/17.03.2.sh | sh",
      "apt-get -y install linux-image-extra-$(uname -r)",
      "docker run --name enable_lio --privileged --rm --cap-add=SYS_ADMIN -v /lib/modules:/lib/modules -v /sys:/sys:rshared storageos/init:0.1"


    ]
    connection {
      type = "ssh"
      user = "root"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}





/*HAPROXY SERVER INSTALL*/

resource "hcloud_server" "host_haproxy" {
  name        = "${format(var.hostname_format_haproxy, count.index + 1)}"
  #location    = "${var.hcloud_location}"
  datacenter  = "${element(var.hcloud_datacenter,count.index)}"
  image       = "${var.image}"
  server_type = "${var.hcloud_type_haproxy}"
  ssh_keys    = ["${var.hcloud_ssh_keys}"]

  count = "${var.hosts_haproxy}"

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq ufw ${join(" ", var.apt_packages_haproxy)}"
    ]
    connection {
      type = "ssh"
      user = "root"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}



/*NGINX REVERSE PROXY INSTALL*/


resource "hcloud_server" "host_nginxrancher" {
  name        = "${format(var.hostname_format_nginxrancher, count.index + 1)}"
  #location    = "${var.hcloud_location}"
  datacenter  = "${element(var.hcloud_datacenter,count.index)}"
  image       = "${var.image}"
  server_type = "${var.hcloud_type_nginxrancher}"
  ssh_keys    = ["${var.hcloud_ssh_keys}"]

  count = "${var.hosts_nginxrancher}"

  provisioner "remote-exec" {
    inline = [
      "while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "apt-get update",
      "apt-get install -yq ufw ${join(" ", var.apt_packages_nginxrancher)}",
      "curl https://releases.rancher.com/install-docker/17.03.2.sh | sh",
      "curl https://get.acme.sh | sh",
      "git clone https://github.com/nutellinoit/lets-ssl-wizard-nginx.git"
    ]
    connection {
      type = "ssh"
      user = "root"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }


}



/*VPN MODULE*/


module "wireguard" {
  source = "./wireguard"
  count        = "${var.hosts_nginxrancher+var.hosts_kube+var.hosts_haproxy}"
  connections  = "${concat(hcloud_server.host_nginxrancher.*.ipv4_address,hcloud_server.host_kube.*.ipv4_address,hcloud_server.host_haproxy.*.ipv4_address)}"
  private_ips  = "${concat(hcloud_server.host_nginxrancher.*.ipv4_address,hcloud_server.host_kube.*.ipv4_address,hcloud_server.host_haproxy.*.ipv4_address)}"
  hostnames    = "${concat(hcloud_server.host_nginxrancher.*.name,hcloud_server.host_kube.*.name,hcloud_server.host_haproxy.*.name)}"
}







