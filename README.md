# Cluster2 (Tenant-B) - Installation Guide

Complete installation and configuration guide for Cluster2 (Tenant-B) Kubernetes cluster with MetalLB, BGP, and Envoy Gateway.

## Cluster Information

- **Cluster:** Tenant-B Kubernetes Cluster
- **Master Node:** master21 (control-plane)
- **Worker Nodes:** worker21, worker22
- **Kubernetes Version:** v1.32.8
- **MetalLB Version:** v0.14.9
- **Envoy Gateway Version:** v1.2.4

## Network Configuration

### BGP Configuration
- **MetalLB ASN:** 60201
- **IP Address Pool:** 198.51.100.20-198.51.100.29 (pool-tenant-b)
- **BGP Peers:**
  - worker21 → Leaf1 (10.0.2.201, ASN 64102)
  - worker21 → Leaf2 (10.0.2.202, ASN 64103)
  - worker22 → Leaf3 (10.0.2.203, ASN 64104)
  - worker22 → Leaf4 (10.0.2.204, ASN 64105)

P1+r6B4E=1B5B367E\## Installation Steps

### 1. Install MetalLB

```bash
./scripts/cluster2-metallb-install.sh
```

**Verify pod placement:**
```bash
kubectl get pods -n metallb-system -o wide
```

Expected output:
```
NAME                         READY   STATUS    RESTARTS   AGE   IP             NODE
controller-cb95499b5-wsn2f   1/1     Running   0          30s   10.223.34.71   master21
speaker-5vgtt                1/1     Running   0          15s   10.0.2.2       worker21
speaker-x84s6                1/1     Running   0          28s   10.0.2.3       worker22
```

✅ Controller on master21, Speakers on worker21 and worker22

### 2. Configure MetalLB BGP

```bash
kubectl apply -f metallb/cluster2-metallb-config.yaml
```

Expected output:
```
ipaddresspool.metallb.io/pool-tenant-b created
bgppeer.metallb.io/rack1-001-leaf1-vrf-tenant-b created
bgppeer.metallb.io/rack1-001-leaf2-vrf-tenant-b created
bgppeer.metallb.io/rack2-001-leaf1-vrf-tenant-b created
bgppeer.metallb.io/rack2-001-leaf2-vrf-tenant-b created
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
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60201,"msg":"BGP session established","peer":"10.0.2.201:179","peerASN":64102}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60201,"msg":"BGP session established","peer":"10.0.2.202:179","peerASN":64103}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60201,"msg":"BGP session established","peer":"10.0.2.203:179","peerASN":64104}
{"caller":"native.go:117","event":"sessionUp","level":"info","localASN":60201,"msg":"BGP session established","peer":"10.0.2.204:179","peerASN":64105}
```

✅ All 4 BGP sessions established

### 4. Verify MetalLB Resources

```bash
kubectl get ipaddresspools.metallb.io,bgppeer.metallb.io,bgpadvertisement.metallb.io -n metallb-system
```

Expected output:
```
NAME                                     AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
ipaddresspool.metallb.io/pool-tenant-b   true          false             ["198.51.100.20-198.51.100.29"]

NAME                                              ADDRESS      ASN     BFD PROFILE   MULTI HOPS
bgppeer.metallb.io/rack1-001-leaf1-vrf-tenant-b   10.0.2.201   64102
bgppeer.metallb.io/rack1-001-leaf2-vrf-tenant-b   10.0.2.202   64103
bgppeer.metallb.io/rack2-001-leaf1-vrf-tenant-b   10.0.2.203   64104
bgppeer.metallb.io/rack2-001-leaf2-vrf-tenant-b   10.0.2.204   64105

NAME                                                 IPADDRESSPOOLS      PEERS
bgpadvertisement.metallb.io/external-advertisement   ["pool-tenant-b"]   ["rack1-001-leaf1-vrf-tenant-b",...]
```

### 5. Create TLS Certificates

```bash
./scripts/certs.sh
```

Expected output:
```
Certificate request self-signature ok
subject=C = US, ST = CA, L = San Francisco, O = tenant2, CN = tenant2.dev

=== Files Generated ===
/tmp/certs/tenant2/ca.crt
/tmp/certs/tenant2/tls.crt
/tmp/certs/tenant2/tls.key
```

