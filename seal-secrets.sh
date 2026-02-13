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

echo -e "${YELLOW}1/5${NC} Sealing langfuse-secrets (encryption key and salt)..."
kubectl create secret generic langfuse-secrets --namespace=langfuse \
  --from-literal=encryptionKey=$(openssl rand -hex 32) \
  --from-literal=salt=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}2/5${NC} Sealing langfuse-db-credentials (PostgreSQL)..."
kubectl create secret generic langfuse-db-credentials --namespace=langfuse \
  --from-literal=username=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}3/5${NC} Sealing langfuse-redis-password..."
kubectl create secret generic langfuse-redis-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}4/5${NC} Sealing langfuse-clickhouse-password..."
kubectl create secret generic langfuse-clickhouse-password --namespace=langfuse \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"

echo -e "${YELLOW}5/5${NC} Sealing langfuse-s3-config (Ceph RGW credentials)..."
echo "  NOTE: You need to provide actual Ceph S3 credentials"
read -p "  S3 Endpoint (e.g., http://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local): " s3_endpoint
read -p "  S3 Access Key: " s3_access_key
read -sp "  S3 Secret Key: " s3_secret_key
echo ""
read -p "  S3 Bucket Name: " s3_bucket
read -p "  S3 Region (default: us-east-1): " s3_region
s3_region=${s3_region:-us-east-1}

kubectl create secret generic langfuse-s3-config --namespace=langfuse \
  --from-literal=endpoint="$s3_endpoint" \
  --from-literal=access_key="$s3_access_key" \
  --from-literal=secret_key="$s3_secret_key" \
  --from-literal=bucket="$s3_bucket" \
  --from-literal=region="$s3_region" \
  --dry-run=client -o yaml | kubeseal --format yaml >> "$OUTPUT_FILE"

echo ""
echo -e "${GREEN}✓ All secrets sealed successfully!${NC}"
echo ""
echo "Sealed secrets saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the sealed secrets: cat $OUTPUT_FILE"
echo "  2. Replace sealedsecrets.yaml: mv $OUTPUT_FILE sealedsecrets.yaml"
echo "  3. Commit and push: git add sealedsecrets.yaml && git commit -m 'chore: seal secrets' && git push"
