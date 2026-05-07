## SecureCredentials is an interactive macOS shell utility that securely encrypts user credentials (username + password) into a portable encrypted blob using:

AES-256-CBC encryption
PBKDF2 (SHA256) key derivation
SwiftDialog UI for input/output

The result is a secure, base64-encoded blob and a PIN, which are both required for decryption.

⚙️ Requirements
Before running the script, ensure the following are available:
macOS system
openssl
jq
curl
SwiftDialog (auto-installed if missing)


🚀 Running the Script
chmod +x scripts/blobCreation.sh  <br>
./pathToFile/blobCreation.sh

🖥️ User Workflow
1. SwiftDialog Installation
If SwiftDialog is not installed, the script will:
Automatically download the latest release
Install it to /usr/local/bin/dialog


2. PIN Selection
You will be prompted with:

Generate PIN → (future logic placeholder)
Use Existing PIN → enter your own PIN


⚠️ Note: In the current version (v0.8), PIN handling logic is incomplete—ensure $PIN is properly populated if modifying the script.


3. Credential Entry
A dialog will prompt you for:
Username
Password (masked input)

Options:
Encrypt → continue
Cancel → exit safely


4. Input Validation
The script checks:
Username is not empty
Password is not empty

If validation fails:
_Username or password missing._

🔐 Encryption Process
Once valid input is provided, the script performs:
1. JSON Payload Creation
JSON{  "secret": {    "u": "username",    "p": "password"  }}

2. Key Derivation
Algorithm: PBKDF2
Digest: SHA256
Iterations: 200,000
Salt: Random 16 bytes
Key length: 32 bytes


3. Encryption
Cipher: AES-256-CBC
IV: Random 16 bytes
Input: JSON payload


4. Blob Construction
Outputs:
Version identifier
Iteration count
Ciphertext

Final blob is:
Converted to hex
Encoded as base64


📦 Output
A final SwiftDialog screen will display:
Encryption complete.

PIN:
<your-pin>

Blob:
<base64-encoded-encrypted-payload>


**⚠️ IMPORTANT:**
**This is the only time the PIN and blob are displayed.
They are NOT stored anywhere.
Losing either means permanent data loss.**



🔒 Security Notes
Encryption key is derived from the PIN using PBKDF2
No plaintext credentials are stored
Temporary files are securely removed after execution
Uses strong cryptographic primitives:
AES-256-CBC
SHA256
High iteration count (200k)



🧯 Cancel / Exit Behavior
At any point, if the user cancels:

A confirmation dialog appears:
_Thank you for using SecureCredentials._

Script exits cleanly
