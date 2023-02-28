#!/usr/bin/env bash

# 
# You can check and explore your cluster with this simply script
# just remeber to set your appropiate settings.
# 

# Checkall possible clusters, as you .kubeconfig may have multiple contexts:
kubectl config view -o jsonpath='{"kubernetes"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'

# Select name of cluster you want to interact with from above output:
export clusterName="kubernetes"

# Point to the API server referring the cluster name
APISERVER="$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$clusterName\")].cluster.server}")"

# Create a secret to hold a token for the default service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata: 
  name: default-token
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
EOF

# Wait for the token controller to populate the secret with a token:
while ! kubectl describe secret default-token | grep -E '^token' >/dev/null; do

  echo "waiting for token..." >&2
  sleep 1

done

# Get the token value
token="$(kubectl get secret default-token -o jsonpath='{.data.token}' | base64 --decode)"

# Explore the API with TOKEN
curl -X GET "$APISERVER"/api --header "Authorization: Bearer $token" --insecure
