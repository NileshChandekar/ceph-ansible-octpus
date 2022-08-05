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
