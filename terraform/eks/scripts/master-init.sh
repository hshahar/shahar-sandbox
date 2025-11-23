#!/bin/bash
# Kubernetes Master Node Initialization Script
# This script installs and configures Kubernetes master node using kubeadm

set -e

echo "========================================="
echo "Initializing Kubernetes Master Node"
echo "========================================="

# Variables from Terraform
CLUSTER_NAME="${cluster_name}"
POD_NETWORK_CIDR="${pod_network_cidr}"
IS_FIRST_MASTER="${is_first_master}"

# Update system
echo "Updating system..."
apt-get update
apt-get upgrade -y

# Disable swap (required for Kubernetes)
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl params
echo "Configuring sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
echo "Installing containerd..."
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install Kubernetes components
echo "Installing Kubernetes components..."
apt-get install -y apt-transport-https ca-certificates curl gpg

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Initialize Kubernetes cluster (first master only)
if [ "$IS_FIRST_MASTER" == "true" ]; then
    echo "Initializing Kubernetes cluster..."

    PRIVATE_IP=$(hostname -I | awk '{print $1}')

    kubeadm init \
        --pod-network-cidr=$POD_NETWORK_CIDR \
        --apiserver-advertise-address=$PRIVATE_IP \
        --node-name=$(hostname -s) \
        --ignore-preflight-errors=NumCPU

    # Setup kubeconfig for ubuntu user
    mkdir -p /home/ubuntu/.kube
    cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config

    # Setup kubeconfig for root
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc

    # Install Calico network plugin
    echo "Installing Calico network plugin..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

    # Generate join command for workers
    kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
    chmod +x /home/ubuntu/join-command.sh

    echo "========================================="
    echo "Master node initialized successfully!"
    echo "========================================="
    echo ""
    echo "To join worker nodes, run:"
    echo "  cat /home/ubuntu/join-command.sh"
    echo ""
    echo "To access the cluster from your local machine:"
    echo "  scp ubuntu@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):/home/ubuntu/.kube/config ~/.kube/config"
fi
