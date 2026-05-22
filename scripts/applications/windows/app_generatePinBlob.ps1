<#
########################################################
# Payload Encryption Utility
# AES-256-CBC blob encryption
#
# Author: Jarred Wheeler
# Version: v1.1 - 05/2026
########################################################
#>

$ErrorActionPreference = "Stop"

########################################################
# Load WinForms
########################################################
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

########################################################
# Helper: Message Box
########################################################
function Show-Message {

    param(
        [string]$Title,
        [string]$Message
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

########################################################
# Cancel / Exit
########################################################
function Cancel-Exit {

    exit 0
}

########################################################
# PIN Selection Dialog
########################################################
function Show-PinChoiceDialog {

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "PIN Selection"
    $form.Size = New-Object System.Drawing.Size(420,180)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    ####################################################
    # Detect Window Close
    ####################################################
    $form.Add_FormClosing({
        if ($form.Tag -eq $null) {
            Cancel-Exit
        }
    })

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Choose whether to generate a new PIN or use an existing PIN."
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(20,20)

    $btnGenerate = New-Object System.Windows.Forms.Button
    $btnGenerate.Text = "Generate PIN"
    $btnGenerate.Size = New-Object System.Drawing.Size(140,40)
    $btnGenerate.Location = New-Object System.Drawing.Point(40,80)

    $btnExisting = New-Object System.Windows.Forms.Button
    $btnExisting.Text = "Use Existing PIN"
    $btnExisting.Size = New-Object System.Drawing.Size(140,40)
    $btnExisting.Location = New-Object System.Drawing.Point(210,80)

    ####################################################
    # Generate PIN
    ####################################################
    $btnGenerate.Add_Click({
        $form.Tag = "Generate"
        $form.Close()
    })

    ####################################################
    # Existing PIN
    ####################################################
    $btnExisting.Add_Click({
        $form.Tag = "Existing"
        $form.Close()
    })

    $form.Controls.Add($label)
    $form.Controls.Add($btnGenerate)
    $form.Controls.Add($btnExisting)

    [void]$form.ShowDialog()

    return $form.Tag
}

########################################################
# Credential Form
########################################################
function Show-CredentialForm {

    param(
        [string]$Title,
        [string[]]$Fields,
        [string[]]$SecureFields
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(520,300)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    ####################################################
    # Detect Window Close
    ####################################################
    $form.Add_FormClosing({
        if ($form.Tag -eq $null) {
            Cancel-Exit
        }
    })

    $textBoxes = @{}
    $y = 20

    foreach ($field in $Fields) {

        $label = New-Object System.Windows.Forms.Label
        $label.Text = $field
        $label.Location = New-Object System.Drawing.Point(20,$y)
        $label.AutoSize = $true

        $textbox = New-Object System.Windows.Forms.TextBox
        $textbox.Location = New-Object System.Drawing.Point(140,$y)
        $textbox.Size = New-Object System.Drawing.Size(320,20)

        if ($SecureFields -contains $field) {
            $textbox.UseSystemPasswordChar = $true
        }

        $form.Controls.Add($label)
        $form.Controls.Add($textbox)

        $textBoxes[$field] = $textbox

        $y += 40
    }

    ####################################################
    # Continue Button
    ####################################################
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Continue"
    $okButton.Size = New-Object System.Drawing.Size(100,35)
    $okButton.Location = New-Object System.Drawing.Point(140,($y + 20))

    $okButton.Add_Click({
        $form.Tag = "OK"
        $form.Close()
    })

    ####################################################
    # Cancel Button
    ####################################################
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(100,35)
    $cancelButton.Location = New-Object System.Drawing.Point(260,($y + 20))

    $cancelButton.Add_Click({
        Cancel-Exit
    })

    $form.Controls.Add($okButton)
    $form.Controls.Add($cancelButton)

    [void]$form.ShowDialog()

    if ($form.Tag -ne "OK") {
        Cancel-Exit
    }

    ####################################################
    # Gather Results
    ####################################################
    $results = @{}

    foreach ($field in $Fields) {
        $results[$field] = $textBoxes[$field].Text
    }

    return $results
}

########################################################
# PIN Selection
########################################################
$PinChoice = Show-PinChoiceDialog

if ($PinChoice -eq "Generate") {

    ####################################################
    # Generate Random PIN
    ####################################################
    $Pin = ([guid]::NewGuid().ToString()).Replace("-","")

}
elseif ($PinChoice -eq "Existing") {

    ####################################################
    # Prompt for Existing PIN
    ####################################################
    $PinResult = Show-CredentialForm `
        -Title "Existing PIN" `
        -Fields @("PIN") `
        -SecureFields @("PIN")

    $Pin = $PinResult["PIN"]

}
else {

    Cancel-Exit

}

########################################################
# Validate PIN
########################################################
if ([string]::IsNullOrWhiteSpace($Pin)) {

    Show-Message `
        -Title "Error" `
        -Message "PIN was not supplied."

    exit 1
}

########################################################
# Prompt for Credentials
########################################################
$CredentialResult = Show-CredentialForm `
    -Title "Credential Entry" `
    -Fields @("Username","Password") `
    -SecureFields @("Password")

$Username = $CredentialResult["Username"]
$Password = $CredentialResult["Password"]

########################################################
# Validate Credentials
########################################################
if ([string]::IsNullOrWhiteSpace($Username) -or
    [string]::IsNullOrWhiteSpace($Password)) {

    Show-Message `
        -Title "Error" `
        -Message "Username or password missing."

    exit 1
}

########################################################
# Configuration
########################################################
[int]$Iterations = 200000
[int]$Version = 3

########################################################
# Payload
########################################################
$Payload = @{
    secret = @{
        u = $Username
        p = $Password
    }
}

########################################################
# Serialize JSON
########################################################
$json = $Payload | ConvertTo-Json -Compress -Depth 50
$plainBytes = [System.Text.Encoding]::UTF8.GetBytes($json)

########################################################
# Generate Salt
########################################################
$salt = New-Object byte[] 16

$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$rng.GetBytes($salt)

########################################################
# Derive Key
########################################################
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
    $Pin,
    $salt,
    $Iterations
)

$key = $kdf.GetBytes(32)

########################################################
# Configure AES
########################################################
$aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider

$aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = $key

########################################################
# Generate IV
########################################################
$aes.GenerateIV()
$iv = $aes.IV

########################################################
# Encrypt
########################################################
$encryptor = $aes.CreateEncryptor()

$cipherBytes = $encryptor.TransformFinalBlock(
    $plainBytes,
    0,
    $plainBytes.Length
)

########################################################
# Build Blob
# Structure:
# [Version][Iterations][Salt][IV][Ciphertext]
########################################################
$iterBytes = [BitConverter]::GetBytes([int]$Iterations)

$blobBytes = @([byte]$Version) +
             $iterBytes +
             $salt +
             $iv +
             $cipherBytes

########################################################
# Convert to Base64
########################################################
$Blob = [Convert]::ToBase64String($blobBytes)

########################################################
# Validate Blob
########################################################
if ([string]::IsNullOrWhiteSpace($Blob)) {

    Show-Message `
        -Title "Encryption Failure" `
        -Message "Blob generation failed."

    exit 1
}

########################################################
# Cleanup
########################################################
$encryptor.Dispose()
$aes.Dispose()
$kdf.Dispose()
$rng.Dispose()

########################################################
# Results Window
########################################################
$form = New-Object System.Windows.Forms.Form
$form.Text = "Encrypted Payload Generated"
$form.Size = New-Object System.Drawing.Size(950,650)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

########################################################
# Results Textbox
########################################################
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.ReadOnly = $true
$textBox.WordWrap = $false
$textBox.Font = New-Object System.Drawing.Font("Consolas",10)
$textBox.Size = New-Object System.Drawing.Size(900,500)
$textBox.Location = New-Object System.Drawing.Point(20,20)

$textBox.Text = @"
Encryption complete.

==================================================

PIN:
$Pin

==================================================

BLOB:
$Blob

==================================================

Save these somewhere safe.
This is the only time they will be shown.
"@

########################################################
# Copy PIN Button
########################################################
$copyPinButton = New-Object System.Windows.Forms.Button
$copyPinButton.Text = "Copy PIN"
$copyPinButton.Size = New-Object System.Drawing.Size(120,40)
$copyPinButton.Location = New-Object System.Drawing.Point(220,540)

$copyPinButton.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($Pin)
})

########################################################
# Copy Blob Button
########################################################
$copyBlobButton = New-Object System.Windows.Forms.Button
$copyBlobButton.Text = "Copy Blob"
$copyBlobButton.Size = New-Object System.Drawing.Size(120,40)
$copyBlobButton.Location = New-Object System.Drawing.Point(380,540)

$copyBlobButton.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($Blob)
})

########################################################
# OK Button
########################################################
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Size = New-Object System.Drawing.Size(120,40)
$okButton.Location = New-Object System.Drawing.Point(540,540)

$okButton.Add_Click({
    $form.Close()
})

########################################################
# Add Controls
########################################################
$form.Controls.Add($textBox)
$form.Controls.Add($copyPinButton)
$form.Controls.Add($copyBlobButton)
$form.Controls.Add($okButton)

########################################################
# Show Window
########################################################
[void]$form.ShowDialog()
