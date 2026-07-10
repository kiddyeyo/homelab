#!/bin/sh
DOMAIN="dns1.infra.sintaq.net"
openssl pkcs12 -export \
  -out /etc/letsencrypt/live/${DOMAIN}/${DOMAIN}.pfx \
  -inkey /etc/letsencrypt/live/${DOMAIN}/privkey.pem \
  -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem \
  -passout pass:
cp /etc/letsencrypt/live/${DOMAIN}/${DOMAIN}.pfx /opt/technitium/certs/cert.pfx
echo "pkcs#12 generado y copiado a Technitium"
