#!/bin/bash
#
# Envoy Gateway Helm Installation Script - Cluster2 (Tenant-B)
#
# Cluster: Tenant-B Kubernetes Cluster
# Kubernetes Version: v1.32.8
# Envoy Gateway Version: v1.2.4
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Envoy Gateway Helm Installation - Cluster2${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Install Gateway API CRDs
echo -e "${YELLOW}Step 1: Installing Gateway API CRDs v1.2.0...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

echo ""
sleep 3

# Step 2: Install Envoy Gateway using Helm (OCI Registry)
echo -e "${YELLOW}Step 2: Installing Envoy Gateway v1.2.4 using Helm from OCI...${NC}"
helm install eg oci://docker.io/envoyproxy/gateway-helm \
	  --version v1.2.4 \
	    --namespace envoy-gateway-system \
	      --create-namespace

echo ""
echo -e "${YELLOW}Waiting for Envoy Gateway to be deployed...${NC}"
sleep 10

# Step 3: Wait for Envoy Gateway to be ready
echo ""
echo -e "${YELLOW}Step 3: Waiting for Envoy Gateway pods to be ready...${NC}"
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo ""
echo -e "${GREEN}✓ Envoy Gateway installation complete${NC}"

# Step 4: Verify installation
echo ""
echo -e "${YELLOW}Step 4: Verifying Envoy Gateway installation...${NC}"
echo ""
echo -e "${YELLOW}Envoy Gateway Pods:${NC}"
kubectl get pods -n envoy-gateway-system -o wide

echo ""
echo -e "${YELLOW}Envoy Gateway Deployment:${NC}"
kubectl get deployment -n envoy-gateway-system

echo ""
echo -e "${YELLOW}Gateway API CRDs:${NC}"
kubectl get crd | grep gateway

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Installed Components:${NC}"
echo "- Gateway API CRDs (v1.2.0)"
echo "- Envoy Gateway (v1.2.4) via Helm"
echo ""
echo -e "${YELLOW}Verification Commands:${NC}"
echo "kubectl get pods -n envoy-gateway-system"
echo "kubectl get crd | grep gateway"
echo ""
echo -e "${YELLOW}To uninstall:${NC}"
echo "helm uninstall eg -n envoy-gateway-system"
echo ""
