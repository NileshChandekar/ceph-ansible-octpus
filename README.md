# ceph-ansible-octopus deployment on Centos-8

![image](https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/images/octopus.png)


|Role|
|----|
|Baremetal Node|


|OS|Version|Kernel|
|----|----|----|
|Ubuntu|20.04.4 LTS (Focal Fossa)|5.4.0-121-generic|


|Assumption|
|----|

```
a) qemu-kvm and libvirtd packages are installed the services are running fine on the baremetal node aka physical node. 
b) docker is also running fine on the baremetla node. 
c) my libvirt images are stored in ``/openstack/images``
```

```
# ls -lhrt /var/lib/libvirt/images
lrwxrwxrwx 1 root root 17 Jul 22 10:58 /var/lib/libvirt/images -> /openstack/images
root@617579-logging01:/openstack/images/deployceph# 
```

```
# systemctl status libvirtd -l 
● libvirtd.service - Virtualization daemon
     Loaded: loaded (/lib/systemd/system/libvirtd.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2022-08-03 11:44:16 BST; 2 days ago
TriggeredBy: ● libvirtd-admin.socket
             ● libvirtd-ro.socket
             ● libvirtd.socket
       Docs: man:libvirtd(8)
             https://libvirt.org
   Main PID: 628799 (libvirtd)
```
```
# systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2022-07-19 12:05:23 BST; 2 weeks 3 days ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 206421 (dockerd)
```

|Mon and OSD Node Creation|
|----|

a) Run bellow [script link](https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/scripts/ceph_infra_setup.sh)


b) this will create mon and osd nodes, along with secondary disk 1 each to all osd nodes. 


c) once the script is over you will below output like- 

```
root@656e0cab7199:/# cat /hostentry.txt 
hector-ceph-mon-node-0 192.168.122.91
hector-ceph-osd-node-0 192.168.122.87
hector-ceph-osd-node-1 192.168.122.81
hector-ceph-osd-node-2 192.168.122.90
root@656e0cab7199:/# 
```

```
root@656e0cab7199:/# cat /ip.txt 
192.168.122.91
192.168.122.87
192.168.122.81
192.168.122.90
root@656e0cab7199:/# 

```

|Deployer Node Creation - I am using container as a deployer node|
|----|

d) then run [script link](https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/scripts/container_create.sh)

e) once the script executed, you will automatically get inside to container, 

f) script will copy hostentry from above script and copy inside container. 

g) this will create a ansible container [2.9] with prebuild ceph ansible repository [octopus]

```
(venv) root@afa1ddea1425:/usr/share/ceph-ansible# git branch
  main
* stable-5.0
(venv) root@afa1ddea1425:/usr/share/ceph-ansible# 
```
h) Inside the container run the [script link](https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/scripts/inside_container.sh)

i) Once the above execution completed, that means your Nodes Infra is ready and now we are ready to go for the Ceph deployment. 


|Ceph Deployment|
|----|

* Go inside the container: 

```
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
for spawn in $( sudo docker ps | grep -i $user | grep -i deploy | awk {'print $1'} ) ; \
do sudo docker exec -it -u root $spawn bash ; done
```

* Activate virtual env. 

```
source /root/templates/venv/bin/activate
```

* Goto ceph-ansible dir. 

```
cd /usr/share/ceph-ansible/
```

```
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# ansible --version
ansible 2.9.27
  config file = /usr/share/ceph-ansible/ansible.cfg
  configured module search path = ['/usr/share/ceph-ansible/library']
  ansible python module location = /root/templates/venv/lib/python3.8/site-packages/ansible
  executable location = /root/templates/venv/bin/ansible
  python version = 3.8.10 (default, Mar 15 2022, 12:22:08) [GCC 9.4.0]
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible#
```

* Cretae hostentry. 

```
cat /hostentry.txt >> /etc/hosts
```

* Create inventory

```
root@656e0cab7199:/# cat /usr/share/ceph-ansible/inventory.yml 
[mons]
192.168.122.91


[mgrs]
192.168.122.91


[osds]
192.168.122.87
192.168.122.81
192.168.122.90


root@656e0cab7199:/# 
```

