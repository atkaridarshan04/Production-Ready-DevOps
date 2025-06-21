# Project Components

This document provides detailed information about the various components and best practices implemented in this DevOps project.

## Security Best Practices

This project implements several security best practices to ensure the application and infrastructure are protected:

### Container Security

- **Multi-stage Docker builds**: Minimizes attack surface by using separate build and runtime images
- **Non-root users**: Application containers run as non-privileged users
- **Read-only file systems**: When possible, containers use read-only file systems
- **Resource limits**: All containers have CPU and memory limits defined
- **Security contexts**: Pods and containers have proper security contexts configured

### Kubernetes Security

- **Secret management**: Sensitive data stored in Kubernetes Secrets (base64 encoded)
- **Network policies**: Control traffic flow between pods (not shown in manifests but recommended)
- **Pod security contexts**: Drop unnecessary capabilities and run as non-root
- **Liveness and readiness probes**: Ensure proper application health monitoring

### Infrastructure Security

- **VPC isolation**: Application runs in a dedicated VPC with proper subnets
- **Security groups**: Restrict network access to necessary ports only
- **IAM roles**: Principle of least privilege for service accounts and roles
- **TLS termination**: HTTPS traffic with certificates from Let's Encrypt

### Database Security

- **StatefulSet**: Ensures stable, predictable database deployment
- **Secure credentials**: Database passwords stored in Kubernetes Secrets
- **Resource isolation**: Dedicated resources for database workloads

## Infrastructure Components

### Terraform Configuration

The infrastructure is defined using Terraform with the following key components:

- **VPC**: Isolated network environment with public subnets across two availability zones
- **EKS Cluster**: Managed Kubernetes control plane with appropriate IAM roles
- **Node Group**: EC2 instances (t2.medium) for running containerized workloads
- **Security Groups**: Network access controls for cluster and node communication
- **IAM Roles**: Proper permissions for EKS and EBS CSI driver integration

### Terraform Backend

The project uses an S3 bucket with DynamoDB for state locking to store the Terraform state securely. This allows for team collaboration and prevents state corruption. The configuration is in `terraform/backend.tf`.

To customize the backend configuration:
1. Edit the bucket name and DynamoDB table name in `terraform/backend.tf`
2. Update the same values in the setup scripts in the `scripts/` directory

## Kubernetes Resources

### Application Deployment

The banking application is deployed with the following Kubernetes resources:

- **Deployment**: Manages the application pods with proper resource limits and security contexts
- **Service**: Exposes the application internally on port 8000
- **ConfigMap**: Stores database connection information
- **Secret**: Securely stores database credentials
- **Ingress**: Configures external access with TLS termination

### Database Deployment

The MySQL database is deployed as a StatefulSet for data persistence:

- **StatefulSet**: Ensures stable network identities and persistent storage
- **Service**: Headless service for direct pod addressing
- **PersistentVolumeClaim**: Requests storage from the EBS storage class
- **Secret**: Stores database root password and database name

## Scaling

The application is configured with Horizontal Pod Autoscalers (HPA). The HPA will scale the number of pods based on CPU utilization:

- Min replicas: 1
- Max replicas: 5
- Target CPU utilization: 70%

This ensures the application can handle varying loads while efficiently using resources.

## Storage

The application uses AWS EBS volumes for persistent storage with the following configuration:

- **Storage Class**: `ebs-sc` using the EBS CSI driver
- **Volume Type**: gp3 for better performance
- **File System**: ext4
- **Reclaim Policy**: Retain (preserves data even after PVC deletion)
- **Volume Binding Mode**: WaitForFirstConsumer (volumes are provisioned when pods are scheduled)

## Secrets Management with HashiCorp Vault

This project implements HashiCorp Vault for secure secrets management, providing a centralized solution for storing and accessing sensitive information.

### Vault Architecture

- **High Availability**: Deployed as a StatefulSet with multiple replicas for reliability
- **Storage Backend**: Uses AWS EBS volumes for persistent storage of encrypted secrets
- **Authentication**: Uses Kubernetes Service Account Token authentication

### Key Features

- **Dynamic Secrets**: Generates short-lived, on-demand database credentials
- **Secret Versioning**: Maintains history of secrets with the KV v2 secrets engine
- **Access Control**: Fine-grained policies control which applications can access specific secrets
- **Audit Logging**: Records all access attempts for security compliance

### Integration with Applications

- **Vault Agent Injector**: Automatically injects secrets into pods as files or environment variables
- **Service Account Binding**: Applications authenticate to Vault using their Kubernetes service account

## Monitoring and Observability

The project includes a comprehensive monitoring stack based on Prometheus and Grafana to provide observability for the Kubernetes cluster and applications.

### Components

| Component | Purpose | Configuration |
|-----------|---------|---------------|
| **Prometheus** | Time-series database for metrics collection and storage | Configured with persistent storage (5Gi) using EBS |
| **Grafana** | Visualization platform for metrics and dashboards | Exposed via LoadBalancer with pre-configured dashboards |
| **Node Exporter** | Collects hardware and OS metrics from Kubernetes nodes | Deployed as DaemonSet to monitor all cluster nodes |
| **Kube State Metrics** | Provides metrics about the state of Kubernetes objects | Collects metrics about pods, deployments, etc. |
| **Service Monitors** | Custom resources that define scraping configurations | Automatically discover and monitor services |

### Key Metrics Monitored

- **Infrastructure Metrics**: CPU, memory, disk, and network usage
- **Kubernetes Metrics**: Pod status, deployment health, and resource utilization
- **Application Metrics**: JVM metrics, HTTP request rates, and response times
- **Database Metrics**: MySQL connection pool, query performance, and availability

### Configuration

The monitoring stack is configured in [monitoring/values.yml](./monitoring/values.yml) with the following settings:

- Prometheus uses persistent storage (5Gi) with the `ebs-sc` StorageClass
- Grafana is enabled and exposed via a LoadBalancer service
- Node Exporter is configured to collect metrics from all nodes
- Kube State Metrics is enabled to collect Kubernetes object metrics
- Alertmanager is disabled by default (can be enabled if needed)

---