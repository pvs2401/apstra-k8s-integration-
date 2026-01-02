# Cluster1 (Tenant-A) - Installation Guide

Complete installation and configuration guide for Cluster1 (Tenant-A) Kubernetes cluster with MetalLB, BGP, and Envoy Gateway.

## Cluster Information

- **Cluster:** Tenant-A Kubernetes Cluster
- **Master Node:** master11 (control-plane)
- **Worker Nodes:** worker11, worker12
- **Kubernetes Version:** v1.32.8
- **MetalLB Version:** v0.14.9
- **Envoy Gateway Version:** v1.2.4

## Network Configuration

### BGP Configuration
- **MetalLB ASN:** 60101
- **IP Address Pool:** 198.51.100.10-198.51.100.19 (pool-tenant-a)
- **BGP Peers:**
  - worker11 → Leaf1 (10.0.1.201, ASN 64102)
  - worker11 → Leaf2 (10.0.1.202, ASN 64103)
  - worker12 → Leaf3 (10.0.1.203, ASN 64104)
  - worker12 → Leaf4 (10.0.1.204, ASN 64105)

## Installation Steps

### 1. Install MetalLB

```bash
./scripts/cluster1-metallb-install.sh
```

**Verify pod placement:**
```bash
kubectl get pods -n metallb-system -o wide
```

Expected output:
```
NAME                         READY   STATUS    RESTARTS   AGE   IP              NODE
controller-cb95499b5-7fvq6   1/1     Running   0          31s   10.223.10.202   master11
speaker-q5qf4                1/1     Running   0          16s   10.0.1.3        worker12
speaker-z8cxm                1/1     Running   0          29s   10.0.1.2        worker11
```

✅ Controller on master11, Speakers on worker11 and worker12

### 2. Configure MetalLB BGP

```bash
kubectl apply -f metallb/cluster1-metallb-config.yaml
```

Expected output:
```
ipaddresspool.metallb.io/pool-tenant-a created
bgppeer.metallb.io/rack1-001-leaf1-vrf-tenant-a created
bgppeer.metallb.io/rack1-001-leaf2-vrf-tenant-a created
bgppeer.metallb.io/rack2-001-leaf1-vrf-tenant-a created
bgppeer.metallb.io/rack2-001-leaf2-vrf-tenant-a created
bgpadvertisement.metallb.io/external-advertisement created
```

### 3. Verify BGP Sessions

```bash
for i in $(kubectl get pod -n metallb-system -l component=speaker | grep -v NAME | awk '{print $1}'); do
    kubectl logs -n metallb-system $i --tail=50 | grep -i "BGP session"
done
```

Expected output (4 BGP sessions established):
```json
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60101,"msg":"BGP session established","peer":"10.0.1.203:179","peerASN":64104}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60101,"msg":"BGP session established","peer":"10.0.1.204:179","peerASN":64105}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60101,"msg":"BGP session established","peer":"10.0.1.201:179","peerASN":64102}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60101,"msg":"BGP session established","peer":"10.0.1.202:179","peerASN":64103}
```

✅ All 4 BGP sessions established

### 4. Verify MetalLB Resources

```bash
kubectl get ipaddresspools.metallb.io,bgppeer.metallb.io,bgpadvertisement.metallb.io -n metallb-system
```

Expected output:
```
NAME                                     AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
ipaddresspool.metallb.io/pool-tenant-a   true          false             ["198.51.100.10-198.51.100.19"]

NAME                                              ADDRESS      ASN     BFD PROFILE   MULTI HOPS
bgppeer.metallb.io/rack1-001-leaf1-vrf-tenant-a   10.0.1.201   64102
bgppeer.metallb.io/rack1-001-leaf2-vrf-tenant-a   10.0.1.202   64103
bgppeer.metallb.io/rack2-001-leaf1-vrf-tenant-a   10.0.1.203   64104
bgppeer.metallb.io/rack2-001-leaf2-vrf-tenant-a   10.0.1.204   64105

NAME                                                 IPADDRESSPOOLS      PEERS
bgpadvertisement.metallb.io/external-advertisement   ["pool-tenant-a"]   ["rack1-001-leaf1-vrf-tenant-a",...]
```

### 5. Create TLS Certificates

```bash
./scripts/certs.sh
```