* Check ping respone. 

```
(venv) root@656e0cab7199:/# ansible -i /usr/share/ceph-ansible/inventory.yml all -m ping 
192.168.122.87 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.122.91 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.122.90 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.122.81 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
(venv) root@656e0cab7199:/# 
```

* Ceph config changes. ``(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# vi group_vars/all.yml``

```
(venv) root@656e0cab7199:/# cat /usr/share/ceph-ansible/group_vars/all.yml
---
dummy:
ceph_origin: repository
ceph_repository: community
ceph_stable_release: octopus
cephx: true
generate_fasid: true
journal_size: 1024
public_network: 192.168.122.0/24
cluster_network: 192.168.200.0/24
monitor_interface: eth2
monitor_address: 192.168.122.91
dashboard_enabled: False
ceph_conf_overrides: 
  mon:
    mon_warn_on_insecure_global_id_reclaim_allowed: False
openstack_config: true
(venv) root@656e0cab7199:/# 

```

* OSD map. ``(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# vi group_vars/osds.yml``

```
(venv) root@656e0cab7199:/# cat /usr/share/ceph-ansible/group_vars/osds.yml
---
dummy:
devices:
  - /dev/vdb
  - /dev/vdc
  - /dev/vdd
journal_collocation: true    
(venv) root@656e0cab7199:/# 
```

* Start the deployment. 

```
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# ansible-playbook -i inventory.yml site.yml
```

* Installation completed - 5-7 min. 

```
PLAY RECAP **************************************************************************************************************************************************
192.168.200.11             : ok=187  changed=30   unreachable=0    failed=0    skipped=450  rescued=0    ignored=1   
192.168.200.14             : ok=119  changed=20   unreachable=0    failed=0    skipped=361  rescued=0    ignored=1   
192.168.200.15             : ok=164  changed=27   unreachable=0    failed=0    skipped=424  rescued=0    ignored=1   
192.168.200.20             : ok=171  changed=32   unreachable=0    failed=0    skipped=421  rescued=0    ignored=1   


INSTALLER STATUS ********************************************************************************************************************************************
Install Ceph Monitor           : Complete (0:00:14)
Install Ceph Manager           : Complete (0:00:32)
Install Ceph OSD               : Complete (0:01:28)
Install Ceph Crash             : Complete (0:00:10)

```


```
[root@hector-ceph-mon-node-0 ~]# ceph -s
  cluster:
    id:     b9db2ddd-41c0-4a67-8478-b40ee5b2de3c
    health: HEALTH_OK
 
  services:
    mon: 1 daemons, quorum hector-ceph-mon-node-0 (age 26m)
    mgr: hector-ceph-mon-node-0(active, since 25m)
    osd: 9 osds: 9 up (since 24m), 9 in (since 24m)
 
  data:
    pools:   8 pools, 225 pgs
    objects: 0 objects, 0 B
    usage:   9.0 GiB used, 171 GiB / 180 GiB avail
    pgs:     225 active+clean
 
[root@hector-ceph-mon-node-0 ~]# 
```

```
[root@hector-ceph-mon-node-0 ~]# ceph df
--- RAW STORAGE ---
CLASS  SIZE     AVAIL    USED    RAW USED  %RAW USED
hdd    180 GiB  171 GiB  50 MiB   9.0 GiB       5.03
TOTAL  180 GiB  171 GiB  50 MiB   9.0 GiB       5.03
 
--- POOLS ---
POOL                   ID  PGS  STORED  OBJECTS  USED  %USED  MAX AVAIL
device_health_metrics   1    1     0 B        0   0 B      0     54 GiB
images                  2   32     0 B        0   0 B      0     54 GiB
volumes                 3   32     0 B        0   0 B      0     54 GiB
vms                     4   32     0 B        0   0 B      0     54 GiB
backups                 5   32     0 B        0   0 B      0     54 GiB
metrics                 6   32     0 B        0   0 B      0     54 GiB
manila_data             7   32     0 B        0   0 B      0     54 GiB
manila_metadata         8   32     0 B        0   0 B      0     54 GiB
[root@hector-ceph-mon-node-0 ~]# 
```

