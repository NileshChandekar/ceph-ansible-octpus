# ceph-ansible-octopus deployment on Centos-8

<p align="center">
  <img 
    width="600"
    height="300"
    src="https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/images/octopus.png/600/300"
  >
</p>

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

|Node Creation|
|----|

a) Run bellow [script link](https://github.com/NileshChandekar/ceph-ansible-octpus/blob/main/scripts/ceph_infra_setup.sh)


b) this will create mon and osd nodes, along with secondary disk 1 each to all osd nodes. 


c) once the script is over you will below output like- 

```
192.168.200.14     root-ceph-mon-node-0
192.168.200.11     root-ceph-osd-node-0
192.168.200.15     root-ceph-osd-node-1
192.168.200.20     root-ceph-osd-node-2
```

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
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# cat inventory.yml 
[mons]
192.168.200.14

[mgrs]
192.168.200.11
192.168.200.15
192.168.200.20

[osds]
192.168.200.11
192.168.200.15
192.168.200.20

(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# 
```

* Check ping respone. 

```
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# ansible -i inventory.yml all -m ping 
192.168.200.14 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.200.20 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.200.15 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.200.11 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# 
```

* Ceph config changes. ``(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# vi group_vars/all.yml``

```
#### Added by Nilesh 

ceph_origin: repository
ceph_repository: community
ceph_stable_release: octopus

public_network: 192.168.200.0/24
cluster_network: 192.168.100.0/24

monitor_interface: eth1

dashboard_enabled: False

ceph_conf_overrides:
  mon:
    mon_warn_on_insecure_global_id_reclaim_allowed: False

openstack_config: true
```

* OSD map. ``(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# vi group_vars/osds.yml``

```
devices:
  - /dev/vdb
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

Tuesday 09 August 2022  11:06:49 +0000 (0:00:00.039)       0:04:15.920 ******** 
=============================================================================== 
ceph-common : install redhat ceph packages ---------------------------------------------------------------------------------------------------------- 67.18s
ceph-osd : create openstack pool(s) ----------------------------------------------------------------------------------------------------------------- 25.24s
ceph-osd : wait for all osd to be up ---------------------------------------------------------------------------------------------------------------- 11.46s
install ceph-mgr packages on RedHat or SUSE ---------------------------------------------------------------------------------------------------------- 9.65s
ceph-common : install centos dependencies ------------------------------------------------------------------------------------------------------------ 7.11s
ceph-osd : generate keys ----------------------------------------------------------------------------------------------------------------------------- 6.29s
ceph-osd : use ceph-volume lvm batch to create bluestore osds ---------------------------------------------------------------------------------------- 5.82s
ceph-osd : get keys from monitors -------------------------------------------------------------------------------------------------------------------- 3.73s
ceph-osd : copy ceph key(s) if needed ---------------------------------------------------------------------------------------------------------------- 3.41s
gather and delegate facts ---------------------------------------------------------------------------------------------------------------------------- 3.04s
ceph-infra : install chrony -------------------------------------------------------------------------------------------------------------------------- 2.95s
ceph-osd : apply operating system tuning ------------------------------------------------------------------------------------------------------------- 2.86s
ceph-osd : install dependencies ---------------------------------------------------------------------------------------------------------------------- 2.72s
ceph-mon : fetch ceph initial keys ------------------------------------------------------------------------------------------------------------------- 2.54s
ceph-mgr : create ceph mgr keyring(s) on a mon node -------------------------------------------------------------------------------------------------- 2.05s
ceph-osd : set noup flag ----------------------------------------------------------------------------------------------------------------------------- 1.47s
ceph-config : look up for ceph-volume rejected devices ----------------------------------------------------------------------------------------------- 1.43s
ceph-facts : check if the ceph mon socket is in-use -------------------------------------------------------------------------------------------------- 1.39s
ceph-facts : read osd pool default crush rule -------------------------------------------------------------------------------------------------------- 1.38s
ceph-config : look up for ceph-volume rejected devices ----------------------------------------------------------------------------------------------- 1.36s
(venv) root@8d13fd1af0a6:/usr/share/ceph-ansible# 
```

```
[root@localhost ~]# ceph -s
  cluster:
    id:     dc7ad8fb-0b14-46f3-a51b-4bf99e62e463
    health: HEALTH_WARN
            Reduced data availability: 225 pgs inactive
            Degraded data redundancy: 225 pgs undersized
 
  services:
    mon: 1 daemons, quorum localhost (age 36m)
    mgr: localhost(active, starting, since 1.90691s)
    osd: 3 osds: 3 up (since 35m), 3 in (since 35m)
 
  data:
    pools:   8 pools, 225 pgs
    objects: 0 objects, 0 B
    usage:   3.7 GiB used, 56 GiB / 60 GiB avail
    pgs:     100.000% pgs not active
             225 undersized+peered
 
[root@localhost ~]#
```

```
[root@localhost ~]# ceph df
--- RAW STORAGE ---
CLASS  SIZE    AVAIL   USED     RAW USED  %RAW USED
hdd    60 GiB  56 GiB  731 MiB   3.7 GiB       6.19
TOTAL  60 GiB  56 GiB  731 MiB   3.7 GiB       6.19
 
--- POOLS ---
POOL                   ID  PGS  STORED  OBJECTS  USED  %USED  MAX AVAIL
device_health_metrics   1    1     0 B        0   0 B      0     18 GiB
images                  2   32     0 B        0   0 B      0     18 GiB
volumes                 3   32     0 B        0   0 B      0     18 GiB
vms                     4   32     0 B        0   0 B      0     18 GiB
backups                 5   32     0 B        0   0 B      0     18 GiB
metrics                 6   32     0 B        0   0 B      0     18 GiB
manila_data             7   32     0 B        0   0 B      0     18 GiB
manila_metadata         8   32     0 B        0   0 B      0     18 GiB
[root@localhost ~]# 
```

