#!/bin/bash

########################################################
# Payload Decryption Utility
# AES-256-CBC blob decryption
# Author: Jarred Wheeler
#         v0.1 - 4/2026
#
# e.g.: decryptblob.sh BLOBGOESHERE
# Parameters:
# 1 - json BLOB
#
########################################################
set -euo pipefail

########################################################
# Change the Pin below to match shared secret (hardcoded)
########################################################
PIN=""

########################################################
# Args
########################################################
# Argument 1 is the json blob
BLOB=${1}

########################################################
# Cleanup
########################################################
TMPFILE=""
CTFILE=""

cleanup() {
    [[ -f "${TMPFILE:-}" ]] && rm -f "$TMPFILE"
    [[ -f "${CTFILE:-}" ]] && rm -f "$CTFILE"
}

trap cleanup EXIT

########################################################
# Decode Blob
########################################################
TMPFILE=$(mktemp)
CTFILE=$(mktemp)

printf "%s" "$BLOB" | base64 -d > "$TMPFILE"

########################################################
# Parse Header
########################################################

# Version byte
VERSION=$(xxd -p -l 1 "$TMPFILE")

# Iterations (little endian uint32)
ITER_HEX_LE=$(xxd -p -s 1 -l 4 "$TMPFILE")

ITER_HEX=$(echo "$ITER_HEX_LE" \
    | sed 's/../& /g' \
    | awk '{for(i=NF;i>=1;i--) printf $i}')

ITERATIONS=$((16#$ITER_HEX))

# Salt
SALT_HEX=$(xxd -p -s 5 -l 16 "$TMPFILE")

# IV
IV_HEX=$(xxd -p -s 21 -l 16 "$TMPFILE")

# Ciphertext starts at byte 37
dd if="$TMPFILE" of="$CTFILE" bs=1 skip=37 status=none

########################################################
# Debug
########################################################
echo "Version:     $VERSION"
echo "Iterations:  $ITERATIONS"
echo "Salt:        $SALT_HEX"
echo "IV:          $IV_HEX"

########################################################
# PBKDF2-HMAC-SHA1 Key Derivation
# MUST MATCH PowerShell 5.1 Rfc2898DeriveBytes
########################################################

KEY_HEX=$(python3 - <<EOF
import hashlib
pin = "${PIN}".encode()
salt = bytes.fromhex("${SALT_HEX}")
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
# Decrypt AES-256-CBC
########################################################

PLAINTEXT=$(openssl enc -aes-256-cbc -d \
    -K "$KEY_HEX" \
    -iv "$IV_HEX" \
    -in "$CTFILE")

########################################################
# Output JSON
########################################################
echo
echo "Decrypted JSON:"
echo "$PLAINTEXT"

########################################################
# Example Usage
########################################################
# username=$(echo "$PAYLOAD_JSON" | jq -r '.secret.u')
# password=$(echo "$PAYLOAD_JSON" | jq -r '.secret.p')
USERNAME=$(echo "$PLAINTEXT" | jq -r '.secret.u')
PASSWORD=$(echo "$PLAINTEXT" | jq -r '.secret.p')
