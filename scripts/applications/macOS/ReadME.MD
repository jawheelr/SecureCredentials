This "application" (really a script) is made to run directly from Self Service+ via JAMF.

Upload it as a script, create a policy, and launch it from Self Service+.

It will:
- Prompt for a PIN (creates a new or allows for an existing to generate a new blob for an existing PIN).
- Prompt for credentials to encrypt.
- Present a screen with the BLOB and PIN to copy and store in a secure location.

It will not:
- Create a decryption script for your script.
- Automatically remember your PIN (or anything else for that matter)
- Create logs anywhere.
