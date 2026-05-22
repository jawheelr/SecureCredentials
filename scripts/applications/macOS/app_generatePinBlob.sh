#!/bin/bash

########################################################
# Payload Encryption Utility + SwiftDialog Prompt
# AES-256-CBC blob encryption
#
# PowerShell Compatible
# - PBKDF2-HMAC-SHA1
# - AES-256-CBC
# - PKCS7 Padding
# - Blob Format:
#   [Version][Iterations][Salt][IV][Ciphertext]
#
# Author: Jarred Wheeler
# Version: v1.0 - 05/2026
########################################################

set -euo pipefail

########################################################
# SwiftDialog
########################################################
DIALOG="/usr/local/bin/dialog"

if [[ ! -x "$DIALOG" ]]; then
    echo "SwiftDialog not installed."
    jamf policy -event swiftDialog
fi

########################################################
# Cancel / Exit Dialog
########################################################
cancel_exit() {

    "$DIALOG" \
        --title "SecureCredentials" \
        --message "Thank you for using SecureCredentials." \
        --button1text "OK" \
        --width 500 \
        --height 260 \
        --ontop

    exit 0
}

########################################################
# Cleanup
########################################################
cleanup() {

    [[ -f "${PLAINTEXT:-}" ]] && rm -f "$PLAINTEXT"
    [[ -f "${CIPHERTEXT:-}" ]] && rm -f "$CIPHERTEXT"
}

trap cleanup EXIT

########################################################
# Ask User About PIN Creation
########################################################
set +e

"$DIALOG" \
    --title "PIN Selection" \
    --message "Choose whether to generate a new PIN or use an existing PIN." \
    --button1text "Generate PIN" \
    --button2text "Use Existing PIN" \
    --width 450 \
    --height 220

PIN_CHOICE=$?

set -e

########################################################
# Generate or Prompt for Existing PIN
########################################################
if [[ $PIN_CHOICE -eq 0 ]]; then

    ####################################################
    # Generate Random PIN
    ####################################################
    PIN=$(uuidgen | tr -d '-')

elif [[ $PIN_CHOICE -eq 2 ]]; then

    ####################################################
    # Prompt for Existing PIN
    ####################################################
    set +e

    PIN_DIALOG=$("$DIALOG" \
        --title "Existing PIN" \
        --message "Enter your existing PIN to continue." \
        --textfield "PIN",secure \
        --button1text "Continue" \
        --button2text "Cancel" \
        --width 500 \
        --height 250)

    PIN_EXIT=$?

    set -e

    ####################################################
    # Handle Cancel
    ####################################################
    if [[ $PIN_EXIT -ne 0 ]]; then
        cancel_exit
    fi

    ####################################################
    # Parse PIN
    ####################################################
    PIN=$(echo "$PIN_DIALOG" | awk -F ' : ' '/PIN/ {print $2}')

    ####################################################
    # Validate PIN
    ####################################################
    if [[ -z "$PIN" ]]; then

        "$DIALOG" \
            --title "Error" \
            --message "No PIN entered." \
            --button1text "OK" \
            --width 400 \
            --height 220

        exit 1
    fi

else
    cancel_exit
fi

########################################################
# Prompt for Username + Password
########################################################
set +e

DIALOG_OUTPUT=$("$DIALOG" \
    --title "Credential Entry" \
    --message "Enter credentials to encrypt." \
    --textfield "Username" \
    --textfield "Password",secure \
    --button1text "Encrypt" \
    --button2text "Cancel" \
    --width 500 \
    --height 300)

EXIT_CODE=$?

set -e

########################################################
# Handle Cancel
########################################################
if [[ $EXIT_CODE -ne 0 ]]; then
    cancel_exit
fi

########################################################
# Parse SwiftDialog Output
########################################################
USERNAME=$(echo "$DIALOG_OUTPUT" | awk -F ' : ' '/Username/ {print $2}')
PASSWORD=$(echo "$DIALOG_OUTPUT" | awk -F ' : ' '/Password/ {print $2}')

########################################################
# Validate Input
########################################################
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then

    "$DIALOG" \
        --title "Error" \
        --message "Username or password missing." \
        --button1text "OK" \
        --width 450 \
        --height 220

    exit 1
fi

########################################################
# Configuration
########################################################
ITERATIONS=200000
VERSION=3

########################################################
# Build JSON Payload
#
# Matches PowerShell:
# ConvertTo-Json -Compress
########################################################
JSON=$(jq -nc \
    --arg u "$USERNAME" \
    --arg p "$PASSWORD" \
    '{secret:{u:$u,p:$p}}')

########################################################
# Temp Files
########################################################
PLAINTEXT=$(mktemp)
CIPHERTEXT=$(mktemp)

printf '%s' "$JSON" > "$PLAINTEXT"

########################################################
# Generate Salt + IV
########################################################
SALT_HEX=$(openssl rand -hex 16)
IV_HEX=$(openssl rand -hex 16)

########################################################
# PBKDF2-HMAC-SHA1 Key Derivation
#
# Matches PowerShell:
# Rfc2898DeriveBytes(
#   PIN,
#   Salt,
#   Iterations
# ).GetBytes(32)
########################################################
KEY_HEX=$(python3 <<PY
import hashlib
import binascii

pin = "$PIN".encode("utf-8")
salt = bytes.fromhex("$SALT_HEX")
iterations = $ITERATIONS

key = hashlib.pbkdf2_hmac(
    "sha1",
    pin,
    salt,
    iterations,
    dklen=32
)

print(binascii.hexlify(key).decode())
PY
)

########################################################
# Encrypt
#
# Matches PowerShell:
# AES CBC + PKCS7
########################################################
openssl enc -aes-256-cbc \
    -K "$KEY_HEX" \
    -iv "$IV_HEX" \
    -in "$PLAINTEXT" \
    -out "$CIPHERTEXT" \
    -nosalt

########################################################
# Version Byte
########################################################
VER_HEX=$(printf '%02x' "$VERSION")

########################################################
# Iterations -> Little Endian
#
# Matches:
# [BitConverter]::GetBytes([int]$Iterations)
########################################################
ITER_HEX=$(printf '%08x' "$ITERATIONS" \
    | sed 's/\(..\)/\1 /g' \
    | awk '{print $4$3$2$1}')

########################################################
# Ciphertext Hex
########################################################
CIPHER_HEX=$(xxd -p "$CIPHERTEXT" | tr -d '\n')

########################################################
# Final Blob Structure
#
# [Version][Iterations][Salt][IV][Ciphertext]
########################################################
BLOB_HEX="${VER_HEX}${ITER_HEX}${SALT_HEX}${IV_HEX}${CIPHER_HEX}"

########################################################
# Convert Blob to Base64
########################################################
BLOB=$(printf '%s' "$BLOB_HEX" \
    | xxd -r -p \
    | base64)

########################################################
# Display Results
########################################################
RESULTS=$(cat <<EOF
Encryption complete.

### PIN:
:3498db[$PIN]

### Blob:
:3498db[$BLOB]
EOF
)

"$DIALOG" \
    --title "Encrypted Payload Generated" \
    --message ":e74c3c[Save the PIN and the BLOB somewhere safe.
This is the only time they will be shown.]

$RESULTS" \
    --button1text "OK" \
    --width 900 \
    --height 550 \
    --ontop
