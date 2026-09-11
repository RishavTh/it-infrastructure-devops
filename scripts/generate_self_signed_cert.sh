#!/usr/bin/env bash
set -euo pipefail
mkdir -p nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/selfsigned.key \
  -out nginx/certs/selfsigned.crt \
  -subj "/CN=localhost"
echo "Self-signed cert created in nginx/certs/"
