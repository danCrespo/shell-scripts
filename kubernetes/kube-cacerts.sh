#!/usr/bin/env bash

##
## Creates self-signed CA certificates to customize
## your kubernetes deployment passing you own certificates
## signed for your CA to the `kubeadm init` command.
##

certsDir=/path/to/certs
sslCert=/etc/ssl/certs/ca.pem
sslFrontPCert=/etc/ssl/certs/front-proxy-ca.pem
sslEtcdCert=/etc/ssl/certs/etcd.ca.pem
cacertificates=/usr/local/share/ca-certificates
sharecacertificates=/usr/share/ca-certificates/mozilla

kubernetesCN="/CN=kubernetes-ca"
kubernetesCACert="$certsDir/ca"

frontProxyCN="/CN=kubernetes-front-proxy-ca"
frontProxyCACert="$certsDir/front-proxy-ca"

etcdCN="/CN=etcd-ca"
etcdCACert="$certsDir/etcd/ca"

if ! [ "$(id -u)" = 0 ]; then
  echo -e "You must be root to run this script.\n \
   Try again and use \"sudo\" command." >&2
  exit 1
fi

gen_ca_crt() {

  local certName="$1"
  local subject="$2"

  if openssl req -x509 \
    -sha256 \
    -days 1000 \
    -nodes \
    -newkey rsa:2048 \
    -keyout "$certName".key \
    -out "$certName".crt \
    -subj "$subject"; then

    echo -e "\nCA Certificate:\n"
    openssl x509 -in "$certName".crt -noout -text

  else
    return 1

  fi

  case "$subject" in

  "$kubernetesCN")
    if [ -f "$sslCert" ]; then
      rm "$sslCert"
    fi

    if [ -f "$cacertificates"/ca.crt ]; then
      rm "$cacertificates"/ca.crt
    fi
    if [ -f "$sharecacertificates"/ca.crt ]; then
      rm "$sharecacertificates"/ca.crt
    fi

    cp -a "$certName".crt "$cacertificates" &&
    cp -a "$certName".crt "$sharecacertificates" &&
      update-ca-certificates
    ;;

  "$frontProxyCN")
    if [ -f "$sslFrontPCert" ]; then
      rm "$sslFrontPCert"
    fi

    if [ -f "$cacertificates"/front-proxy-ca.crt ]; then
      rm "$cacertificates"/front-proxy-ca.crt
    fi
    if [ -f "$sharecacertificates"/front-proxy-ca.crt ]; then
      rm "$sharecacertificates"/front-proxy-ca.crt
    fi

    cp -a "$certName".crt "$cacertificates" &&
    cp -a "$certName".crt "$sharecacertificates" &&
      update-ca-certificates
    ;;

  "$etcdCN")
    if [ -f "$sslEtcdCert" ]; then
      rm "$sslEtcdCert"
    fi

    if [ -f "$cacertificates"/etcd.ca.crt ]; then
      rm "$cacertificates"/etcd.ca.crt
    fi
    if [ -f "$sharecacertificates"/etcd.ca.crt ]; then
      rm "$sharecacertificates"/etcd.ca.crt
    fi

    cp -sa "$certName".crt "$cacertificates"/etcd.ca.crt &&
    cp -sa "$certName".crt "$sharecacertificates"/etcd.ca.crt &&
      update-ca-certificates
    ;;
  esac

}

if ! [ -d "$certsDir"/etcd ]; then
  mkdir -p "$certsDir"/etcd
fi

kubeArray=(
  "$kubernetesCACert"
  "$kubernetesCN"
)
frontProxyArray=(
  "$frontProxyCACert"
  "$frontProxyCN"
)
etcdArray=(
  "$etcdCACert"
  "$etcdCN"
)

entitiesArray=(
  "${kubeArray[*]}"
  "${frontProxyArray[*]}"
  "${etcdArray[*]}"
)

echo -e "What certificates do you want to create?\n \
[(1)kubernetes-ca, (2)front-proxy-ca, (3)etcd-ca, (4)All]\n"

read -r choice

case "$choice" in

1)
  gen_ca_crt "$kubernetesCACert" "$kubernetesCN"
  ;;
2)
  gen_ca_crt "$frontProxyCACert" "$frontProxyCN"
  ;;
3)
  gen_ca_crt "$etcdCACert" "$etcdCN"
  ;;
4)
  for entity in "${entitiesArray[@]}"; do
    cacert="$(echo "$entity" | cut -d' ' -f1)"
    cacn="$(echo "$entity" | cut -d' ' -f2)"
    gen_ca_crt "$cacert" "$cacn"
    sleep 2
  done
  ;;
*)
  echo "Anything?..."
  exit 0
  ;;

esac
