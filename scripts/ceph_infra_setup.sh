#!/bin/bash


user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
for i in $(sudo virsh list --all | grep -i $user | egrep -i "mon|osd" | awk {'print $2'} ) ; \
  do virsh destroy $i ; done

for i in $(sudo virsh list --all | grep -i $user | egrep -i "mon|osd" | awk {'print $2'} ) ; \
  do virsh undefine  $i ; done

rm -fr /openstack/images/deployceph/*

clear
read -p "Enter Ceph MON Count: " mon
read -p "Enter Ceph OSD Count: " osd
read -p "Enter Disk Count: " disk
read -p "Enter Ceph Mon Memory Size: " mem_mon
read -p "Enter Ceph OSD Memory Size: " mem_osd

clear

echo -e "\033[1;36mCreating Ceph Deploy OS Directory\033[0m"


if ! ls -al /openstack/images/deployceph ; then
  echo "Creating Directory" ; \
    mkdir /openstack/images/deployceph ;\
  else
    echo "Directory already exist."
fi

cd /openstack/images/deployceph/



echo -e "\033[1;36mCreating Guest Qcow2\033[0m"

### Create guest qcow2

if ! ls -al centos8-guest.qcow2 ; then   
    echo "Creating centos8-guest qcow2 image" ; \
    qemu-img create -f qcow2 centos8-guest.qcow2 80G ;  \
else     
    echo "Guest Image already exist."; 
fi

echo -e "\033[1;36mDownloading Image\033[0m"

### Downloading image 
  
if ! ls -al CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 ; then   
   echo "Downloading Centos-8 Server Image" ; \
   curl -O https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 ; \
else     
    echo "Server Image already exist."; 
fi

echo -e "\033[1;36mModify Image\033[0m"

### Virt resize

cd /openstack/images/deployceph/
virt-resize --expand /dev/sda1 \
/openstack/images/deployceph/CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 \
/openstack/images/deployceph/centos8-guest.qcow2


cd /openstack/images/deployceph/
qemu-img create \
-f qcow2 \
-b /openstack/images/deployceph/centos8-guest.qcow2 \
/openstack/images/deployceph/dummy-ceph-node.qcow2

virt-customize \
-a /openstack/images/deployceph/dummy-ceph-node.qcow2 \
--root-password password:0 \
--uninstall cloud-init





echo -e "\033[1;36mCreating Ceph MON OS Disk\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0
for a in `seq 1 $mon` ; \
do cp /openstack/images/deployceph/dummy-ceph-node.qcow2 $user-ceph-mon-node-$((j++)).qcow2 ; \
done 

echo -e "\033[1;36mCreating Ceph OSD OS Disk\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0
for i in `seq 1 $osd` ; \
do cp /openstack/images/deployceph/dummy-ceph-node.qcow2 $user-ceph-osd-node-$((j++)).qcow2 ; \
done 


echo -e "\033[1;36mSpawning $mon CEPH MON\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0
cmd_ceph() {
    sudo virt-install \
    --name $user-ceph-mon-node-$((i++)) \
    --ram $mem_mon \
    --vcpus 4 \
    --disk path=/openstack/images/deployceph/$user-ceph-mon-node-$((j++)).qcow2,device=disk,bus=virtio,format=qcow2 \
    --os-variant fedora10 \
    --import \
    --vnc \
    --noautoconsole \
    --network bridge=clust_br5,model=virtio \
    --network network:public_network 
}

for a in `seq 1 $mon`; do cmd_ceph ; done

echo -e "\033[1;36mSpawning $osd CEPH OSD\033[0m"
i=0
j=0
cmd_ceph() {
    sudo virt-install \
    --name $user-ceph-osd-node-$((i++)) \
    --ram $mem_osd \
    --vcpus 4 \
    --disk path=/openstack/images/deployceph/$user-ceph-osd-node-$((j++)).qcow2,device=disk,bus=virtio,format=qcow2 \
    --os-variant fedora10 \
    --import \
    --vnc \
    --noautoconsole \
    --network bridge=clust_br5,model=virtio \
    --network network:public_network 
}

for a in `seq 1 $osd`; do cmd_ceph ; done



user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0

for d in `seq 1 $disk`; \
do qemu-img create -f qcow2 -o preallocation=metadata $user-ceph-disk-$((j++)).qcow2 20G ; \
done


for lsblk in vdb  ; do echo $lsblk ; done


user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0

for a in $(virsh list --all | grep -i osd | awk {'print $2'} | grep -i 0 ) ; \
do \
virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblk --persistent --config ; \
done

for a in $(virsh list --all | grep -i osd | awk {'print $2'} |grep -i 1 ) ; \
do \
virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblk --persistent --config ; \
done

for a in $(virsh list --all | grep -i osd | awk {'print $2'} |grep -i 2) ; \
do \
virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblk --persistent --config ; \
done


for i in $(sudo virsh list --all | grep -i $user | awk {'print $2'} ) ; do virsh destroy $i ; done
sleep 10 
for i in $(sudo virsh list --all | grep -i $user | awk {'print $2'} ) ; do virsh start  $i ; done
echo -e "\033[1;36mGetting IP details\033[0m"
sleep 60 



for IP in $(sudo virsh list --all | grep -i ceph | awk {'print $2'}); \
do sudo virsh domifaddr $IP| awk {'print $4'} | awk 'NR>2'|  cut -d'/' -f1; \
done  > /tmp/cephtxtfiles/ip.txt


echo -e "\033[1;36mGetting HOSTENTRY Point\033[0m"

user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')

for ADDR in $(sudo virsh list --all | grep -i ceph | awk {'print $2'}); \
do echo $ADDR ;  \
sudo virsh domifaddr $ADDR | egrep -i 200 | awk {'print $4'} ; \
done > /tmp/cephtxtfiles/1.txt ; \
sed 'N;s/\n/ /'  /tmp/cephtxtfiles/1.txt > /tmp/cephtxtfiles/2.txt ; \
cat /tmp/cephtxtfiles/2.txt | cut -d "/" -f1 > /tmp/cephtxtfiles/3.txt ; \
cat /tmp/cephtxtfiles/3.txt | awk '{ print $NF"     "  $1 }' > /tmp/cephtxtfiles/hostentry.txt

clear 

for p in $(cat /tmp/cephtxtfiles/ip.txt); do ping -c1 $p; done

sleep 5 

clear 

cat /tmp/cephtxtfiles/hostentry.txt
