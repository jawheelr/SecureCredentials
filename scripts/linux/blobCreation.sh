#!/bin/bash

########################################################
# Payload Encryption Utility – Zenity GUI (Ubuntu/Debian)
# AES-256-CBC blob encryption
#
# PowerShell Compatible
# - PBKDF2-HMAC-SHA1
# - AES-256-CBC
# - PKCS7 Padding
# - Blob Format:
#   [Version][Iterations][Salt][IV][Ciphertext]
#
# GUI: Zenity (GTK)
#
# Author: Jarred Wheeler
# Version: v1.3-linux - 06/2026
########################################################

set -euo pipefail

########################################################
# Command -> APT Package Mapping
########################################################
declare -A CMD_PKG_MAP=(
    [zenity]="zenity"
    [jq]="jq"
    [openssl]="openssl"
    [python3]="python3"
    [xxd]="xxd"
    [uuidgen]="uuid-runtime"
    [curl]="curl"
)

########################################################
# Dependency Check + Auto-Install
########################################################
MISSING_PKGS=()

for cmd in "${!CMD_PKG_MAP[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_PKGS+=("${CMD_PKG_MAP[$cmd]}")
    fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then

    echo "──────────────────────────────────────────────"
    echo "  Missing packages detected: ${MISSING_PKGS[*]}"
    echo "  Installing now..."
    echo "──────────────────────────────────────────────"

    ####################################################
    # Elevate if not root
    ####################################################
    if [[ $EUID -ne 0 ]]; then
        SUDO="sudo"
    else
        SUDO=""
    fi

    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq "${MISSING_PKGS[@]}"

    ####################################################
    # Verify all commands are now available
    ####################################################
    STILL_MISSING=()
    for cmd in "${!CMD_PKG_MAP[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            STILL_MISSING+=("$cmd")
        fi
    done

    if [[ ${#STILL_MISSING[@]} -gt 0 ]]; then
        echo "ERROR: Installation failed for: ${STILL_MISSING[*]}"
        echo "Please install manually and re-run."
        exit 1
    fi

    echo "──────────────────────────────────────────────"
    echo "  All dependencies installed successfully."
    echo "──────────────────────────────────────────────"
fi

########################################################
# Icon – Download PNG for Zenity window-icon
########################################################
ICON_URL="https://raw.githubusercontent.com/jawheelr/SecureCredentials/main/media/icons/SecureCredentials_linux.png"
ICON_LOCAL="/tmp/.SecureCredentials_icon.png"

if [[ ! -f "$ICON_LOCAL" ]]; then
    curl -fsSL "$ICON_URL" -o "$ICON_LOCAL" 2>/dev/null || true
fi

# Build reusable icon flag array
WICON=()
if [[ -f "$ICON_LOCAL" ]]; then
    WICON=(--window-icon="$ICON_LOCAL")
fi

########################################################
# Dark / Light Mode Detection
#
# 1. GNOME 42+ exposes color-scheme via gsettings
# 2. Fallback: check if the GTK theme name contains "dark"
# 3. Default: light mode (Adwaita)
#
# Result: GTK_THEME is exported so every Zenity dialog
#         inherits the correct palette automatically.
########################################################
detect_theme() {

    local scheme=""

    ####################################################
    # Primary: org.gnome.desktop.interface color-scheme
    #   'prefer-dark'  -> dark
    #   'default'      -> light
    #   'prefer-light'  -> light
    ####################################################
    if command -v gsettings &>/dev/null; then
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)
        scheme=$(echo "$scheme" | tr -d "'\"")

        if [[ "$scheme" == "prefer-dark" ]]; then
            echo "dark"
            return
        elif [[ "$scheme" == "default" || "$scheme" == "prefer-light" ]]; then
            echo "light"
            return
        fi
    fi

    ####################################################
    # Fallback: inspect gtk-theme name for "dark"
    ####################################################
    if command -v gsettings &>/dev/null; then
        local gtk_theme
        gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || true)
        gtk_theme=$(echo "$gtk_theme" | tr -d "'\"" | tr '[:upper:]' '[:lower:]')

        if [[ "$gtk_theme" == *"dark"* ]]; then
            echo "dark"
            return
        fi
    fi

    ####################################################
    # Default to light
    ####################################################
    echo "light"
}

DETECTED_MODE=$(detect_theme)

if [[ "$DETECTED_MODE" == "dark" ]]; then
    export GTK_THEME="Adwaita:dark"
else
    export GTK_THEME="Adwaita"
fi

echo "──────────────────────────────────────────────"
echo "  Theme detected: $DETECTED_MODE  (GTK_THEME=$GTK_THEME)"
echo "──────────────────────────────────────────────"

########################################################
# Cancel / Exit – Thank You Dialog
########################################################
cancel_exit() {

    zenity --info \
        "${WICON[@]}" \
        --title="SecureCredentials" \
        --text="\nThank you for using SecureCredentials.\n" \
        --width=420 \
        --height=160 \
        --no-markup 2>/dev/null || true

    exit 0
}

########################################################
# Error Dialog Helper
########################################################
show_error() {

    local msg="$1"

    zenity --error \
        "${WICON[@]}" \
        --title="Error" \
        --text="\n${msg}\n" \
        --width=400 \
        --height=160 2>/dev/null || true
}

########################################################
# Cleanup – Secure temp file removal
########################################################
cleanup() {

    [[ -f "${PLAINTEXT:-}" ]]  && rm -f "$PLAINTEXT"
    [[ -f "${CIPHERTEXT:-}" ]] && rm -f "$CIPHERTEXT"
}

trap cleanup EXIT

########################################################
# Step 1 – Ask User About PIN Creation
########################################################
PIN_CHOICE=$(zenity --list \
    "${WICON[@]}" \
    --title="PIN Selection" \
    --text="\nChoose whether to generate a new PIN or use an existing PIN.\n" \
    --column="Action" \
    "Generate a new PIN" \
    "Use an existing PIN" \
    --hide-header \
    --width=520 \
    --height=360 2>/dev/null) || true

########################################################
# Step 2 – Generate or Prompt for Existing PIN
########################################################
if [[ "$PIN_CHOICE" == "Generate a new PIN" ]]; then

    ####################################################
    # Generate Random PIN (32 hex characters)
    ####################################################
    PIN=$(uuidgen | tr -d '-')

elif [[ "$PIN_CHOICE" == "Use an existing PIN" ]]; then

    ####################################################
    # Prompt for Existing PIN (masked input)
    ####################################################
    PIN=$(zenity --entry \
        "${WICON[@]}" \
        --title="Existing PIN" \
        --text="\nEnter your existing PIN to continue.\n" \
        --hide-text \
        --width=480 \
        --height=170 2>/dev/null) || cancel_exit

    ####################################################
    # Validate PIN
    ####################################################
    if [[ -z "$PIN" ]]; then
        show_error "No PIN entered."
        exit 1
    fi

else

    ####################################################
    # User closed / escaped the dialog
    ####################################################
    cancel_exit
fi

########################################################
# Step 3 – Prompt for Username + Password
########################################################
DIALOG_OUTPUT=$(zenity --forms \
    "${WICON[@]}" \
    --title="Credential Entry" \
    --text="\nEnter credentials to encrypt.\n" \
    --add-entry="Username" \
    --add-password="Password" \
    --separator="|" \
    --width=480 \
    --height=240 2>/dev/null) || cancel_exit

########################################################
# Parse Zenity Forms Output   (Username|Password)
########################################################
USERNAME=$(echo "$DIALOG_OUTPUT" | cut -d'|' -f1)
PASSWORD=$(echo "$DIALOG_OUTPUT" | cut -d'|' -f2-)

########################################################
# Validate Input
########################################################
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    show_error "Username or password missing."
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
#
# -w 0 : no line wrapping (Linux base64 wraps at 76)
########################################################
BLOB=$(printf '%s' "$BLOB_HEX" \
    | xxd -r -p \
    | base64 -w 0)

########################################################
# Display Results – text-info for selectable/copy text
########################################################
cat <<EOF | zenity --text-info \
    "${WICON[@]}" \
    --title="Encrypted Payload Generated" \
    --width=900 \
    --height=480 \
    --font="monospace 11" 2>/dev/null || true
═══════════════════════════════════════════════════
  ⚠  SAVE THE PIN AND BLOB SOMEWHERE SAFE
  ⚠  This is the only time they will be shown.
═══════════════════════════════════════════════════

PIN:
$PIN

BLOB:
$BLOB
EOF
