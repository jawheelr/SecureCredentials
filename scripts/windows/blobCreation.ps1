########################################################
# Payload Encryption Utility
# Generates a versioned, salted AES-256-CBC blob from
# a JSON secret payload for secure transport.
# Author: Jarred Wheeler
# v.01 05/2026
#
########################################################

########################################################
# Change the Pin below to match shared secret
# See SecretServer for current 32bit Pin
# Example 32bit Shared Secret
# $Pin = 'A7K9ChangeMeX4P2Q8Z1L6M3T5R0BHY'
########################################################
# Shared secret PIN retrieved from SecretServer
[string] $Pin = '' 

# 200k iterations to mitigate brute-force risks
[int] $Iterations = 200000 

########################################################
# Build your secret JSON payload here
# You can have mulitple secret per payload:
# $Payload = @{
#  secret = @{
#    u = 'apiuser1'
#    p = 'SuperSecretPassword1!'
#  }
#  secret2 = @{
#    u = 'apiuser2'
#    p = 'SuperSecretPassword2!'
#  }
#}
########################################################
# Define the Secret Server API User object to be encrypted
$Payload = @{
  secret = @{
    # API User
    u = ''
    # API Password
    p = ''
  }
}

########################################################
# Data Serialization and Entropy Generation
########################################################

# Convert payload to minified JSON byte array
$json = $Payload | ConvertTo-Json -Compress -Depth 50
$plainBytes = [System.Text.Encoding]::UTF8.GetBytes($json)

# Initialize CSP for cryptographically strong random salt
$salt = New-Object byte[] 16
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$rng.GetBytes($salt)

########################################################
# Key Derivation and Encryption Logic
########################################################

# Derive a 256-bit key using PBKDF2 (Rfc2898)
# 
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Pin, $salt, $Iterations)
$key = $kdf.GetBytes(32)

# Configure AES in CBC mode with PKCS7 padding
# 
$aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = $key

# Generate unique IV for this specific encryption session
$aes.GenerateIV()
$iv = $aes.IV

# Encrypt the plaintext byte stream
$encryptor = $aes.CreateEncryptor()
$cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

########################################################
# Binary Blob Assembly
# Structure: [Ver][Iterations][Salt][IV][Ciphertext]
########################################################

$ver = 3 # Current schema version
$iterBytes = [BitConverter]::GetBytes([int]$Iterations)

# Combine all components into a single byte array
$blobBytes = @([byte]$ver) + $iterBytes + $salt + $iv + $cipherBytes

## TODO: Implement HMAC-SHA256 for integrity verification

# Encode the final package to Base64 for string transport
[Convert]::ToBase64String($blobBytes)