### 6. Create Kubernetes TLS Secret

```bash
kubectl create secret tls tenant2-tls-cert \
  --cert=/tmp/certs/tenant2/tls.crt \
  --key=/tmp/certs/tenant2/tls.key \
  -n default
```

Expected output:
```
secret/tenant2-tls-cert created
```

### 7. Install Envoy Gateway

```bash
./scripts/cluster2-envoy-install.sh
```

**Verify installation:**
```bash
kubectl get pods -n envoy-gateway-system
```

Expected output:
```
NAME                            READY   STATUS      RESTARTS   AGE
eg-gateway-helm-certgen-7f62z   0/1     Completed   0          21s
envoy-gateway-c7fcdbd7d-xktlc   1/1     Running     0          16s
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
deployment.apps/websocket-echo-tenant2-prod created
service/websocket-echo-tenant2-prod-service created
```

### 9. Deploy Envoy Gateway Resources

```bash
kubectl apply -f envoy/
```

Expected output:
```
gatewayclass.gateway.networking.k8s.io/eg created
gateway.gateway.networking.k8s.io/tenant2-envoy-gw created
httproute.gateway.networking.k8s.io/prod-websocket-route created
httproute.gateway.networking.k8s.io/prod-websocket-redirect created
```

### 10. Patch Envoy Service (Set externalTrafficPolicy)

```bash
./scripts/patch-envoy-services.sh
```

Expected output:
```
service/envoy-default-tenant2-envoy-gw-9464b881 patched
```

## Verification

### Check BGP Route Advertisement

```bash
kubectl logs -n metallb-system -l component=speaker --tail=100 | grep -E "announc|advertise" | grep 198
```

Expected output:
```json
{"caller":"bgp_controller.go:346","event":"updatedAdvertisements","ips":["198.51.100.20"],"level":"info","msg":"making advertisements using BGP","numAds":1,"pool":"pool-tenant-b","protocol":"bgp"}
{"caller":"main.go:420","event":"serviceAnnounced","ips":["198.51.100.20"],"level":"info","msg":"service has IP, announcing","pool":"pool-tenant-b","protocol":"bgp"}
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
=== Pod: speaker-5vgtt ===
{"caller":"bgp_controller.go:346","event":"updatedAdvertisements","ips":["198.51.100.20"],"level":"info","msg":"making advertisements using BGP","numAds":1,"pool":"pool-tenant-b","protocol":"bgp"}

=== Pod: speaker-x84s6 ===
{"caller":"bgp_controller.go:346","event":"updatedAdvertisements","ips":["198.51.100.20"],"level":"info","msg":"making advertisements using BGP","numAds":1,"pool":"pool-tenant-b","protocol":"bgp"}
```

✅ LoadBalancer IP (198.51.100.20) is being advertised via BGP from both speakers

### Check Gateway and Services

```bash
# Check Gateway
kubectl get gateway -n default

# Check application services
kubectl get svc -n default
```

Expected output:
```
NAME               CLASS   ADDRESS         PROGRAMMED   AGE
tenant2-envoy-gw   eg      198.51.100.20   True         86s

NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes                            ClusterIP   10.233.0.1      <none>        443/TCP   17d
prod-fallback-service                 ClusterIP   10.233.44.240   <none>        80/TCP    98s
websocket-echo-tenant2-prod-service   ClusterIP   10.233.2.93     <none>        80/TCP    98s
```

## Installation Summary

✅ **MetalLB installed** - Controller on master21, Speakers on worker nodes  
✅ **BGP configured** - 4 BGP sessions established with leaf switches  
✅ **IP pool configured** - 198.51.100.20-29 available for LoadBalancer services  
✅ **Envoy Gateway installed** - v1.2.4 via Helm  
✅ **TLS certificates created** - tenant2.dev certificate  
✅ **Applications deployed** - Fallback and WebSocket services  
✅ **Gateway configured** - tenant2-envoy-gw with HTTP/HTTPS listeners  
✅ **BGP routes advertised** - 198.51.100.20 advertised to all BGP peers