Expected output:
```
Certificate request self-signature ok
subject=C = US, ST = CA, L = San Francisco, O = tenant1, CN = tenant1.dev

=== Files Generated ===
/tmp/certs/tenant1/ca.crt
/tmp/certs/tenant1/tls.crt
/tmp/certs/tenant1/tls.key
```

### 6. Create Kubernetes TLS Secret

```bash
kubectl create secret tls tenant1-tls-cert \
  --cert=/tmp/certs/tenant1/tls.crt \
  --key=/tmp/certs/tenant1/tls.key \
  -n default
```

Expected output:
```
secret/tenant1-tls-cert created
```

### 7. Install Envoy Gateway

```bash
./scripts/cluster1-envoy-install.sh
```

**Verify installation:**
```bash
kubectl get pods -n envoy-gateway-system
```

Expected output:
```
NAME                            READY   STATUS      RESTARTS   AGE
eg-gateway-helm-certgen-vmlq6   0/1     Completed   0          23s
envoy-gateway-c7fcdbd7d-79r6v   1/1     Running     0          19s
```

### 8. Deploy Applications

```bash
kubectl apply -f apps/
```

Expected output:
```
configmap/fallback-error-pages created
deployment.apps/prod-fallback-app created
service/prod-fallback-service created
deployment.apps/websocket-echo-tenant1-prod created
service/websocket-echo-tenant1-prod-service created
```

### 9. Deploy Envoy Gateway Resources

```bash
kubectl apply -f envoy/
```

Expected output:
```
gatewayclass.gateway.networking.k8s.io/eg created
gateway.gateway.networking.k8s.io/tenant1-envoy-gw created
httproute.gateway.networking.k8s.io/prod-websocket-route created
httproute.gateway.networking.k8s.io/prod-websocket-redirect created
```

### 10. Patch Envoy Service (Set externalTrafficPolicy)

```bash
./scripts/patch-envoy-services.sh
```

Expected output:
```
service/envoy-default-tenant1-envoy-gw-a201ad8e patched
```

## Verification

### Check BGP Route Advertisement

```bash
kubectl logs -n metallb-system -l component=speaker --tail=100 | grep -E "announc|advertise" | grep 198
```

Expected output:
```json
{"caller":"main.go:420","event":"serviceAnnounced","ips":["198.51.100.10"],"level":"info","msg":"service has IP, announcing","pool":"pool-tenant-a","protocol":"bgp"}
```

### Check BGP Advertisements from All Speakers

```bash
for i in $(kubectl get pod -n metallb-system -l component=speaker | grep -v NAME | awk '{print $1}'); do
    echo "=== Pod: $i ==="
    kubectl logs -n metallb-system $i --tail=50 | grep -E "updatedAdvertisements"
done
```

Expected output:
```json
=== Pod: speaker-q5qf4 ===
{"caller":"bgp_controller.go:346","event":"updatedAdvertisements","ips":["198.51.100.10"],"level":"info","msg":"making advertisements using BGP","numAds":1,"pool":"pool-tenant-a","protocol":"bgp"}

=== Pod: speaker-z8cxm ===
{"caller":"bgp_controller.go:346","event":"updatedAdvertisements","ips":["198.51.100.10"],"level":"info","msg":"making advertisements using BGP","numAds":1,"pool":"pool-tenant-a","protocol":"bgp"}
```

✅ LoadBalancer IP (198.51.100.10) is being advertised via BGP from both speakers

### Check Gateway and Services

```bash
# Check Gateway
kubectl get gateway -n default

# Check Envoy Gateway LoadBalancer service
kubectl get svc -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=tenant1-envoy-gw"

# Check application services
kubectl get svc -n default
```

## Installation Summary

✅ **MetalLB installed** - Controller on master11, Speakers on worker nodes  
✅ **BGP configured** - 4 BGP sessions established with leaf switches  
✅ **IP pool configured** - 198.51.100.10-19 available for LoadBalancer services  
✅ **Envoy Gateway installed** - v1.2.4 via Helm  
✅ **TLS certificates created** - tenant1.dev certificate  
✅ **Applications deployed** - Fallback and WebSocket services  
✅ **Gateway configured** - tenant1-envoy-gw with HTTP/HTTPS listeners  
✅ **BGP routes advertised** - 198.51.100.10 advertised to all BGP peers
