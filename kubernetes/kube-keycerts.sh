#!/usr/bin/env bash

##
## Creates TLS and authentication certificates to customize
## your kubernetes deployment passing you own certificates
## signed for your CA to the `kubeadm init` command.
##
## DNS names, usage extensions and some IPs are set to the
## default initial settings (i.e if you don't pass custom values
# to kubeadm init)
##

MASTER_IP="$(hostname -I | cut -d' ' -f1)"
certsDir=/path/to/certs
extDir="$certsDir/ext"
csrConfDir="$certsDir/csrconf"

apiserverExtension="$extDir/apiserver.conf"
apiserverCsrConf="$csrConfDir/apiservercsr.conf"
apiserverCertsName="$certsDir/apiserver"
asSignerCrt="$certsDir/ca.crt"
asSignerKey="$certsDir/ca.key"

apiserverKubeletClientExtension="$extDir/apiserverKubeletC.conf"
apiserverKubeletClientCsrConf="$csrConfDir/apiserverKubeletCcsr.conf"
apiserverKubeletClientCerts="$certsDir/apiserver-kubelet-client"
askcSignerCrt="$certsDir/ca.crt"
askcSignerKey="$certsDir/ca.key"

apiserverEtcdClientExtension="$extDir/apiserverEtcdC.conf"
apiserverEtcdClientCsrConf="$csrConfDir/apiserverEtcdCcsr.conf"
apiserverEtcdClientCerts="$certsDir/apiserver-etcd-client"
asecSignerCrt="$certsDir/etcd/ca.crt"
asecSignerKey="$certsDir/etcd/ca.key"

frontProxyClientExtension="$extDir/frontProxyC.conf"
frontProxyClientCsrConf="$csrConfDir/frontProxyCcsr.conf"
frontProxyClientCerts="$certsDir/front-proxy-client"
fpcSignerCrt="$certsDir/front-proxy-ca.crt"
fpcSignerKey="$certsDir/front-proxy-ca.key"

etcdHealthcheckClientExtension="$extDir/healthcheckC.conf"
etcdHealthcheckClientCsrConf="$csrConfDir/healthcheckCcsr.conf"
etcdHealthcheckClientCerts="$certsDir/etcd/healthcheck-client"
ehcSignerCrt="$certsDir/etcd/ca.crt"
ehcSignerKey="$certsDir/etcd/ca.key"

etcdPeerExtension="$extDir/peer.conf"
etcdPeerCsrConf="$csrConfDir/peerCsr.conf"
etcdPeerCerts="$certsDir/etcd/peer"
epeSignerCrt="$certsDir/etcd/ca.crt"
epeSignerKey="$certsDir/etcd/ca.key"

etcdServerExtension="$extDir/server.conf"
etcdServerCsrConf="$csrConfDir/serverCsr.conf"
etcdServerCerts="$certsDir/etcd/server"
esrSignerCrt="$certsDir/etcd/ca.crt"
esrSignerKey="$certsDir/etcd/ca.key"

kubeletExtension="$extDir/kubeletExt.conf"
kubeletCsrConf="$csrConfDir/kubeletCsr.conf"
kubeletCert="/var/lib/kubelet/pki/kubelet"
kubeSignerCrt="$certsDir/ca.crt"
kubeSignerKey="$certsDir/ca.key"

if ! [ "$(id -u)" = 0 ]; then
  echo -e "You must be root to run this script.\n \
   Try again and use \"sudo\" command." >&2
  exit 1
fi

## Creates the configuration extension templates
## for the certificates.
create_csr_config() {

  local csrConfig="$1"
  local commonName="$2"
  local organization="$3"
  local masterIP="$4"
  local MASTER_CLUSTER_IP="$5"

  echo "Creating $csrConfig..."
  cat >"$csrConfig" <<EOF
  [ req ]
  default_bits = 2048
  prompt = no
  default_md = sha256
  distinguished_name = dn
  req_extensions = req_ext

  [ dn ]
  C = MX
  ST = Puebla
  L = Puebla
  O = $organization
  OU = system
  CN = $commonName

  [ req_ext ]
  subjectAltName = @alt_names

  [ alt_names ]
  DNS.1 = kubernetes
  DNS.2 = kubernetes.default
  DNS.3 = kubernetes.default.svc
  DNS.4 = kubernetes.default.svc.cluster
  DNS.5 = kubernetes.default.svc.cluster.local
  IP.1 = $masterIP
  IP.2 = $MASTER_CLUSTER_IP

  [ v3_ext ]
  authorityKeyIdentifier=keyid,issuer:always
  basicConstraints=CA:FALSE
  keyUsage=critical,digitalSignature,keyEncipherment,dataEncipherment
  extendedKeyUsage=serverAuth,clientAuth
  subjectAltName=@alt_names

EOF
}

