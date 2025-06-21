# HashiCorp Vault Setup Guide

This guide provides step-by-step instructions for setting up HashiCorp Vault on Kubernetes with high availability configuration.

## Prerequisites
- Kubernetes cluster with kubectl configured
- Helm installed
- AWS EBS CSI driver (for storage class)

## Setup Steps

### 1. Create Namespace
```bash
kubectl create ns vault
```

### 2. Add HashiCorp Helm Repository
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

### 3. Create Storage Class for Vault
```bash
kubectl apply -f storage.yml
```

### 4. Install Vault with Custom Configuration
```bash
helm install vault hashicorp/vault -n vault -f vault-values.yml
```

Monitor pod creation:
```bash
kubectl get pods -n vault
```

### 5. Expose Vault Using LoadBalancer
```bash
kubectl apply -f service.yml
```

### 6. Initialize Vault (Run Only Once)
```bash
kubectl exec -n vault -it vault-0 -- vault operator init
```

This command will generate:
- 5 unseal keys
- 1 Initial Root Token

> **IMPORTANT**: Copy and securely store these keys and the root token. They are required for unsealing Vault and administrative access.

### 7. Unseal Vault on All Pods

Initially, all Vault pods are in a `Sealed` state. You must unseal each pod using at least 3 of the 5 unseal keys generated in the previous step.

Unseal each Vault pod:
```bash
# Unseal the first pod
kubectl exec -n vault -it vault-0 -- vault operator unseal <key>

# Unseal the second pod
kubectl exec -n vault -it vault-1 -- vault operator unseal <key>

# Unseal the third pod
kubectl exec -n vault -it vault-2 -- vault operator unseal <key>
```

> Repeat for every with minimum 3 keys.

### 8. Login To Vault
```bash
kubectl exec -n vault -it vault-0 -- vault login <root-token>
```

### 9. Enable Kubernetes Authentication
```bash
kubectl exec -n vault -it vault-0 -- vault auth enable kubernetes
```

### 10. Create Service Account for Application Pods
```bash
kubectl create ns bankapp
kubectl create serviceaccount vault-auth -n bankapp
```

### 11. Configure Kubernetes Auth in Vault

Extract required information:
```bash
SERVICE_ACCOUNT_NAME=vault-auth
NAMESPACE=bankapp

# JWT TOKEN
TOKEN_REVIEW_JWT=$(kubectl get secret $(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -o jsonpath="{.secrets[0].name}") -n $NAMESPACE -o jsonpath="{.data.token}" | base64 --decode)

# Kubernetes API HOST
KUBE_HOST=$(kubectl config view --raw -o=jsonpath='{.clusters[0].cluster.server}')

# Kubernetes CA Cert
KUBE_CA_CERT=$(kubectl get secret $(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -o jsonpath="{.secrets[0].name}") -n $NAMESPACE -o jsonpath="{.data['ca.crt']}" | base64 --decode)
```

Configure Kubernetes authentication:
```bash
kubectl exec -n vault -it vault-0 -- vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert="$KUBE_CA_CERT"
```

### 12. Apply Vault Policy
```bash
kubectl cp app-policy.hcl vault/vault-0:/tmp/app-policy.hcl
kubectl exec -n vault -it vault-0 -- vault policy write app-policy /tmp/app-policy.hcl
```

### 13. Create Role in Vault to Map Pod to Policy
```bash
kubectl exec -n vault -it vault-0 -- vault write auth/kubernetes/role/vault-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces="bankapp" \
    policies=app-policy \
    ttl=24h 
```

### 14. Store Secret in Vault

#### Enable `KV V2` Engine (Used for Secrets Versioning)
```bash
kubectl exec -n vault -it vault-0 -- vault secrets enable -path=secret -version=2 kv 
```

#### Store Secrets in Vault
```bash
# Store MySQL secrets
kubectl exec -n vault -it vault-0 -- vault kv put secret/mysql MYSQL_DATABASE=bankappdb MYSQL_ROOT_PASSWORD=Test@123

# Store frontend application secrets
kubectl exec -n vault -it vault-0 -- vault kv put secret/frontend SPRING_DATASOURCE_USERNAME=root SPRING_DATASOURCE_PASSWORD=Test@123
```

## Next Steps

After completing this setup, your applications can access secrets from Vault using the Vault Agent Injector or direct API calls.

