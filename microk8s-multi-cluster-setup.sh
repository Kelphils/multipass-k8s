#!/bin/bash
# - Make sure multipass is installed and working

# - Make sure you have a working internet connection

# Make choices on how much RAM, CPU and storage you want to allocate to the VM (I chose 4GB RAM, 1 CPU cores and 20GB disk space)
# This is based on the specs of my laptop, you can choose whatever you want
# - Spin up 3 master and 3 worker nodes
for i in 1; do
  for nodeType in master worker; do
    multipass launch -n ${nodeType}-${i} -c 1 -m 4G -d 20G
  done
done

# - Install microk8s on all nodes
for i in 1; do
  for nodeType in master worker; do
    multipass exec ${nodeType}-${i} -- sudo snap install microk8s --classic --channel=1.26
    multipass exec ${nodeType}-${i} -- sudo usermod -a -G microk8s ubuntu
    multipass exec ${nodeType}-${i} -- sudo chown -f -R ubuntu ~/.kube
  done
done

# - Check if microk8s is ready in last worker node
multipass exec worker-1 -- microk8s status

# Check status of microk8s in all nodes

# If none of the nodes are ready, wait a few seconds and try again
# If all nodes are ready, continue
# If some nodes are not ready, Restart the nodes that are not ready

# if you run multipass list, all nodes should have two IP addresses
# one is for kubernetes and the other is for the host
# - multipass list

# - Enable the required microk8s addons
for i in 1; do
  for nodeType in master worker; do
    multipass exec ${nodeType}-${i} -- sudo microk8s enable dns
    multipass exec ${nodeType}-${i} -- sudo microk8s enable dashboard
    multipass exec ${nodeType}-${i} -- sudo microk8s enable registry
    multipass exec ${nodeType}-${i} -- sudo microk8s enable istio
    multipass exec ${nodeType}-${i} -- sudo microk8s enable ha-cluster
    multipass exec ${nodeType}-${i} -- sudo microk8s enable metrics-server
    multipass exec ${nodeType}-${i} -- sudo microk8s enable community
    multipass exec ${nodeType}-${i} -- sudo microk8s enable rbac
    multipass exec ${nodeType}-${i} -- sudo microk8s enable helm3
    multipass exec ${nodeType}-${i} -- sudo microk8s enable helm
  done
done

# get the node names and IP addresses only output, check if in file nodes.txt
for nodeType in master worker; do
  multipass list | grep ${nodeType} | awk '{print $3, $1}' | tee -a nodes.txt
done

# copy the nodes.txt file to all nodes
for i in 1; do
  for nodeType in master worker; do
    multipass transfer nodes.txt ${nodeType}-${i}:/home/ubuntu/nodes.txt
  done
done

# echo the content of nodes.txt into the file /etc/hosts in each nodes
for i in 1; do
  for nodeType in master worker; do
    multipass exec ${nodeType}-${i} -- sudo bash -c "cat /home/ubuntu/nodes.txt >> /etc/hosts"
  done
done

# generate the token for the cluster from the master node
# multipass exec master-0 -- sudo microk8s add-node --token-ttl 3600

# join second master node to the cluster using the token generated above
# multipass exec master-1 -- sudo microk8s join token

# generate the token for the cluster from the second master node
multipass exec master-1 -- sudo microk8s add-node --token-ttl 3600

# join third master node to the cluster using the token generated above
# multipass exec master-2 -- sudo microk8s join token

# generate the token for the cluster from the third master node
# multipass exec master-2 -- sudo microk8s add-node --token-ttl 3600

# Join all worker nodes to the cluster using the token generated above
for i in 1; do
  multipass exec worker-${i} -- sudo microk8s join 192.168.64.8:25000/afc13c475d204fba664a1b2dfaca251b/f82021770f66 --worker
done

# After all nodes are joined, kubectl won't work from the worker nodes

# label the worker nodes
for i in 1; do
  for nodeType in master worker; do
    multipass exec master-1 -- sudo microk8s kubectl label node ${nodeType}-${i} node-role.kubernetes.io/${nodeType}=${nodeType}
  done
done

# label master nodes as control plane
for i in 1; do
  multipass exec master-1 -- sudo microk8s kubectl label node master-${i} node-role.kubernetes.io/control-plane=master
done

# taint the master nodes
for i in 1; do
  multipass exec master-1 -- sudo microk8s kubectl taint node master-${i} node-role.kubernetes.io/master:NoSchedule
done

# get configuration for kubectl
multipass exec master-1 -- sudo microk8s config

# Update your local kubectl configuration with the configuration from the master node

# stop all nodes if you want to save resources
for i in 1; do
  for nodeType in worker master; do
    multipass stop ${nodeType}-${i}
  done
done

# start all nodes if you want to use them again
for i in 1; do
  for nodeType in master worker; do
    multipass start ${nodeType}-${i}
  done
done

# delete all nodes if you want to start from scratch
for i in 1; do
  for nodeType in master worker; do
    multipass delete ${nodeType}-${i}
  done
done

# purge all nodes if you want to start from scratch
for i in 1; do
  for nodeType in master worker; do
    multipass purge
  done
done