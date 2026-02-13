# Langfuse Deployment Manifests

Kubernetes manifests for deploying Langfuse LLM observability platform to the Animaniacs cluster.

## Architecture

Langfuse is deployed with the following components:

### Core Services
- **Web (2 replicas)**: Frontend application serving the Langfuse UI
- **Worker (1 replica)**: Background job processor for async tasks

### Data Layer
- **PostgreSQL (CloudNativePG)**: Primary database with 3-instance HA cluster
  - 20Gi storage on Ceph block storage
  - Automated backups to Ceph S3 (retention: 30 days)
  - Connection pooling and monitoring enabled
- **Redis (standalone)**: Caching layer for session and application data
  - 1Gi persistent storage
- **ClickHouse (single shard)**: Analytics database for trace data
  - 10Gi persistent storage
  - Includes ZooKeeper for coordination (1 replica, 2Gi storage)

### Storage
- **Ceph S3 (RGW)**: Object storage for file uploads and exports
  - Endpoint: `http://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local`
  - Public URL: `https://object.farh.net`
  - Bucket: `langfuse`
  - Credentials auto-created by CephObjectStoreUser and reflected via reflector

## Storage Allocation

Total persistent storage: **~33Gi**
- PostgreSQL: 20Gi (Ceph block)
- ClickHouse: 10Gi (Ceph block)
- ZooKeeper: 2Gi (Ceph block)
- Redis: 1Gi (Ceph block)

## Resource Requests

- **Web**: 2 × (100m CPU, 256Mi memory, 512Mi limit)
- **Worker**: 1 × (50m CPU, 128Mi memory, 256Mi limit)
- **PostgreSQL**: 3 × (100m CPU, 512Mi memory, 1Gi limit)
- **Redis**: 1 × (50m CPU, 64Mi memory, 128Mi limit)
- **ClickHouse**: 1 × (100m CPU, 512Mi memory, 1Gi limit)
- **ZooKeeper**: 1 × (50m CPU, 128Mi memory, 256Mi limit)

## Secrets

All secrets are sealed using Sealed Secrets:

1. **langfuse-secrets**: Encryption key and salt for application security
2. **langfuse-db-credentials**: PostgreSQL username and password
3. **langfuse-redis-password**: Redis authentication password
4. **langfuse-clickhouse-password**: ClickHouse database password
5. **rook-ceph-object-user-ceph-objectstore-langfuse**: S3 credentials (auto-created, reflected)

To regenerate sealed secrets, run:
```bash
./seal-secrets.sh
```

## Ingress

Access via Gateway API HTTPRoute:
- **URL**: `https://langfuse.animaniacs.farh.net`
- **Gateway**: `internal` (gateway-system namespace)
- **Backend**: langfuse-web service on port 3000

## PostgreSQL Backups

Automated backups via CloudNativePG to Ceph S3:
- **Destination**: `s3://langfuse-postgres-backups/`
- **Retention**: 30 days
- **Compression**: gzip for both WAL and base backups
- **Schedule**: Continuous WAL archiving + scheduled base backups

## Deployment

This repository is monitored by Flux CD. Changes pushed to main branch are automatically deployed:

1. Flux GitRepository watches this repo
2. Kustomization applies manifests in dependency order:
   - HelmRepository → PostgreSQL cluster → Sealed secrets → HelmRelease → HTTPRoute
3. HelmRelease deploys Langfuse chart with custom values

## Files

- `helmrepository.yaml`: Langfuse official Helm chart repository
- `helmrelease.yaml`: Langfuse deployment configuration (web + worker + dependencies)
- `postgres-cluster.yaml`: CloudNativePG cluster definition
- `httproute.yaml`: Gateway API ingress route
- `sealedsecrets.yaml`: Encrypted secrets for Langfuse and PostgreSQL
- `kustomization.yaml`: Kustomize resource definitions
- `seal-secrets.sh`: Helper script to regenerate sealed secrets

## Notes

- MinIO is disabled in favor of external Ceph S3 (`object.farh.net`)
- S3 credentials are auto-created by CephObjectStoreUser in `rook-ceph` namespace
- The secret is reflected to `langfuse` namespace via reflector annotations
- PostgreSQL backups use the same Ceph S3 backend
