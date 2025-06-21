# Production Ready DevOps

This project demonstrates a complete DevOps implementation for deploying a secure, scalable Java SpringBoot banking application on AWS EKS using Terraform, Docker, and Kubernetes.

## Project Overview

This project showcases a production-ready deployment of a banking web application using modern DevOps practices and cloud-native technologies:

- **Infrastructure as Code**: Terraform-managed AWS resources including VPC, EKS, IAM roles, and security groups
- **Containerization**: Multi-stage Docker builds for optimized, secure application images
- **Orchestration**: Kubernetes manifests for all application components with proper security contexts
- **Persistence**: StatefulSets with EBS volumes for MySQL database reliability
- **Networking**: NGINX Ingress controller with TLS termination via Let's Encrypt
- **Scaling**: Horizontal Pod Autoscaler for dynamic scaling based on CPU utilization
- **Monitoring**: Prometheus and Grafana for comprehensive observability
- **Security**: Proper secret management with HashiCorp Vault and network policies

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://www.terraform.io/downloads.html) | v1.0.0+ | Infrastructure as Code tool to provision AWS resources |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Latest | Command-line tool for interacting with the Kubernetes cluster |
| [Helm](https://helm.sh/docs/intro/install/) | v3.0.0+ | Package manager for Kubernetes to install applications |
| [eksctl](https://eksctl.io/installation/) | Latest | Command-line tool for creating and managing EKS clusters |


## Deployment Guide

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/DevOps-Prod.git
cd DevOps-Prod
```

### 2. Set up Terraform Backend (Optional but Recommended)

Before initializing Terraform, set up a remote backend to store the Terraform state securely:

**For Linux/macOS:**
```bash
# Make the script executable
chmod +x ./scripts/setup-terraform-backend.sh

# Run the script to create S3 bucket and DynamoDB table for state management
./scripts/setup-terraform-backend.sh
```

**For Windows:**
```powershell
# Run the script using PowerShell
& bash ./scripts/setup-terraform-backend.sh
```

### 3. Infrastructure Provisioning with Terraform

Create the AWS infrastructure using Terraform:

```bash
# Navigate to the terraform directory
cd terraform

# Initialize Terraform with the backend configuration
terraform init

# Preview the changes
terraform plan

# Apply the changes
terraform apply --auto-approve
```

### 4. Configure kubectl to use the new EKS cluster

```bash
aws eks --region eu-north-1 update-kubeconfig --name eks-cluster
```

### 5. Set up OIDC provider for EKS

```bash
eksctl utils associate-iam-oidc-provider --region eu-north-1 --cluster eks-cluster --approve
```

### 6. Create IAM service account for EBS CSI driver

```bash
eksctl create iamserviceaccount \
  --region=eu-north-1 \
  --cluster=eks-cluster \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-service-accounts
```

### 7. Install EBS CSI driver

```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.11"
```

### 8. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### 9. Install cert-manager for SSL/TLS certificates

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# Apply the ClusterIssuer for Let's Encrypt
kubectl apply -f kubernetes-manifests/cert-issuer.yml
```

### 10. Set Up HashiCorp Vault for Secrets Management
Follow the [HashiCorp Vault README](./haspicorp-vault/README.md) for complete setup instructions.


### 11. Create namespace and deploy the application

```bash
# Create the namespace
kubectl create namespace bankapp

# Apply the Service Account
kubectl apply -f service-account.yml

# Apply the storage class first
kubectl apply -f kubernetes-manifests/storage.yml

# Deploy MySQL database
kubectl apply -f kubernetes-manifests/mysql.yml

# Wait for MySQL to be ready
kubectl wait --for=condition=ready pod -l app=mysql -n bankapp --timeout=120s

# Deploy the banking application and related resources
kubectl apply -f kubernetes-manifests/bankapp.yml
kubectl apply -f kubernetes-manifests/hpa.yml
kubectl apply -f kubernetes-manifests/ingress.yml
```

### 12. Set Up Monitoring
Follow the [Monitoring README](./monitoring/README.md) to set up Prometheus and Grafana for comprehensive monitoring.

### 13. Access the application

```bash
# Get the Ingress external IP/hostname
kubectl get ingress -n bankapp

# Get the Grafana service URL for monitoring
kubectl get svc monitoring-grafana -n monitoring
```

Access the banking application using the hostname configured in the ingress (you'll need to add an entry to your hosts file or configure a real domain to point to the ingress IP).

### 14. Clean up resources when done

```bash
# Delete Kubernetes resources first
kubectl delete namespace bankapp
kubectl delete namespace monitoring

# Navigate to terraform directory
cd terraform

# Destroy all AWS resources created by Terraform
terraform destroy --auto-approve
```

---