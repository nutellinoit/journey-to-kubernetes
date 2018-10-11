> Voglio crearlo in **automatico!**

Bentornati alla seconda parte del viaggio verso il cluster kubernetes. In questo articolo vi mostrerò in quale hosting cloud ho pensato di creare il cluster e come ho fatto.

Trovate tutto il codice di questa guida nella parte 2 di questa repository: https://github.com/nutellinoit/journey-to-kubernetes

I tool che ho utilizzato sono:

* Terraform
* Route 53
* Alcuni pezzi del progetto https://github.com/hobby-kube

Partiamo dalla struttura delle macchine. Su Hetzner cloud una VM con 2 virtual core , 4Gb di ram e 40Gb di disco costa esattamente:

![Hetzner Price](/content/images/2018/09/Schermata-2018-09-15-alle-11.02.10.png)

5.98 euro, praticamente te la regalano. Di queste macchine ne ho prese esattamente 10.

Le ho suddivise logicamente così:

* **1** server Nginx che effettua il reverse proxy verso i servizi esposti da Kubernetes via `NodePort`. Inoltre in questo server Nginx ci sarà installato acme.sh per l'emissione dei certificati SSL e Rancher per avere un overview del cluster che andremo ad installare dopo.
* **8** server Kubernetes, 3 master e 5 worker
* **1** server HaProxy, per effettuare il reverse e il balancing delle porte del server mail

La prima parte del lavoro è creare le macchine virtuali e creare la VPN interna per il traffico privato. 

> Perché la VPN interna?

Hetzner cloud costa poco, ma da solamente un ip pubblico e nessuna possibilità di avere ip privati tra le macchine. Questo problema fa si che tutto il traffico interno del cluster sia facilmente sniffabile. Per ovviare a questo problema utilizziamo Wireguard, una rete mesh interna sicura e criptata. (https://www.wireguard.com/)

Prima di tutto, per poter agire via API su hetzner cloud, bisogna entrare nel proprio progetto, e creare la chiave API da usare:

![Hetzner schermata](/content/images/2018/09/Schermata-2018-09-15-alle-11.09.30.png)

Diamo una descrizione alla nostra chiave e salviamola in un luogo sicuro.

Ricordiamoci anche di aggiungere la chiave pubblica ssh nel pannello in modo tale che Hetzner non crei una password di root, ma aggiunga la nostra chiave ai server per effettuare il login.

Nel mio caso si trova in 

`cat .ssh/id_rsa.pub`

![](/content/images/2018/09/Schermata-2018-09-15-alle-11.13.03.png)

Questa chiave, sopratutto il nome che avrà dovremo usarlo in terraform per aggiungere automaticamente la chiave nei server.

Eseguiti questi passaggi siamo pronti a creare il nostro script terraform.

Iniziamo dal file delle variabili:

```tf
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

## VM type

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
```

Definiamo quindi il numero di server , il tipo, il formato dell'hostname, l'immagine del server che useremo e i dati riguardanti la posizione del datacenter. Notare che `hcloud_datacenter` è una lista di due zone dello stesso datacenter, questo per poter avere più availability nel caso uno dei due abbia dei guasti.
Ricordiamoci inoltre di inserire la nostra chiave API di Hetzner nella variabile `hcloud_token`

Dopodiché andiamo a definire le variabili per AWS route 53

```tf
/* AWS DNS SETTING AND KEYS */

variable "region" {
  default = "us-east-1"
}

variable "ttl" {
  default = 300
}

variable "zone_id" {
  default = "XYZZZZZZZZZZ"
}
```

Per poter utilizzare terraform con il nostro account AWS dovremo prima lanciare il tool awscli da riga di comando e configurare l'accesso:

```bash
aws configure
```


Con queste variabili stiamo indicando di agire sulla zona dns `XYZZZZZZZZZZ` , questo valore lo troviamo all'interno di amazon route 53 nelle informazioni delle hosted zones. `Hosted Zone ID`

![](/content/images/2018/09/hostedzone.jpg)

Definiamo inoltre quali pacchetti installare nei nodi durante il provisioning


```tf

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


```

### Script Principale

Passiamo ora alla definizione principale del nostro script terraform.

In questa fase utilizzeremo le variabili definite fin'ora per gestire il deploy

Iniziamo inizializzando al provider hcloud la nostra API key di Hetzner

```tf
/*INIT PROVIDER HCLOUD*/

provider "hcloud" {
  token = "${var.hcloud_token}"
}

```

Procediamo definendo la creazione di tutti i 10 nodi che saranno utilizzati poi per il reverse proxy, per i nodi kubernetes e per il server haproxy

```tf

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



```

In quest'ultima sezione sono definiti tutti i pacchetti da installare tramite il remote-exec , e tutte le informazioni riguardanti i nodi di Hetzner passati tramite variabile.



Definiamo infine basandoci sulla creazione delle macchine effettuate in precedenza, i record dns di queste macchine virtuali

```tf
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

``` 

In questo modo stiamo utilizzando l'output `ipv4_address` della creazione delle vm tramite il provider hcloud negli step precedenti per creare tutti i record DNS relativi tramite aws route53.


Infine, utilizziamo il modulo terraform `wireguard` per installare la VPN in automatico nei nostri 10 nodi appena creati

```tf
/*VPN MODULE*/
module "wireguard" {
  source = "./wireguard"
  count        = "${var.hosts_nginxrancher+var.hosts_kube+var.hosts_haproxy}"
  connections  = "${concat(hcloud_server.host_nginxrancher.*.ipv4_address,hcloud_server.host_kube.*.ipv4_address,hcloud_server.host_haproxy.*.ipv4_address)}"
  private_ips  = "${concat(hcloud_server.host_nginxrancher.*.ipv4_address,hcloud_server.host_kube.*.ipv4_address,hcloud_server.host_haproxy.*.ipv4_address)}"
  hostnames    = "${concat(hcloud_server.host_nginxrancher.*.name,hcloud_server.host_kube.*.name,hcloud_server.host_haproxy.*.name)}"
}
```

In questo modo invochiamo il modulo presente nella sottocartella `wireguard` passandogli come variabili di ingresso gli output delle altre definizioni. Notare come tutti gli ipv4 dei server sono stati concatenati in modo che gli ip abbiano un ordine definito.

Vediamo ora un dettaglio del modulo wireguard che differisce rispetto alla repository `hobby-kube` linkata all'inizio dell'articolo.

### VPN

In questa serie di guide, vedremo come installare kubernetes utilizzando Kubespray. Tramite Kubespray possiamo definire alcune variabili tra cui il CIDR della network del plugin utilizzato per la comunicazione intra cluster (nel nostro caso sarà flannel). Dobbiamo quindi andare ad inserire questa network nelle route che verranno impostate alla creazione delle interfacce. Dovremo inoltre definire la classe di IP da utilizzare per la nostra rete mesh.

I due parametri si trovano nel file `wireguard/main.tf` e sono in dettaglio:

```tf
variable "overlay_cidr" {
  type = "string"
  default = "10.233.0.0/16"
}

variable "vpn_iprange" {
  default = "10.0.1.0/24"
}
```

### Lo script in azione!

Proviamo ora a lanciare tutto quello che abbiamo preparato, alla fine di tutto dovremmo avere l'output corretto di tutte le creazioni di oggetti definiti nel nostro progetto.

