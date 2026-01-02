#!/bin/bash

PROD_SERVICE=$(kubectl get svc -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=tenant1-envoy-gw" -o jsonpath='{.items[0].metadata.name}')
kubectl patch svc "$PROD_SERVICE" -n envoy-gateway-system -p '{
  "spec": {
    "externalTrafficPolicy": "Cluster"
  }
}'
