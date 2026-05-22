########################################################
# Payload Decryption Utility
# Decrypts AES-256-CBC blob for access to
# secret server vault.
# Author: Jarred Wheeler
# v.01 03/2026
# v.02 04/2026 - added global parsing for $payload
#
# PS1 script args:
# 1 - $Blob
########################################################

# Inject line 15-89 at the top of your code base

########################################################
# Change the Pin below to match shared secret
# See SecretServer for current 32bit Pin
# Example 32bit Shared Secret
# $Pin = 'A7K9ChangeMePleaseZ1L6M3T5R0BHY'
########################################################
$Pin = ''

# PS1 arguments
param(
    [Parameter(Mandatory)]
    [string]$Blob
)

########################################################
# Functions
########################################################
function Decode-JsonBlob {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Blob,
        [Parameter(Mandatory = $true)]
        [string] $Pin
    )

    $bytes = [Convert]::FromBase64String($Blob)
    if ($bytes.Length -lt 38) {
        throw "Blob too short."
    }

    # Blob format:
    # [1 byte version=3][4 bytes iterations][16 salt][16 iv][ciphertext]

    $version = $bytes[0]
    if ($version -ne 3) {
        throw "Unsupported blob version $version"
    }

    $iterations = [BitConverter]::ToInt32($bytes, 1)
    $salt = $bytes[5..20]
    $iv = $bytes[21..36]
    $cipher = $bytes[37..($bytes.Length - 1)]

    # Derive AES key
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Pin, $salt, $iterations)
    $key = $kdf.GetBytes(32)

    # AES decrypt
    $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key = $key
    $aes.IV = $iv

    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)

    $json = [System.Text.Encoding]::UTF8.GetString($plainBytes)

    # Convert to PowerShell object
    $global:payload = $json | ConvertFrom-Json

    # Best-effort cleanup
    try { [Array]::Clear($plainBytes, 0, $plainBytes.Length) } catch {}
    try { [Array]::Clear($key, 0, $key.Length) } catch {}
}

Decode-JsonBlob -Blob $Blob -Pin $Pin

########################################################
# $payload is now available for use below this point
# Example:
# $username = $payload.secret.u
# $password = $payload.secret.p
########################################################
