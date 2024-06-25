#!/bin/bash

REPO_URL=https://github.com/tundeafod/microservices-app.git

# Installing Helm
wget https://get.helm.sh/helm-v3.9.3-linux-amd64.tar.gz
tar xvf helm-v3.9.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm helm-v3.9.3-linux-amd64.tar.gz

# Kubernetes Dashboard
sudo su -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml" ubuntu
sleep 20

cat <<EOT > /home/ubuntu/admin-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/admin-user.yaml
sudo su -c "kubectl apply -f /home/ubuntu/admin-user.yaml" ubuntu

cat <<EOT > /home/ubuntu/cluster-binding.yaml
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

# ArgoCD namespace and deployment manifest
# sudo su -c "kubectl create namespace argocd" ubuntu
# sudo su -c "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.1-rc2/manifests/install.yaml" ubuntu

Stable version for ArgoCD
sudo su -c "kubectl create namespace argocd" ubuntu
sudo su -c "kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" ubuntu

# Ingress-nginx Helm Chart installation with Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace


# Monitoring
sudo su -c "kubectl create namespace monitoring" ubuntu
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana --namespace monitoring

sleep 30

# Token Creation for namespaces
sudo su -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode > /home/ubuntu/argopassword" ubuntu
sudo su -c "kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode > /home/ubuntu/grafpassword" ubuntu
sudo su -c "kubectl -n kubernetes-dashboard create token admin-user > /home/ubuntu/token" ubuntu

# Creating application namespace and deploying the application
sudo su -c "kubectl create namespace stage-boutique" ubuntu
git clone $REPO_URL
cd microservices-app/
git checkout main
sudo su -c "kubectl apply -f deployment-service.yml" ubuntu
cd
cd eks-code/

sudo su -c "kubectl create namespace prod-boutique" ubuntu
git clone $REPO_URL
cd microservices-app/
git checkout production
sudo su -c "kubectl apply -f deployment-service.yml" ubuntu
cd
cd eks-code/

# Cert-manager namespace and installation
sudo su -c "kubectl create namespace cert-manager" ubuntu
sudo su -c "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml" ubuntu
#helm repo add jetstack https://charts.jetstack.io
helm repo update
#helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.15.0 --set installCRDs=true

# Configure Issuers - Create a ClusterIssuer for Let's Encrypt
cat <<EOT > /home/ubuntu/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: afod2000@outlook.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - http01:
        ingress:
          class: nginx
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/cluster-issuer.yaml
sudo su -c "kubectl apply -f /home/ubuntu/cluster-issuer.yaml" ubuntu

# Create a Certificate
cat <<EOT > /home/ubuntu/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tundeafod-click-cert
  namespace: cert-manager
spec:
  secretName: afodsecret
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: tundeafod.click
  dnsNames:
  - tundeafod.click
  - "*.tundeafod.click"
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/certificate.yaml
sudo su -c "kubectl apply -f /home/ubuntu/certificate.yaml" ubuntu

# LoadBalancer Network configuration
cat <<EOT > /home/ubuntu/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - kubernetes-dashboard.tundeafod.click
    secretName: afodsecret
  rules:
  - host: kubernetes-dashboard.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.tundeafod.click
    secretName: afodsecret
  rules:
  - host: argocd.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: boutique-ingress
  namespace: stage-boutique
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - boutique.tundeafod.click
    secretName: afodsecret
  rules:
  - host: stage-boutique.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: boutique-ingress
  namespace: prod-boutique
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - boutique.tundeafod.click
    secretName: afodsecret
  rules:
  - host: prod-boutique.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-grafana-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
  - hosts:
    - prometheus.tundeafod.click
    - grafana.tundeafod.click
    secretName: afodsecret
  rules:
  - host: prometheus.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-server
            port:
              number: 80
  - host: grafana.tundeafod.click
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
EOT
sudo chown ubuntu:ubuntu /home/ubuntu/ingress.yaml
sudo su -c "kubectl apply -f /home/ubuntu/ingress.yaml" ubuntu

# sudo su -c "kubectl create secret tls afodsecret --cert=/path/to/tls.crt --key=/path/to/tls.key -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -" ubuntu
# sudo su -c "kubectl create secret tls afodsecret --cert=/path/to/tls.crt --key=/path/to/tls.key -n argocd --dry-run=client -o yaml | kubectl apply -f -" ubuntu
# sudo su -c "kubectl create secret tls afodsecret --cert=/path/to/tls.crt --key=/path/to/tls.key -n boutique --dry-run=client -o yaml | kubectl apply -f -" ubuntu
# sudo su -c "kubectl create secret tls afodsecret --cert=/path/to/tls.crt --key=/path/to/tls.key -n monitoring --dry-run=client -o yaml | kubectl apply -f -" ubuntu