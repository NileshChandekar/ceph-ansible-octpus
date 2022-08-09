#!/bin/bash
clear
echo -e "\033[1;36mCreate Containers\033[0m"

user=$(id | awk '{print $1}' | sed 's/.*(//;s/)$//')

sudo docker run \
-d \
-it \
--restart=always \
--name deployer-node-$user \
--tmpfs /tmp \
--tmpfs /run \
--tmpfs /run/lock \
-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
nileshc85/ceph-ansible-2.9-octopus:20.04


echo -e "\033[1;36mCopy IP and HOST Files in Container\033[0m"

for spawn in $( sudo docker ps | grep -i $user | grep -i deploy | awk {'print $1'} ) ; \
do sudo docker cp /tmp/cephtxtfiles/ip.txt $spawn:/ip.txt ; done

for spawn in $( sudo docker ps | grep -i $user | grep -i deploy | awk {'print $1'} ) ; \
do sudo docker cp /tmp/cephtxtfiles/hostentry.txt $spawn:/hostentry.txt ; done

echo -e "\033[1;36mGet Inside of Container\033[0m"
for spawn in $( sudo docker ps | grep -i $user | grep -i deploy | awk {'print $1'} ) ; \
do sudo docker exec -it -u root $spawn bash ; done


