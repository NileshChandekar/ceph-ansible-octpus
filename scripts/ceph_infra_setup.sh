#!/bin/bash 
clear
echo -e "\033[1;36Provide Infra Details:- \033[0m"
read -p "Enter Ceph MON Count: " mon
read -p "Enter Ceph OSD Count: " osd
read -p "Enter Disk Count: " disk
read -p "Enter Ceph Mon Memory Size: " mem_mon
read -p "Enter Ceph OSD Memory Size: " mem_osd

clear

echo -e "\033[1;36mCreating Ceph Deploy OS Directory\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
mkdir -p /tmp/$user/cephtxtfiles
sudo mkdir -p /openstack/images/deployceph



### Create guest qcow2
cd /openstack/images/deployceph/
echo -e "\033[1;36mCreating Guest Qcow2\033[0m"
if ! ls -al centos8-guest.qcow2 > /dev/null ; then   
    echo "Creating centos8-guest qcow2 image" ; \
    sudo qemu-img create -f qcow2 centos8-guest.qcow2 80G > /dev/null ;  \
else     
    echo "Guest Image already exist."; 
fi


### Downloading image 
cd /openstack/images/deployceph/
echo -e "\033[1;36mDownloading Image\033[0m"
  if ! ls -al CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 > /dev/null ; then   
   echo "Downloading Centos-8 Server Image" ; \
   sudo curl -O https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 > /dev/null ; \
else     
    echo "Server Image already exist."; 
fi


### Virt resize
echo -e "\033[1;36mModify Image\033[0m"
cd /openstack/images/deployceph/
sudo virt-resize --expand /dev/sda1 \
/openstack/images/deployceph/CentOS-Stream-GenericCloud-8-20220125.1.x86_64.qcow2 \
/openstack/images/deployceph/centos8-guest.qcow2 > /dev/null 

cd /openstack/images/deployceph/
sudo qemu-img create \
-f qcow2 \
-b /openstack/images/deployceph/centos8-guest.qcow2 \
/openstack/images/deployceph/dummy-ceph-node.qcow2 > /dev/null 


### Reset Password to Zero "0"
echo -e "\033[1;36mReset Password\033[0m"
sudo virt-customize \
-a /openstack/images/deployceph/dummy-ceph-node.qcow2 \
--root-password password:0 \
--uninstall cloud-init > /dev/null 


### Creating Ceph MON OS Disk
echo -e "\033[1;36mCreating Ceph $mon MON OS Disk\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0
for a in `seq 1 $mon` ; \
        do sudo cp /openstack/images/deployceph/dummy-ceph-node.qcow2 $user-ceph-mon-node-$((j++)).qcow2 > /dev/null ; \
        done 
i=0
j=0

### Creating Ceph MON Domain
echo -e "\033[1;36mCreating $mon Ceph  MON OS Domain\033[0m"
cmd_ceph() {
    sudo virt-install \
    --name $user-ceph-mon-node-$((i++)) \
    --memory $mem_mon \
    --vcpus 4 \
    --disk /openstack/images/deployceph/$user-ceph-mon-node-$((j++)).qcow2,device=disk,bus=virtio,format=qcow2 \
    --import \
    --os-variant ubuntu20.04 \
    --network network:external \
    --network bridge=providerbr0,model=virtio \
    --noautoconsole \
    --vnc \
    --cpu SandyBridge,+vmx 
}


for a in `seq 1 $mon`; do cmd_ceph  ; done


### Creating Ceph OSD Disk
echo -e "\033[1;36mCreating Ceph OSD Disk\033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0
for i in `seq 1 $osd` ; \
        do sudo cp /openstack/images/deployceph/dummy-ceph-node.qcow2 $user-ceph-osd-node-$((j++)).qcow2 > /dev/null ; \
        done 
i=0
j=0

### Creating Ceph OSD Domain
echo -e "\033[1;36mCreating Ceph OSD Domain\033[0m"
cmd_ceph() {
    sudo virt-install \
    --name $user-ceph-osd-node-$((i++)) \
    --memory $mem_mon \
    --vcpus 4 \
    --disk /openstack/images/deployceph/$user-ceph-osd-node-$((j++)).qcow2,device=disk,bus=virtio,format=qcow2 \
    --import \
    --os-variant ubuntu20.04 \
    --network network:external \
    --network bridge=providerbr0,model=virtio \
    --noautoconsole \
    --vnc \
    --cpu SandyBridge,+vmx
}

