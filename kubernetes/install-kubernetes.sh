#!/usr/bin/env bash

##
## Automates the installation of Kubernetes. Installs, builds, creates, and configures
## the necessary files and dependencies.
#
## WARNING! ## 
## This script is intended to perform a fresh install and assuming that no dependencies 
## have been previously installed; I urge you to read the code and remove or comment out
## what you don't need, as otherwise it may overwrite configuration files, previous installations,
## or applications you've built from scratch (usually using Make).
##

keyrings=/etc/apt/keyrings
dockergpg=https://download.docker.com/linux/debian
systemdpath=/etc/systemd/system
sourceslist=/etc/apt/sources.list.d
calico_manifest_url=https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests

# It is neccesarry to be executed as root.
if ! [ "$(id -u)" = 0 ]; then
  echo -e "You must be root to run this script.\n \
   Try again and use \"sudo\" command." >&2
  exit 1
fi

if [ "$SUDO_USER" ]; then
  real_user="$SUDO_USER"
else
  real_user="$(whoami)"
fi

sudo="sudo -E -u $real_user"

##########################################################
#                      FUNCTIONS
##########################################################

# Adds the docker gpg key and
# install the docker repository
add_docker_repo() {
  [ ! -d "$keyrings" ] && mkdir -p "$keyrings"

  curl -fsSL "$dockergpg"/gpg | gpg --dearmor -o "$keyrings"/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=$keyrings/docker.gpg] $dockergpg \
  $(lsb_release -cs) stable" | tee "$sourceslist"/docker.list >/dev/null
}

# Prepares the environment for building and installing the CRI.
# 1. Installs Go Programming Language.
# 2. Clones the Mirantis cri-dockerd repository.
# 3. Builds the cri-dockerd executable.
# 4. Installs the cri-dockerd service and the socket.
# 5. Adds the network configuration of the cri-dockerd.
# 6. Reloads system daemons
# 7. Enables cri-dockerd's service's and socket's boot start
install_cri_dockerd() {
  # If 'go' isn't installed, then installs 'go'
  # to build the Container Runtime (cri-dockerd)
  if [ ! "$(command -v go)" ];then
     apt install golang-go >/dev/null 2>&1
  fi

    local go1207="~/go/bin/go1.20.7"

   if [ ! "$(command -v "$go1207")"
     go install golang.org/dl/go1.20.7@latest
     go1.20.7 download
   fi

   alias go="$go1207"

  # Clones the cri-dockerd repository and builds the executable
  cd && $sudo git clone https://github.com/Mirantis/cri-dockerd.git
  cd cri-docker || return
  $sudo mkdir bin && go mod tidy && go build -o bin/cri-dockerd

  [ ! -d /usr/local/bin ] && mkdir -p /usr/local/bin 

  # Installs the cri-dockerd service and socket
  install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
  cp -a packaging/systemd/* "$systemdpath"
  sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' "$systemdpath"/cri-docker.service

  [ ! -d /etc/cni ] && mkdir -p /etc/cni/net.d 

  # Adds the cni network configuration for the cri-dockerd
  
  bash -c 'cat > /etc/cni/net.d/10-containerd-net.conflist <<EOF 
{
  "cniVersion": "1.0.0",
  "name": "containerd-net",
  "type": "bridge",
  "plugins": [
    {
      "name": "bridge",
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "ipMasq": true,
      "promiscMode": true,
      "ipam": {
        "type": "host-local",
        "subnet": "10.2.0.0/16",
        "routes": [
          { "dst": "0.0.0.0/0" },
          { "dst": "::/0" }
        ]
      }
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true}
    }
  ]
}
EOF'

  # Reloads the system daemons and enables
  # boot start of cri-dockerd service and socket
  systemctl daemon-reload &&                 
    systemctl enable cri-docker.service &&   
    systemctl enable --now cri-docker.socket 
}

# Initializes the kubernetes cluster
init_cluster() {
  
  if
    kubeadm init --pod-network-cidr=10.2.0.0/16 \
 --cri-socket=unix:///var/run/cri-dockerd.socket
  then

    $sudo mkdir -p "$HOME"/.kube
    cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config 
    chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config     

    sleep 5

    kubectl create -f "$calico_manifest_url"/tigera-operator.yaml
    kubectl create -f "$calico_manifest_url"/custom-resources.yaml

    sleep 5

    kubectl get nodes

    sleep 3

    kubectl get namespaces

    sleep 3

    kubectl get all -n kube-system

  fi
}

##########################################################
#                      SCRIPT MAIN
##########################################################

# Uncomment if want to disable swap (It is highly encouraged to do so and it is the most recommended if not necessary)
#swapoff -a

# Installs the necessary dependencies

apt-get update &&
  apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

# Adds docker repository
add_docker_repo &&
 apt-get update

# Gets and installs docker using the docker script
# source: <https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script>
$sudo curl https://get.docker.com | bash &&

# Adds the current user to docker's group.
# Required if you want to run docker commands without `sudo`
usermod -aG docker "$USER" 

# Sets the configuration of docker daemon to use
# systemd as the cgroupdriver

bash -c 'cat > /etc/docker/daemon.json <<EOF    
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'

# Adds the directory to the systemd path
# to be used for docker
mkdir -p "$systemdpath"/docker.service.d            
systemctl daemon-reload && systemctl restart docker &&

# Adds the gpg key and installs the repository of kubernetes
$sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 

bash -c "cat <<EOF >$sourceslist/kubernetes.list 
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF"

# Installs the binaries of kubernetes
apt-get update &&                               
  apt-get install -y kubelet kubeadm kubectl && 
  apt-mark hold kubelet kubeadm kubectl &&

# Initializes the cluster (Master control-plane, APIserver and pods)
init_cluster
