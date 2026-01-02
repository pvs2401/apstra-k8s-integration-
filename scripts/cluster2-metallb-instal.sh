#!/bin/bash
#
# MetalLB Installation Script - Cluster2 (Tenant-B)
# Controller on Master, Speakers on Workers Only
#
# Cluster: Tenant-B Kubernetes Cluster
# Kubernetes Version: v1.32.8
# MetalLB Version: v0.14.9
#
# Nodes:
#   - master21 (control-plane)
#   - worker21 (worker)
#   - worker22 (worker)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MetalLB Installation Script - Cluster2${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Install MetalLB
echo -e "${YELLOW}Step 1: Installing MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

echo ""
echo -e "${YELLOW}Waiting for MetalLB namespace to be created...${NC}"
sleep 5

# Step 2: Wait for initial deployment
echo ""
echo -e "${YELLOW}Step 2: Waiting for pods to be ready (this may take up to 90 seconds)...${NC}"
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s || echo "Warning: Some pods may still be starting"

echo ""
echo -e "${YELLOW}Current pod status:${NC}"
kubectl get pods -n metallb-system -o wide

# Step 3: Patch Controller - Run on Master Node
echo ""
echo -e "${YELLOW}Step 3: Patching Controller deployment to run on master node...${NC}"
kubectl patch deployment controller -n metallb-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/nodeSelector",
    "value": {
      "node-role.kubernetes.io/control-plane": ""
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/tolerations",
    "value": [
      {
        "key": "node-role.kubernetes.io/control-plane",
        "operator": "Exists",
        "effect": "NoSchedule"
      },
      {
        "key": "node-role.kubernetes.io/master",
        "operator": "Exists",
        "effect": "NoSchedule"
      }
    ]
  }
]'

echo -e "${GREEN}✓ Controller patched to run on master node${NC}"

# Step 4: Patch Speaker - Run on Worker Nodes Only
echo ""
echo -e "${YELLOW}Step 4: Patching Speaker DaemonSet to run only on worker nodes...${NC}"
kubectl patch daemonset speaker -n metallb-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/affinity",
    "value": {
      "nodeAffinity": {
        "requiredDuringSchedulingIgnoredDuringExecution": {
          "nodeSelectorTerms": [
            {
              "matchExpressions": [
                {
                  "key": "node-role.kubernetes.io/control-plane",
                  "operator": "DoesNotExist"
                }
              ]
            }
          ]
        }
      }
    }
  }
]'

echo -e "${GREEN}✓ Speaker patched to run only on worker nodes${NC}"

# Step 5: Wait for pods to reschedule
echo ""
echo -e "${YELLOW}Step 5: Waiting for pods to reschedule (30 seconds)...${NC}"
sleep 30

# Step 6: Verify pod placement
echo ""
echo -e "${YELLOW}Step 6: Verifying pod placement...${NC}"
echo ""
kubectl get pods -n metallb-system -o wide

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check controller placement
echo -e "${YELLOW}Controller Pod (should be on master21):${NC}"
kubectl get pod -n metallb-system -l component=controller -o wide

echo ""
echo -e "${YELLOW}Speaker Pods (should be on worker21 and worker22 only):${NC}"
kubectl get pod -n metallb-system -l component=speaker -o wide

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Apply BGP configuration: kubectl apply -f metallb-bgp-complete.yaml"
echo "2. Verify BGP sessions are established"
echo "3. Test with a LoadBalancer service"
echo ""
echo -e "${YELLOW}To apply BGP configuration:${NC}"
echo "kubectl apply -f metallb/cluster2-metallb-config.yaml"
echo ""
echo -e "${YELLOW}To verify BGP sessions:${NC}"
echo 'for i in $(kubectl get pod -n metallb-system -l component=speaker | grep -v NAME | awk '"'"'{print $1}'"'"'); do'
echo '    kubectl logs -n metallb-system $i --tail=50 | grep -i "BGP session"'
echo 'done'
echo ""
echo -e "${YELLOW}To check MetalLB resources:${NC}"
echo "kubectl get ipaddresspools.metallb.io,bgppeer.metallb.io,bgpadvertisement.metallb.io -n metallb-system"
echo ""