create_cert_extension() {

  local extName="$1"
  local masterIP="$2"
  local MASTER_CLUSTER_IP="$3"

  echo "Creating $extName..."
  cat >"$extName" <<EOF

  [ v3_ext ]
  authorityKeyIdentifier=keyid,issuer:always
  basicConstraints=CA:FALSE
  keyUsage=critical,digitalSignature,keyEncipherment,dataEncipherment
  extendedKeyUsage=serverAuth,clientAuth
  subjectAltName=@alt_names

  [ alt_names ]
  DNS.1 = kubernetes
  DNS.2 = kubernetes.default
  DNS.3 = kubernetes.default.svc
  DNS.4 = kubernetes.default.svc.cluster
  DNS.5 = kubernetes.default.svc.cluster.local
  IP.1 = $masterIP
  IP.2 = $MASTER_CLUSTER_IP

EOF
}

# Generates the Certificate Signer Request (csr) and
# is signed by your Authority (CA) to get the required
# certificates (crt or pem)
gen_and_sign_cert() {
  extensionfile="$1"
  CAfile="$2"
  CAkey="$3"
  certName="$4"
  csrConf="$5"

  openssl genrsa -out "$certName".key 2048

  # Generate web server's private key and certificate signing request (CSR)
  if openssl req \
    -new \
    -nodes \
    -key "$certName".key \
    -out "$certName".csr \
    -config "$csrConf"; then

    echo -e "\nServer's Certificate Signing Request:\n"
    openssl req -in "$certName".csr -noout -text

  else
    exit 1
  fi

  # Use CA's private key to sign web server's CSR and get back the signed certificate
  if openssl x509 \
    -req \
    -in "$certName".csr \
    -CA "$CAfile" \
    -CAkey "$CAkey" \
    -CAcreateserial \
    -out "$certName".crt \
    -days 1000 \
    -extensions v3_ext \
    -extfile "$extensionfile" \
    -sha256; then

    echo -e "\nServer's signed certificate:\n"
    openssl x509 -in "$certName".crt -noout -text

  else
    exit 1
  fi

  sleep 3
}

counter=0
extFiles=(
  "$apiserverExtension"
  "$apiserverKubeletClientExtension"
  "$apiserverEtcdClientExtension"
  "$frontProxyClientExtension"
  "$etcdHealthcheckClientExtension"
  "$etcdPeerExtension"
  "$etcdServerExtension"
  "$kubeletExtension"
)
csrConfigs=(
  "$apiserverCsrConf"
  "$apiserverKubeletClientCsrConf"
  "$apiserverEtcdClientCsrConf"
  "$frontProxyClientCsrConf"
  "$etcdHealthcheckClientCsrConf"
  "$etcdPeerCsrConf"
  "$etcdServerCsrConf"
  "$kubeletCsrConf"
)
CN=(
  kube-apiserver
  kube-apiserver-kubelet-client
  kube-apiserver-etcd-client
  front-proxy-client
  kube-etcd-healthcheck-client
  "$HOSTNAME"
  "$MASTER_IP"
  system:node:kubernetes
)
ORG=(
  system
  system:masters
  system:masters
  system
  system:masters
  system
  system
  system:nodes
)

