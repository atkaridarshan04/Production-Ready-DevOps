# Monitoring Setup Guide

This guide provides instructions for setting up Prometheus and Grafana monitoring for your Kubernetes cluster.

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus and Grafana stack
helm install monitoring prometheus-community/kube-prometheus-stack -f monitoring/values.yml -n monitoring

# Expose services as LoadBalancer 
kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

kubectl patch svc monitoring-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
```


## Accessing Grafana

Access Grafana at the external IP with default credentials:
- **Username**: admin
- **Password**: password (as configured in values.yml)

## Configuring Grafana

To configure Grafana for monitoring:

1. Navigate to the "Configuration" menu and select "Data Sources"
2. Click "Add data source" and choose "Prometheus" from the list
3. Enter the Prometheus server URL in the "URL" field
4. Click "Save & Test" to verify the connection

## Using Dashboards

Once configured, you can access pre-built dashboards by:
1. Going to the "Dashboards" section
2. Selecting "Browse" to view all available dashboard templates
3. Exploring the various pre-configured monitoring dashboards

## Available Metrics

The monitoring stack provides visibility into:
- Node-level metrics (CPU, memory, disk, network)
- Pod and container metrics
- Kubernetes control plane metrics
- Application-specific metrics (when configured)