#!/bin/sh +x

# Set tenant name from command line argument (default to tenant1)
TENANT=${1:-tenant1}

# Create certificates directory
mkdir -p /tmp/certs/${TENANT}
cd /tmp/certs/${TENANT}

# Generate CA private key
openssl genrsa -out ca.key 4096

# Generate CA certificate
openssl req -new -x509 -key ca.key -sha256 \
	  -subj "/C=US/ST=CA/O=${TENANT}/CN=${TENANT}-CA" \
	    -days 3650 -out ca.crt

# Create server certificate configuration
cat > server.conf << EOF
[req]
default_bits = 4096
prompt = no
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = ${TENANT}
CN = ${TENANT}.dev

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${TENANT}.dev
DNS.2 = *.${TENANT}.dev
DNS.3 = prod.${TENANT}.dev
DNS.4 = qa.${TENANT}.dev
DNS.5 = staging.${TENANT}.dev
EOF

# Generate server private key
openssl genrsa -out tls.key 4096

# Generate CSR
openssl req -new -key tls.key -out server.csr -config server.conf

# Generate server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
	  -CAcreateserial -out tls.crt -days 365 -sha256 \
	    -extensions v3_req -extfile server.conf

# Verify certificate
echo "=== Certificate Details ==="
openssl x509 -in tls.crt -text -noout | grep -A 1 "Subject Alternative Name"
openssl x509 -in tls.crt -text -noout | grep "Subject:"

echo ""
echo "=== Files Generated ==="
ls -lh $PWD/tls.crt $PWD/tls.key $PWD/ca.crt

echo ""
echo "=== Create Kubernetes Secret (if needed) ==="
echo "kubectl create secret tls ${TENANT}-tls-cert \\"
echo "  --cert=$PWD/tls.crt \\"
echo "  --key=$PWD/tls.key \\"
echo "  -n default"
