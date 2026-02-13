#!/bin/bash
set -e

echo "Generating and sealing Langfuse secrets..."
echo "This will create sealed versions of all required secrets."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output file
OUTPUT_FILE="sealedsecrets-sealed.yaml"
rm -f "$OUTPUT_FILE"

echo -e "${YELLOW}1/6${NC} Sealing langfuse-secrets (encryption key and salt)..."
kubectl create secret generic langfuse-secrets --namespace=langfuse \
  --from-literal=encryptionKey=$(openssl rand -hex 32) \
  --from-literal=salt=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}2/6${NC} Sealing langfuse-db-credentials (PostgreSQL)..."
kubectl create secret generic langfuse-db-credentials --namespace=langfuse \
  --from-literal=username=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}3/6${NC} Sealing langfuse-redis-password..."
kubectl create secret generic langfuse-redis-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}4/6${NC} Sealing langfuse-clickhouse-password..."
kubectl create secret generic langfuse-clickhouse-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}5/5${NC} Sealing langfuse-minio-credentials..."
kubectl create secret generic langfuse-minio-credentials --namespace=langfuse \
  --from-literal=root-user=admin \
  --from-literal=root-password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo ""
echo -e "${YELLOW}Note:${NC} PostgreSQL S3 backup credentials are auto-created by CephObjectStoreUser"
echo "  The secret 'rook-ceph-object-user-langfuse' will be created automatically"

echo ""
echo -e "${GREEN}✓ All secrets sealed successfully!${NC}"
echo ""
echo "Sealed secrets saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the sealed secrets: cat $OUTPUT_FILE"
echo "  2. Replace sealedsecrets.yaml: mv $OUTPUT_FILE sealedsecrets.yaml"
echo "  3. Commit and push: git add sealedsecrets.yaml && git commit -m 'chore: seal secrets' && git push"
