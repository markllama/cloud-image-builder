#!/bin/bash
#
# Install kubevirt on top of an existing kubernetes
#
export KUBECONFIG=/etc/kubernetes/admin.conf
#
kubectl apply -f /home/centos/templates/kubevirt-operator.yaml
kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
kubectl apply -f /home/centos/templates/kubevirt-cr.yaml

if systemctl is-enabled kubevirt-init ; then
    systemctl disable kubevirt-init
fi
