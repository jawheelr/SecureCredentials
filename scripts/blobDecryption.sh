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
# ADD lines 15-88 into the top of your script
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
# Functions
########################################################
decode_json_blob() {
  local BLOB="$1"
  local PIN="$2"

  tmp=$(mktemp)
  ct=$(mktemp)

  printf "%s" "$BLOB" | base64 -d > "$tmp"

  ########################################################
  # Parse header
  ########################################################
  version=$(xxd -p -l 1 "$tmp")

  iter_hex=$(xxd -p -s 1 -l 4 "$tmp" | \
    fold -w2 | awk '{a[NR]=$0} END {for(i=NR;i>0;i--) printf "%s", a[i]}')

  iterations=$((16#$iter_hex))

  salt_hex=$(xxd -p -s 5 -l 16 "$tmp")
  iv_hex=$(xxd -p -s 21 -l 16 "$tmp")

  dd if="$tmp" of="$ct" bs=1 skip=37 status=none

  ########################################################
  # Key derivation (MUST MATCH ENCRYPTOR)
  ########################################################
  KEY=$(printf "%s|%s|%s" "$PIN" "$SALT" "$ITERATIONS" \
  | openssl dgst -sha256 \
  | awk '{print $2}')
  
  ########################################################
  # Decrypt
  ########################################################
  plaintext=$(openssl enc -aes-256-cbc -d \
    -K "$KEY" \
    -iv "$iv_hex" \
    -in "$ct")

  printf "%s\n" "$plaintext"

  rm -f "$tmp" "$ct"
}

########################################################
# Run
########################################################
PAYLOAD_JSON=$(decode_json_blob "$BLOB" "$PIN")

########################################################
# Assign user and password to hidden variables
########################################################
username=$(echo "$PAYLOAD_JSON" | jq -r '.secret.u')
password=$(echo "$PAYLOAD_JSON" | jq -r '.secret.p')
