#!/bin/sh
CERT_NAME="dns1.infra.sintaq.net"
openssl pkcs12 -export \
  -out /etc/letsencrypt/live/${CERT_NAME}/${CERT_NAME}.pfx \
  -inkey /etc/letsencrypt/live/${CERT_NAME}/privkey.pem \
  -in /etc/letsencrypt/live/${CERT_NAME}/fullchain.pem \
  -passout pass:
cp /etc/letsencrypt/live/${CERT_NAME}/${CERT_NAME}.pfx /opt/technitium/certs/cert.pfx
echo "pkcs#12 generado y copiado a Technitium"
