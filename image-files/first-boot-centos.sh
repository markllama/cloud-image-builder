#! /bin/sh
#
# NOTE: This script should reside in /usr/local/bin.
#       It is executed at bootup of the instance by the kubevirt-installer
#       service. The script disables this service at the end of ths run.
#       The script creates and changes files in the centos user space
#
export KUBEVIRT_ANSIBLE_DIR=~/kubevirt-ansible

SAVE_DIR=~/.save

INVENTORY_FILE=~/inventory

function create_inventory() {
    echo "[masters]" > ${INVENTORY_FILE}
    hostname >> ${INVENTORY_FILE}
}

function set_network_addresses() {
    # make sure we use a weave network that doesnt conflict
    local master_vars_file=${KUBEVIRT_ANSIBLE_DIR}/playbooks/roles/kubernetes-master/vars/main.yml
    
    if [ -w ${master_vars_file} ] ; then
        for num in `seq 30 50` ; do
            ip r | grep -q 172.$num
            if [ "$?" != "0" ] ; then
                sed -i "s/172.30/172.$num/" ${master_vars_file}
                break
            fi
        done
    fi
}

function deploy_kubernetes() {
    sudo ansible-playbook ${KUBEVIRT_ANSIBLE_DIR}/playbooks/cluster/kubernetes/cluster-localhost.yml \
         --connection=local \
         --inventory ${INVENTORY_FILE}
}

function configure_kubernetes_client() {
    mkdir -p ~/.kube
    cp /etc/kubernetes/admin.conf ~/.kube/config
}

function wait_for_kubernetes() {
    # wait for kubernetes cluster to be up
    sudo ansible-playbook ~/cluster-wait.yml --connection=local
}

function deploy_kubevirt() {
    # deploy kubevirt
    kubectl create namespace kubevirt
    # enable software emulation
    grep -q -E 'vmx|svm' /proc/cpuinfo || kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
    export KUBEVIRT_VERSION=$(cat ~/kubevirt-version)
    wget https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/kubevirt-operator.yaml
    wget https://github.com/kubevirt/kubevirt/releases/download/v$KUBEVIRT_VERSION/kubevirt-cr.yaml
    kubectl apply -f kubevirt-operator.yaml
    kubectl apply -f kubevirt-cr.yaml
}

# validate kubevirt pods and services are up
function validate_kubevirt_installation() {
    ansible-playbook after-install-checks.yml \
                     --connection=local \
                     --inventory ${INVENTORY_FILE}
}

function delete_cdi() {
    # remove CDI because users will create it as a lab exercise
    # cdi-provision is in /tmp? MAL
    kubectl delete -f /tmp/cdi-provision.yml
}

function generate_motd() {
    sudo ansible-playbook motd.yml -v
    mv motd* ~/.save
    mv kubevirt-version ~/.save
}

function cleanup_files() {
    # Don't throw things away
    mkdir -p ${SAVE_DIR}

    local save_files="${INVENTORY_FILE} after-install-checks.yml cluster-wait.yml emulation-configmap.yaml"
    local file
    
    # cleanup
    for file in ${save_files} ; do
        [ -f ${file} ] && mv ${file} ${SAVE_DIR}
    done
}

function disable_kubevirt_installer() {
    # disable the service so it only runs the first time the VM boots
    sudo chkconfig kubevirt-installer off
}

# ============================================================================
# MAIN
# ============================================================================

create_inventory
set_network_addresses

deploy_kubernetes
#configure_kubernetes_client
#wait_for_kubernetes

#deploy_kubevirt
#validate_kubevirt_installation

#delete_cdi

#generate_motd
#disable_kubevirt_installer
cleanup_files
