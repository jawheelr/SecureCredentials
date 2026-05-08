#!/bin/bash

########################################################
# Payload Encryption Utility + SwiftDialog Prompt
# AES-256-CBC blob encryption
#
# Author: Jarred Wheeler
#         v0.8 - 5/2026
#
########################################################

set -euo pipefail

########################################################
# SwiftDialog Check
########################################################
DIALOG="/usr/local/bin/dialog"

if [[ ! -x "$DIALOG" ]]; then
    echo "SwiftDialog not installed. Installing..."
    url=$(curl https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest | grep -m1 "browser_download_url" | awk '{print $2}' | sed 's/[",]//g')
    download=$(curl -Ls -o /dev/null -w %{url_effective} "$url")
    name=$(curl -OJsL $url -w "%{filename_effective}" )
        # Change name to omit extension and replace periods with spaces
        if [[ ${name} = *"."* ]]
            then name=$(echo ${name} | sed 's/[.]/ /g')
        fi
    curl -L "$download" --output /tmp/"${name}".pkg
    installer -pkg /tmp/"{$name}".pkg -target /
    rm -Rf /tmp/"${name}".pkg
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
    # Generate random PIN
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

    if [[ -z "$PIN" ]]; then
        echo "No PIN entered."
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
    echo "Username or password missing."
    exit 1
fi

########################################################
# Configuration
########################################################
ITERATIONS=200000
VERSION=3

########################################################
# Payload (JSON)
########################################################
JSON=$(jq -n \
    --arg u "$USERNAME" \
    --arg p "$PASSWORD" \
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
# PBKDF2 key derivation (32 bytes)
########################################################
KEY=$(openssl kdf \
    -keylen 32 \
    -kdfopt digest:SHA256 \
    -kdfopt salt:"$SALT" \
    -kdfopt iter:"$ITERATIONS" \
    PBKDF2 <<<"$PIN" \
    | xxd -p -c 256)

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
# Build Blob
########################################################
VER_HEX=$(printf "%02x" "$VERSION")

ITER_HEX=$(printf "%08x" "$ITERATIONS" \
    | sed 's/\(..\)/\1 /g' \
    | awk '{print $4$3$2$1}')

BLOB_HEX="${VER_HEX}${ITER_HEX}${SALT}${IV}$(xxd -p "$CIPHERTEXT" | tr -d '\n')"

BLOB=$(echo "$BLOB_HEX" | xxd -r -p | base64)

########################################################
# Cleanup temp files
########################################################
rm -f "$PLAINTEXT" "$CIPHERTEXT"

########################################################
# Display Results
########################################################
RESULTS=$(cat <<EOF
Encryption complete.

### PIN:
:3498db[${PIN}]

### Blob:
:3498db[${BLOB}]
EOF
)

"$DIALOG" \
    --title "Encrypted Payload Generated" \
    --message ":e74c3c[Save the PIN and the BLOB somewhere safe.
    This is the only time that these will be shown!]  \n\n
    $RESULTS" \
    --button1text "OK" \
    --width 800 \
    --height 500 \
    --ontop
