# Langfuse Deployment Manifests

Kubernetes deployment manifests for [Langfuse](https://langfuse.com) - an open-source LLM observability and analytics platform.

## Architecture

This deployment uses:
- **Langfuse Helm Chart** from `https://langfuse.github.io/langfuse-k8s`
- **CloudNativePG** for PostgreSQL database cluster (3 replicas)
- **Redis** for caching (bundled with Helm chart)
- **ClickHouse** for analytics and time-series data
- **MinIO** for S3-compatible object storage
- **Gateway API HTTPRoute** for ingress via Cilium Gateway

## Components

### Core Services
- **langfuse-web** (2 replicas) - Web application on port 3000
- **langfuse-worker** (1 replica) - Background job processor

### Data Layer
- **PostgreSQL Cluster** (3 instances) - Primary database via CloudNativePG
- **Redis** (standalone) - Session and data caching
- **ClickHouse** (1 shard) - Analytics database with ZooKeeper
- **MinIO** (standalone) - Object storage for uploads and exports

### Networking
- **HTTPRoute**: `langfuse.animaniacs.farh.net` via internal gateway
- **Service**: ClusterIP on port 3000

## Files

- `helmrepository.yaml` - Langfuse Helm chart repository
- `helmrelease.yaml` - Langfuse application configuration
- `postgres-cluster.yaml` - CloudNativePG cluster definition
- `httproute.yaml` - Gateway API ingress route
- `sealedsecrets.yaml` - Sealed secrets (PLACEHOLDERS - must be sealed)
- `kustomization.yaml` - Kustomize resource list

## Prerequisites

Before deploying, you must:

1. **Seal all secrets** (replace PLACEHOLDER values in `sealedsecrets.yaml`)
2. **Ensure CloudNativePG operator is installed** in the cluster
3. **Verify storage classes** (`ceph-block`) are available
4. **Configure Ceph S3 credentials** for PostgreSQL backups

## Sealing Secrets

All secrets use placeholders and must be sealed with actual credentials:

### 1. Langfuse Application Secrets
```bash
kubectl create secret generic langfuse-secrets --namespace=langfuse \
  --from-literal=encryptionKey=$(openssl rand -hex 32) \
  --from-literal=salt=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml
```

### 2. PostgreSQL Database Credentials
```bash
kubectl create secret generic langfuse-db-credentials --namespace=langfuse \
  --from-literal=username=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml
```

### 3. Redis Password
```bash
kubectl create secret generic langfuse-redis-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml
```

### 4. ClickHouse Password
```bash
kubectl create secret generic langfuse-clickhouse-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml
```

### 5. MinIO Credentials
```bash
kubectl create secret generic langfuse-minio-credentials --namespace=langfuse \
  --from-literal=root-user=admin \
  --from-literal=root-password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml
```

### 6. PostgreSQL S3 Backup Credentials
```bash
# Get Ceph credentials from existing secret or create new
kubectl create secret generic langfuse-postgres-backup-s3 --namespace=langfuse \
  --from-literal=ACCESS_KEY_ID=<ceph-access-key> \
  --from-literal=ACCESS_SECRET_KEY=<ceph-secret-key> \
  --dry-run=client -o yaml | kubeseal --format yaml
```

## Configuration

### Resource Limits
- **Web**: 100m CPU request, 256Mi memory request, 512Mi memory limit
- **Worker**: 50m CPU request, 128Mi memory request, 256Mi memory limit
- **PostgreSQL**: 100m CPU request, 512Mi memory request, 1Gi memory limit
- **Redis**: 50m CPU request, 64Mi memory request, 128Mi memory limit
- **ClickHouse**: 100m CPU request, 512Mi memory request, 1Gi memory limit
- **MinIO**: 50m CPU request, 128Mi memory request, 256Mi memory limit

### Storage
- **PostgreSQL**: 20Gi (ceph-block)
- **Redis**: 1Gi (ceph-block)
- **ClickHouse**: 10Gi (ceph-block)
- **ZooKeeper**: 2Gi (ceph-block)
- **MinIO**: 20Gi (ceph-block)

### PostgreSQL Backups
- **Destination**: Ceph S3 (`s3://langfuse-postgres-backups/`)
- **Retention**: 30 days
- **Compression**: gzip (WAL and data)
- **Volume Snapshots**: 7 days retention

## Deployment

This repository is deployed via Flux GitOps:

```yaml
# In kubernetes cluster config
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: langfuse
  namespace: langfuse
spec:
  sourceRef:
    kind: GitRepository
    name: langfuse
  path: ./
```

## Access

After deployment, Langfuse will be available at:
- **URL**: https://langfuse.animaniacs.farh.net
- **Initial Setup**: Navigate to URL and create first organization/account

## Monitoring

- **PostgreSQL**: Monitoring enabled via podMonitor (Prometheus)
- **Langfuse Logs**: JSON format, info level
- **Telemetry**: Enabled (reports basic usage stats to Langfuse)

## Scaling

### Manual Scaling
Adjust replicas in `helmrelease.yaml`:
```yaml
langfuse:
  replicas: 2
web:
  replicas: 2
worker:
  replicas: 1
```

### Auto-scaling
The chart supports KEDA, HPA, and VPA. Enable in `helmrelease.yaml` values.

## Maintenance

### Database Migrations
Langfuse automatically runs migrations on startup. CloudNativePG handles PostgreSQL upgrades.

### Backups
- **PostgreSQL**: Automatic backups to Ceph S3 every day
- **Recovery**: Use CloudNativePG restore procedures

### Upgrades
Update `helmrelease.yaml` chart version and Flux will reconcile:
```yaml
chart:
  spec:
    chart: langfuse
    version: "1.1.x"  # Update version
```

## Optional Features

### SMTP Email Notifications
Uncomment and configure in `helmrelease.yaml`:
```yaml
langfuse:
  smtp:
    connectionUrl: "smtp://user:pass@smtp.example.com:587"
    fromAddress: "langfuse@example.com"
```

### SSO Authentication
Configure auth providers in `helmrelease.yaml`:
```yaml
langfuse:
  auth:
    disableUsernamePassword: true
    providers:
      azureAd:
        clientId: "<client-id>"
        clientSecret: "<client-secret>"
        tenantId: "<tenant-id>"
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n langfuse
```

### View Logs
```bash
# Web application
kubectl logs -n langfuse -l app.kubernetes.io/component=web

# Worker
kubectl logs -n langfuse -l app.kubernetes.io/component=worker

# PostgreSQL
kubectl logs -n langfuse langfuse-postgres-1
```

### Database Connection Issues
```bash
# Check PostgreSQL cluster status
kubectl get cluster -n langfuse langfuse-postgres

# Check database credentials
kubectl get secret -n langfuse langfuse-db-credentials -o yaml
```

### HelmRelease Status
```bash
kubectl get helmrelease -n langfuse langfuse -o yaml
```

## References

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse Self-hosting Guide](https://langfuse.com/self-hosting)
- [Langfuse Kubernetes Deployment](https://langfuse.com/self-hosting/deployment/kubernetes-helm)
- [Langfuse Helm Chart](https://github.com/langfuse/langfuse-k8s)
- [CloudNativePG Documentation](https://cloudnative-pg.io)
