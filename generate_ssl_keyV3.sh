#!/bin/bash
# ref to https://goharbor.io/docs/2.0.0/install-config/configure-https/

HOSTNAME="harbor"
DOMAIN="ericstar.tw"
CA_DAYS="3650"
HARBOR_IP="192.168.10.163"
HARBOR_DIR="/harbor"

DOMAIN_NAME="${HOSTNAME}.${DOMAIN}"
GENDIR=./ssl_tmp
CA_KEY=./ca.key
CA_CRT=./ca.crt
CA_CERT=./ca.cert
DOMAIN_KEY=./${DOMAIN_NAME}.key
DOMAIN_CSR=./${DOMAIN_NAME}.csr
DOMAIN_CRT=./${DOMAIN_NAME}.crt
DOMAIN_CERT=./${DOMAIN_NAME}.cert


# Generate a Certificate Authority Certificate
# Generate a CA certificate private key
echo "Generate CA"
openssl genrsa -out ${CA_KEY} 4096
# Generate the CA certificate.
openssl req -x509 -new -nodes -sha512 -days ${CA_DAYS}\
     -subj "/C=CN/ST=Taiwan/L=Taiwan/O=CS/OU=infra/CN=${DOMAIN_NAME}" \
     -key ${CA_KEY} \
     -out ${CA_CRT}


# Generate a Server Certificate
echo "Generate Server Cert"
openssl genrsa -out ${DOMAIN_KEY} 4096
# Generate a certificate signing request (CSR)
openssl req -sha512 -new \
        -subj "/C=CN/ST=Taiwan/L=Taiwan/O=CS/OU=infra/CN=${DOMAIN_NAME}" \
        -key ${DOMAIN_KEY} \
        -out ${DOMAIN_CSR}


# Generate an x509 v3 extension file
cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1=127.0.0.1
IP.2=${HARBOR_IP}
DNS.1=${DOMAIN_NAME}
DNS.2=${DOMAIN}
DNS.3=${HOSTNAME}
EOF

# generate a certificate for your Harbor host
echo "Generate CERT for harbor"
openssl x509 -req -sha512 -days ${CA_DAYS} \
        -extfile v3.ext \
        -CA ${CA_CRT} -CAkey ${CA_KEY} -CAcreateserial \
        -in ${DOMAIN_CSR} \
        -out ${DOMAIN_CRT}

# generate PEM file
openssl x509 -inform PEM -in ${DOMAIN_CRT} -out ${DOMAIN_CERT}
openssl x509 -inform PEM -in ${CA_CRT} -out ${CA_CERT}

# check docker
#[ ! -f /usr/bin/docker ] && echo "docker does not exist"


# copy domain keys to harbor dir
read -p "Press enter to copy domain keys to harbor"
sudo mkdir -p ${HARBOR_DIR}/cert
sudo cp -p ${DOMAIN_CRT} ${DOMAIN_KEY} ${HARBOR_DIR}/cert

# copy server certificate to docker etc
read -p "Press enter to copy domain keys to docker"
sudo mkdir -p /etc/docker/certs.d/${DOMAIN_NAME}
sudo cp -p ${DOMAIN_CERT} ${DOMAIN_KEY} ${CA_CERT} ${CA_KEY} /etc/docker/certs.d/${DOMAIN_NAME}/
sudo cp -p ${DOMAIN_NAME}.crt /usr/local/share/ca-certificates/${DOMAIN_NAME}.crt
sudo update-ca-certificates
#sudo systemctl restart docker.service

