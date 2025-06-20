# Production DevOps Deployment

This project demonstrates a complete DevOps implementation for deploying a Java SpringBoot application on AWS EKS using Terraform, Docker, and Kubernetes.

## Project Overview

This project demonstrates a production-ready deployment of a web application using modern DevOps practices and cloud-native technologies:

- **Infrastructure**: Terraform-managed AWS resources including VPC, EKS.
- **Containerization**: Docker images for the application.
- **Orchestration**: Kubernetes manifests for all application components
- **Storage**: EBS volumes for MySQL persistence
- **Networking**: Ingress controller with TLS termination
- **Scaling**: Horizontal Pod Autoscaler for dynamic scaling
- **Monitoring**: Prometheus and Grafana for observability

## Prerequisites

Before you begin, ensure you have the following tools installed:

- [AWS CLI](https://aws.amazon.com/cli/) - Configured with appropriate credentials
- [Terraform](https://www.terraform.io/downloads.html) - v1.0.0 or newer
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - For interacting with the Kubernetes cluster
- [Helm](https://helm.sh/docs/intro/install/) - For installing Kubernetes applications
- [eksctl](https://eksctl.io/installation/) - For additional EKS management

## Deployment Guide

### 1. Set up Terraform Backend (Optional but Recommended)

Before initializing Terraform, set up a remote backend to store the Terraform state securely:

**For Linux/macOS:**
```bash
# Make the script executable
chmod +x ./scripts/setup-terraform-backend.sh

# Run the script to create S3 bucket and DynamoDB table for state management
./scripts/setup-terraform-backend.sh
```

### 2. Infrastructure Provisioning with Terraform

Create the AWS infrastructure using Terraform:

```bash
# Initialize Terraform with the backend configuration
terraform init

# Preview the changes
terraform plan

# Apply the changes
terraform apply --auto-approve
```

### 3. Configure kubectl to use the new EKS cluster

```bash
aws eks --region eu-north-1 update-kubeconfig --name prod-demo-cluster
```

### 4. Set up OIDC provider for EKS

```bash
eksctl utils associate-iam-oidc-provider --region eu-north-1 --cluster prod-demo-cluster --approve
```

### 5. Create IAM service account for EBS CSI driver

```bash
eksctl create iamserviceaccount \
  --region=eu-north-1 \
  --cluster=prod-demo-cluster \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-service-accounts
```

### 6. Install EBS CSI driver

```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.11"
```

### 7. Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### 8. Install cert-manager for SSL/TLS certificates

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

### 9. Create namespace for the application

```bash
kubectl create namespace bankapp
```

### 10. Deploy the application

```bash
kubectl apply -f kubernetes/
```

### 11. Access the application

```bash
# Get the Ingress external IP/hostname
kubectl get ingress -n bankapp
```

### 12. Clean up resources when done

```bash
# Destroy all resources created by Terraform
terraform destroy --auto-approve
```

## Configuration

### Terraform Backend

The project uses an S3 bucket with DynamoDB for state locking to store the Terraform state securely. This allows for team collaboration and prevents state corruption. The configuration is in `terraform/backend.tf`.

To customize the backend configuration:
1. Edit the bucket name and DynamoDB table name in `terraform/backend.tf`
2. Update the same values in the setup scripts in the `scripts/` directory

## Scaling

The application is configured with Horizontal Pod Autoscalers (HPA). The HPA will scale the number of pods based on CPU utilization:

- Min replicas: 1
- Max replicas: 5
- Target CPU utilization: 70%

## Storage

The application uses AWS EBS volumes for persistent storage with the following configuration:

- Storage Class: `ebs-sc` using the EBS CSI driver
- Volume Type: gp3
- File System: ext4
- Reclaim Policy: Retain

## Monitoring

Add Prometheus and Grafana to provide observability for your Kubernetes cluster and applications.

### Components

- **Prometheus**: A time-series database for storing metrics
- **Grafana**: A visualization tool for creating dashboards
- **Node Exporter**: Collects hardware and OS metrics from Kubernetes nodes
- **Kube State Metrics**: Provides metrics about the state of Kubernetes objects

### Configuration

The monitoring stack is configured in [monitoring/values.yml](./monitoring/values.yml) with the following settings:

- Prometheus uses persistent storage (5Gi) with the `ebs-sc` StorageClass
- Grafana is enabled and exposed via a LoadBalancer service
- Node Exporter is configured to collect metrics from all nodes
- Kube State Metrics is enabled to collect Kubernetes object metrics
- Alertmanager is disabled (can be enabled if needed)

### Deployment

#### Add the Prometheus community Helm repository
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

#### Install Prometheus and Grafana using the custom values file
```bash
helm install monitoring prometheus-community/kube-prometheus-stack -f monitoring/values.yml -n monitoring --create-namespace
```

#### Expose Serices
```bash
kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

kubectl patch svc monitoring-kube-state-metrics -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

kubectl patch svc monitoring-prometheus-node-exporter -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
```

### Access the application
```bash
kubectl get svc -n monitoring
```

Go to graphana and add prometheus as data source , and save it.

In dashboard section you will see pre-configured dashboards.

---

