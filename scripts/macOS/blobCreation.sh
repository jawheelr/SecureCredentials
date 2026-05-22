#!/bin/bash

########################################################
# Payload Decryption Utility (Bash)
# AES-256-CEC blob encryption
#
# Author: Jarred Wheeler
#         v0.1 - 4/2026
# Python required to use PBKDF2.
#   *Allows for blobs/pins usage across platforms
#
########################################################
set -euo pipefail

########################################################
# Configuration
########################################################
PIN=""
ITERATIONS=200000
VERSION=3

########################################################
# Payload (JSON)
########################################################
JSON=$(jq -n \
  --arg u "" \
  --arg p "" \
  '{secret:{u:$u,p:$p}}')

PLAINTEXT=$(mktemp)
CIPHERTEXT=$(mktemp)

printf '%s' "$JSON" > "$PLAINTEXT"

########################################################
# Salt + IV
########################################################
SALT=$(openssl rand -hex 16)
IV=$(openssl rand -hex 16)

########################################################
# PBKDF2-HMAC-SHA1 key derivation (32 bytes)
# MUST MATCH:
# PowerShell 5.1 Rfc2898DeriveBytes
# hashlib.pbkdf2_hmac('sha1', ...)
########################################################
KEY=$(python3 <<EOF
import hashlib

pin = "${PIN}".encode()
salt = bytes.fromhex("${SALT}")
iterations = ${ITERATIONS}

key = hashlib.pbkdf2_hmac(
    'sha1',
    pin,
    salt,
    iterations,
    32
)

print(key.hex())
EOF
)

########################################################
# Encrypt
########################################################
openssl enc -aes-256-cbc \
  -K "$KEY" \
  -iv "$IV" \
  -in "$PLAINTEXT" \
  -out "$CIPHERTEXT" \
  -nosalt

########################################################
# Build blob
########################################################
VER_HEX=$(printf "%02x" "$VERSION")

ITER_HEX=$(printf "%08x" "$ITERATIONS" \
  | sed 's/\(..\)/\1 /g' \
  | awk '{print $4$3$2$1}')

BLOB_HEX="${VER_HEX}${ITER_HEX}${SALT}${IV}$(xxd -p "$CIPHERTEXT" | tr -d '\n')"

BLOB=$(echo "$BLOB_HEX" | xxd -r -p | base64)

########################################################
# Cleanup
########################################################
rm -f "$PLAINTEXT" "$CIPHERTEXT"