if [ -d "$csrConfDir" ]; then

  for conf in "${csrConfigs[@]}"; do

    ! [ -f "$conf" ] &&
      until ((counter == ${#csrConfigs[@]})); do
        create_csr_config \
          "${csrConfigs[counter]}" \
          "${CN[counter]}" \
          "${ORG[counter]}" \
          "$MASTER_IP" \
          10.96.0.1

        ((counter = counter + 1))
        sleep 1
      done
  done

else

  mkdir -p "$csrConfDir"

  until ((counter == ${#csrConfigs[@]})); do
    create_csr_config \
      "${csrConfigs[counter]}" \
      "${CN[counter]}" \
      "${ORG[counter]}" \
      "$MASTER_IP" \
      10.96.0.1

    ((counter = counter + 1))
    sleep 1
  done
fi

counter=0

if [ -d "$extDir" ]; then

  for ext in "${extFiles[@]}"; do

    ! [ -f "$ext" ] &&
      until ((counter == ${#extFiles[@]})); do

        create_cert_extension \
          "${extFiles[counter]}" \
          "$MASTER_IP" \
          10.96.0.10

        ((counter = counter + 1))
        sleep 1
      done
  done

else

  mkdir -p "$extDir"

  until ((counter == ${#extFiles[@]})); do

    create_cert_extension \
      "${extFiles[counter]}" \
      "$MASTER_IP" \
      10.96.0.10

    ((counter = counter + 1))
    sleep 1
  done
fi

apiServerArray=(
  "$apiserverExtension"
  "$asSignerCrt"
  "$asSignerKey"
  "$apiserverCertsName"
  "$apiserverCsrConf"
)
apiServerKubeCArray=(
  "$apiserverKubeletClientExtension"
  "$askcSignerCrt"
  "$askcSignerKey"
  "$apiserverKubeletClientCerts"
  "$apiserverKubeletClientCsrConf"
)
apiServerECEArray=(
  "$apiserverEtcdClientExtension"
  "$asecSignerCrt"
  "$asecSignerKey"
  "$apiserverEtcdClientCerts"
  "$apiserverEtcdClientCsrConf"
)
frontProxyCEArray=(
  "$frontProxyClientExtension"
  "$fpcSignerCrt"
  "$fpcSignerKey"
  "$frontProxyClientCerts"
  "$frontProxyClientCsrConf"
)
etcHCCArray=(
  "$etcdHealthcheckClientExtension"
  "$ehcSignerCrt"
  "$ehcSignerKey"
  "$etcdHealthcheckClientCerts"
  "$etcdHealthcheckClientCsrConf"
)
etcdPeerArray=(
  "$etcdPeerExtension"
  "$epeSignerCrt"
  "$epeSignerKey"
  "$etcdPeerCerts"
  "$etcdPeerCsrConf"
)
etcdServerArray=(
  "$etcdServerExtension"
  "$esrSignerCrt"
  "$esrSignerKey"
  "$etcdServerCerts"
  "$etcdServerCsrConf"
)
kubeletArray=(
  "$kubeletExtension"
  "$kubeSignerCrt"
  "$kubeSignerKey"
  "$kubeletCert"
  "$kubeletCsrConf"
)

entitiesArray=(
  "${apiServerArray[*]}"
  "${apiServerKubeCArray[*]}"
  "${apiServerECEArray[*]}"
  "${frontProxyCEArray[*]}"
  "${etcHCCArray[*]}"
  "${etcdPeerArray[*]}"
  "${etcdServerArray[*]}"
  "${kubeletArray[*]}"
)

echo -e "What certificates do you want to create?\n \
[(1)apiserver, (2)apiserver-kubelet-client, (3)apiserver-etcd-client,\
(4)front-proxy-client, (5)healthcheck-client, (6)peer, (7)server, (8)kubelet, (9)All]\n"

read -r choice

case $choice in

1)
  gen_and_sign_cert \
    "$apiserverExtension" \
    "$asSignerCrt" \
    "$asSignerKey" \
    "$apiserverCertsName" \
    "$apiserverCsrConf"
  ;;
2)
  gen_and_sign_cert \
    "$apiserverKubeletClientExtension" \
    "$askcSignerCrt" \
    "$askcSignerKey" \
    "$apiserverKubeletClientCerts" \
    "$apiserverKubeletClientCsrConf"
  ;;
3)
  gen_and_sign_cert \
    "$apiserverEtcdClientExtension" \
    "$asecSignerCrt" \
    "$asecSignerKey" \
    "$apiserverEtcdClientCerts" \
    "$apiserverEtcdClientCsrConf"
  ;;
4)
  gen_and_sign_cert \
    "$frontProxyClientExtension" \
    "$fpcSignerCrt" \
    "$fpcSignerKey" \
    "$frontProxyClientCerts" \
    "$frontProxyClientCsrConf"
  ;;
5)
  gen_and_sign_cert \
    "$etcdHealthcheckClientExtension" \
    "$ehcSignerCrt" \
    "$ehcSignerKey" \
    "$etcdHealthcheckClientCerts" \
    "$etcdHealthcheckClientCsrConf"
  ;;
6)
  gen_and_sign_cert \
    "$etcdPeerExtension" \
    "$epeSignerCrt" \
    "$epeSignerKey" \
    "$etcdPeerCerts" \
    "$etcdPeerCsrConf"
  ;;
7)
  gen_and_sign_cert \
    "$etcdServerExtension" \
    "$esrSignerCrt" \
    "$esrSignerKey" \
    "$etcdServerCerts" \
    "$etcdServerCsrConf"
  ;;
8)
  gen_and_sign_cert \
    "$kubeletExtension" \
    "$kubeSignerCrt" \
    "$kubeSignerKey" \
    "$kubeletCert" \
    "$kubeletCsrConf"
  ;;
9)
  for entity in "${entitiesArray[@]}"; do
    extensionConf="$(echo "$entity" | cut -d' ' -f1)"
    signerCert="$(echo "$entity" | cut -d' ' -f2)"
    signerKey="$(echo "$entity" | cut -d' ' -f3)"
    certsNames="$(echo "$entity" | cut -d' ' -f4)"
    csrConfig="$(echo "$entity" | cut -d' ' -f5)"

    gen_and_sign_cert \
      "$extensionConf" \
      "$signerCert" \
      "$signerKey" \
      "$certsNames" \
      "$csrConfig"
    sleep 2
  done
  ;;

*)
  echo "Anything?.."
  exit 0
  ;;

esac
