# 🔐 SecureCredentials

A lightweight Bash-based utility for securely encrypting and decrypting credentials using **AES‑256‑CBC** with **PBKDF2 key derivation**.

This project consists of two scripts:

*   `blobCreation.sh` → Interactive credential encryption (with SwiftDialog UI)
*   `blobDecryption.sh` → Command-line decryption of encrypted blobs

***

## 📌 Features

*   ✅ AES‑256‑CBC encryption
*   ✅ PBKDF2 (SHA-256) key derivation
*   ✅ Random salt + IV for each encryption
*   ✅ JSON-based payload structure
*   ✅ Optional GUI using **SwiftDialog**
*   ✅ Portable Bash implementation (macOS/Linux-friendly)
*   ✅ Base64-encoded encrypted blob output

***

## 🧱 Project Structure

```
.
├── assets/
│   └── usage.md
├── docs/
│   └── usage.md
├── examples/
│   └── sample_run.md
├── scripts/
│   ├── blobCreation.sh   # Encrypt credentials (interactive)
│   └── blobDecryption.sh       # Decrypt blob (CLI)
└── README.md
```


***

## 🚀 How It Works

### Encryption Flow (`SecureCredentials.sh`)

1.  Prompts user (via SwiftDialog) for:
    *   Username
    *   Password
    *   PIN (generated or user-supplied)

2.  Builds a JSON payload:
    ```json
    {
      "secret": {
        "u": "username",
        "p": "password"
      }
    }
    ```

3.  Generates:
    *   Random salt (16 bytes)
    *   Random IV (16 bytes)

4.  Derives encryption key using:
        PBKDF2 (SHA256, 200000 iterations)

5.  Encrypts payload with:
        AES-256-CBC

6.  Outputs:
    *   🔑 PIN
    *   📦 Encrypted base64 blob

***

### Decryption Flow (`decryptblob-2.sh`)

1.  Accepts base64-encoded blob as input
2.  Extracts:
    *   Version
    *   Iteration count
    *   Salt
    *   IV
    *   Ciphertext
3.  Re-derives the key using the provided PIN
4.  Decrypts the payload
5.  Outputs JSON and optionally extracts:
    *   Username
    *   Password

***

## ⚙️ Requirements

### Core Dependencies

*   `bash`
*   `openssl`
*   `jq`
*   `xxd`
*   `awk`

### Optional (for UI experience)

*   <https://github.com/swiftDialog/swiftDialog>

> The encryption script attempts to install SwiftDialog automatically if missing.

***

## 🛠️ Usage

### 🔒 Encrypt Credentials

```bash
chmod +x SecureCredentials.sh
./SecureCredentials.sh
```

Follow the prompts to:

*   Enter credentials
*   Generate or supply a PIN

📌 Output will display:

*   PIN (save this!)
*   Encrypted blob

***

### 🔓 Decrypt a Blob

```bash
chmod +x decryptblob-2.sh
./decryptblob-2.sh "<BASE64_BLOB>"
```

You must edit the script to set your PIN:

```bash
PIN="your-pin-here"
```

***

## 📦 Example

### Encrypted Output

    PIN: 123456
    Blob: VGhpcyBpcyBhbiBlbmNyeXB0ZWQgYmxvYg==

### Decrypted Output

```json
{
  "secret": {
    "u": "myuser",
    "p": "mypassword"
  }
}
```

***

## 🔐 Security Notes

*   ⚠️ The PIN is **required** to decrypt data — losing it means permanent data loss.
*   ⚠️ The PIN is currently **hardcoded in the decrypt script** — consider more secure handling.
*   ⚠️ Output is only shown once during encryption — store it securely.
*   ✅ Uses strong cryptographic primitives:
    *   AES‑256‑CBC
    *   PBKDF2 with 200,000 iterations
    *   Random salt + IV

***

## ⚠️ Known Limitations / Improvements

*   ❗ PIN handling could be improved (avoid hardcoding)
*   ❗ Minimal error handling in decryption script
*   ❗ No integrity check (e.g., HMAC)
*   ❗ macOS-oriented (SwiftDialog dependency)

Future improvements could include:

*   HMAC validation for tamper detection
*   Secure PIN input on decrypt side
*   Cross-platform UI support
*   Packaging as a unified CLI tool

***

## 🤝 Contributing

Contributions are welcome! Feel free to:

*   Open issues
*   Submit pull requests
*   Suggest improvements or enhancements

***

## 📄 License

MIT License (or specify your preferred license)

***

## 👤 Author

**Jarred Wheeler**  
Sr Infrastructure Engineer

***

If you want, I can also:

*   turn this into a polished GitHub repo (badges, releases, examples)
*   refactor your scripts for correctness/security (there are a few bugs worth fixing)
*   or add a proper CLI wrapper with flags instead of editing variables manually