for a in `seq 1 $osd`; do cmd_ceph  ; done




i=0
j=0
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
for d in `seq 1 $disk`; \
do sudo qemu-img create -f qcow2 -o preallocation=metadata $user-ceph-disk-$((j++)).qcow2 20G  ; \
done


for lsblkb in vdb  ; do echo $lsblkb > /dev/null ; done
for lsblkc in vdc  ; do echo $lsblkc > /dev/null ; done
for lsblkd in vdd  ; do echo $lsblkd > /dev/null ; done

### Stop running Domain and attach raw disk for OSD's 
echo -e "\033[1;36mStop running Domain and attach raw disk for OSD's :- \033[0m"
user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
for i in $(sudo virsh list --all | grep -i $user | awk {'print $2'} ) ; do sudo virsh destroy $i > /dev/null; done
i=0
j=0

user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
i=0
j=0

for a in $(sudo virsh list --all | grep -i osd | awk {'print $2'} | grep -i 0 ) ; \
do \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkb --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkc --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkd --persistent --config > /dev/null ; \
done

for a in $(sudo virsh list --all | grep -i osd | awk {'print $2'} |grep -i 1 ) ; \
do \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkb --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkc --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkd --persistent --config > /dev/null ; \
done

for a in $(sudo virsh list --all | grep -i osd | awk {'print $2'} |grep -i 2) ; \
do \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkb --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkc --persistent --config > /dev/null ; \
sudo virsh attach-disk --domain $a /openstack/images/deployceph/$user-ceph-disk-$((j++)).qcow2 --target $lsblkd --persistent --config > /dev/null ; \
done


clear
sudo virsh list --all | grep -i $user | grep -i ceph 
for i in $(sudo virsh list --all | grep -i $user | awk {'print $2'} ) ; do sudo virsh start  $i > /dev/null ; done

echo -e "\033[1;36mWait for 60 Second\033[0m"


# 1. Paste the `progress` function in your bash script.
function progress () {
    s=0.5;
    f=0.5;
    echo -ne "\r\n";
    while true; do
           sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[             ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[>            ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[-->          ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[--->         ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[---->        ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[----->       ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[------>      ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[------->     ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[-------->    ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[--------->   ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[---------->  ] Elapsed: ${s} secs." \
        && sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[-----------> ] Elapsed: ${s} secs.";
           sleep $f && s=`echo ${s} + ${f} + ${f} | bc` && echo -ne "\r\t[------------>] Elapsed: ${s} secs.";
    done;
}

# 2. Then, somewhere in your script, wrap any long running process call as follows:
while true; do progress; done &
    sleep 50; # or, whatever
kill $!; trap 'kill $!' SIGTERM


user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')
for i in $(sudo virsh list --all | grep -i $user| awk {'print $2'}); \
do echo $i ;  \
sudo virsh domifaddr $i | egrep -i 192 | awk {'print $4'} ; \
done > /tmp/$user/cephtxtfiles/test.txt

sed 'N;s/\n/ /' /tmp/$user/cephtxtfiles/test.txt > /tmp/$user/cephtxtfiles/test1.txt
cat /tmp/$user/cephtxtfiles/test1.txt | cut -d '/' -f1  > /tmp/$user/cephtxtfiles/test2.txt
cat /tmp/$user/cephtxtfiles/test2.txt | awk {'print $1'} > /tmp/$user/cephtxtfiles/test5.txt

sed 'N;s/\n/ /'  /tmp/$user/cephtxtfiles/test.txt  > /tmp/$user/cephtxtfiles/test1.txt ; cat /tmp/$user/cephtxtfiles/test1.txt | awk {'print $2'} > /tmp/$user/cephtxtfiles/test3.txt ; cat /tmp/$user/cephtxtfiles/test3.txt | cut -d '/' -f1 > /tmp/$user/cephtxtfiles/test4.txt


clear

echo -e "\033[1;36mHostname+IP\033[0m"
cat /tmp/$user/cephtxtfiles/test2.txt
echo -e "\033[1;36mHostname\033[0m"
cat /tmp/$user/cephtxtfiles/test5.txt
echo -e "\033[1;36mIP\033[0m"
cat /tmp/$user/cephtxtfiles/test4.txt
