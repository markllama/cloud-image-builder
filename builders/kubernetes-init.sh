#!/bin/bash
#
# initialize a kubernetes service on a single host for demonstrations
#
kubeadm init --ignore-preflight-errors=all

export KUBECONFIG=/etc/kubernetes/admin.conf

export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"

# patch weave plugin to have desired IP allocation range
# ipalloc_range={{ ipalloc_range }}
# {% raw %}
# kubectl --namespace=kube-system patch ds weave-net -p '{"spec": {"template": {"spec": {"containers": [{"name": "weave", "env": [{"name": "IPALLOC_RANGE", "value": "'$ipalloc_range'"}]}]}}}}'
# {% endraw %}

# add to masters possibility to schedule pods
kubectl taint nodes --all node-role.kubernetes.io/master-

# add additional service accounts
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
kubectl create clusterrolebinding add-on-default-admin --clusterrole=cluster-admin --serviceaccount=default:default

mkdir -p /home/centos/.kube
cp /etc/kubernetes/admin.conf /home/centos/.kube/config
chown -R centos:centos /home/centos/.kube

if systemctl is-enabled kubernetes-init ; then
    systemctl disable kubernetes-init
fi
