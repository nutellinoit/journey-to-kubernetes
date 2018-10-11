# Journey to Kubernetes

> Voglio il **mio cluster Kubernetes**!

*Finalmente* ho completato lo studio ed il test del mio cluster kubernetes personale, dove andrò a trasferire tutti i servizi che gestisco, con l'ottica di avere la possibilità di aggiungere nuovi servizi in un modo *unificato*, *scalabile*, e *high available*.

Nel dettaglio:

- Una decina di siti web, (wordpress, phpbb, ghost...)
- Server Mail
- Server ownCloud 
- Altri servizi web minori

Passiamo ora ad elencare i protagonisti di questo studio.

---

# La ricetta

Per avere un cluster stabile, distribuito e scalabile ho utilizzato i componenti che elencherò di seguito. 
La via non è stata facile, ho dovuto effettuare moltissimi test dato che alcuni sistemi non si sono dimostrati all'altezza di un sistema stabile. 
Alla fine del viaggio sono riuscito ad arrivare ad una soluzione performante, e fault tolerant.


---

## Tools utilizzati

## Servizi web cloud

- **Hetzner Cloud** come provider per le VM https://www.hetzner.com/cloud
- **Amazon route 53** per la gestione dei puntamenti DNS https://aws.amazon.com/it/route53/

### Infrastruttura

- **Terraform** per la creazione e il provisioning dell’infrastruttura base https://www.terraform.io/
- **Kubespray** per la creazione del cluster kubernetes https://github.com/kubernetes-incubator/kubespray 

### File-system

- **GlusterFS** - Playbook Ansible per la gestione dei file-system distribuiti nei nodi https://www.jeffgeerling.com/blog/simple-glusterfs-setup-ansible
- **Kubernetes Local provisioner** - Playbook Ansible per la creazione automatica dei pv di kubernetes https://github.com/nutellinoit/local-storage-playbook

### Gestione dei database distribuiti Mysql

- **Mysql operator** - Operator di oracle per i cluster MySQL self healing https://github.com/oracle/mysql-operator

### Ripristino e migrazione automatica dei workload da backups

- **Beekup suite** per il ripristino dei backup dei siti e per migrazione delle caselle email via imap https://github.com/beeckup

### Sicurezza

- **Let’s encrypt** per l’emissione dei certificati SSL usando il progetto open source https://github.com/Neilpang/acme.sh
- **Wireguard** vpn interna mesh https://www.wireguard.com/
- **Iptables**

### Mail server

- **Haproxy** per l’entrypoint del mail server
- **Poste.io** come mail server

Non entrerò nel dettaglio in questo primo articolo di ognuna delle parti che compongono il cluster, ma farò altri 6 articoli che copriranno le seguenti fasi:

* Creazione macchine virtuali e predisposizione [parte-2](parte-2/README.md)
  * Terraform
  * Aws route 53
* Creazione cluster Kubernetes
  * Kubespray
* Creazione file-system
  * GlusterFS
  * Local Provisioner
* Creazione dei workload
  * Wordpress scalabile e in HA
  * Mailserver
* Test di resilienza
  * Verfica down di nodi multipli di un cluster di 8 nodi, verifica di un riavvio completo (simulando un power off forzato di tutte le macchine)

Stay tuned!

