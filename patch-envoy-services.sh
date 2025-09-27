#!/bin/bash

PROD_SERVICE=$(kubectl get svc -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=prod-websocket-gateway" -o jsonpath='{.items[0].metadata.name}')
kubectl patch svc "$PROD_SERVICE" -n envoy-gateway-system -p '{
  "spec": {
    "loadBalancerIP": "192.168.100.15",
    "externalTrafficPolicy": "Cluster"
  }
}'

QA_SERVICE=$(kubectl get svc -n envoy-gateway-system -l "gateway.envoyproxy.io/owning-gateway-name=qa-websocket-gateway" -o jsonpath='{.items[0].metadata.name}')
kubectl patch svc "$QA_SERVICE" -n envoy-gateway-system -p '{
  "spec": {
    "loadBalancerIP": "192.168.100.25",
    "externalTrafficPolicy": "Cluster"
  }
}'