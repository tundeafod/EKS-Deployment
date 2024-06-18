#!/bin/bash

REPO_URL=https://github.com/tundeafod/boutique-microservices-application.git

#installing helm
wget https://get.helm.sh/helm-v3.9.3-linux-amd64.tar.gz
tar xvf helm-v3.9.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin
rm helm-v3.9.3-linux-amd64.tar.gz

sudo su -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml" ubuntu
sudo cat <<EOT> /home/ubuntu/admin-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/admin-user.yaml 
sudo su -c "kubectl apply -f /home/ubuntu/admin-user.yaml" ubuntu

sudo cat <<EOT> /home/ubuntu/cluster-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOT

sudo chown ubuntu:ubuntu /home/ubuntu/cluster-binding.yaml 
sudo su -c "kubectl apply -f /home/ubuntu/cluster-binding.yaml" ubuntu
sleep 30
sudo su -c "kubectl -n kubernetes-dashboard create token admin-user > /home/ubuntu/token" ubuntu

sudo su -c "kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'" ubuntu

#creating stage namespace
sudo su -c "kubectl create namespace stage" ubuntu
git clone $REPO_URL
cd boutique-microservices-application/
sudo su -c "kubectl apply -f application-manifest.yaml" ubuntu

#creating prod namespace
sudo su -c "kubectl create namespace prod" ubuntu
git clone $REPO_URL
cd boutique-microservices-application/
sudo su -c "kubectl apply -f application-manifest.yaml" ubuntu
cd
cd eks-code/

#creating argocd namespace
sudo su -c "kubectl create namespace argocd" ubuntu

#deploy argocd into cluster
sudo su -c "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml" ubuntu

#patch loadbalancer
sudo su -c "kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'" ubuntu
sleep 40

sudo su -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d > /home/ubuntu/argopassword" ubuntu

sudo su -c "kubectl create namespace monitoring" ubuntu
sudo su -c "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts" ubuntu
sudo su -c "helm repo update" ubuntu
sudo su -c "helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring" ubuntu


sudo su -c "kubectl patch svc prometheus-stack-kube-prom-operator -n monitoring -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'" ubuntu

sudo su -c "kubectl patch svc prometheus-stack-grafana -n monitoring -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'" ubuntu


# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update
# helm install my-ingress-nginx ingress-nginx/ingress-nginx