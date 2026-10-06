#!/usr/bin/env bash
set -euo pipefail
# Ephemeral keys belong solely to isolated test CAs; never saved in the repository.
mkdir -p /tmp/hex-tls
cd /tmp/hex-tls
for authority in trusted untrusted; do
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "ca-$authority.key" -out "ca-$authority.pem" -days 1 \
    -subj "/CN=Hex test $authority CA" -addext 'basicConstraints=critical,CA:TRUE' >/dev/null 2>&1
done
for variant in valid wrong-host untrusted; do
  authority=trusted
  hostname=api.mailchannels.net
  if [ "$variant" = wrong-host ]; then hostname=wrong.example.test; fi
  if [ "$variant" = untrusted ]; then authority=untrusted; fi
  openssl req -new -newkey rsa:2048 -nodes -keyout "$variant.key" -out "$variant.csr" \
    -subj "/CN=$hostname" >/dev/null 2>&1
  printf 'subjectAltName=DNS:%s\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n' "$hostname" > "$variant.ext"
  openssl x509 -req -in "$variant.csr" -CA "ca-$authority.pem" -CAkey "ca-$authority.key" -CAcreateserial \
    -out "$variant.pem" -days 1 -extfile "$variant.ext" >/dev/null 2>&1
done
