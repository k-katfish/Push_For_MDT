Import-Module Microsoft.PowerShell.Security
function Get-StoredPSCredential {
    if (-Not $script:StoredPSCredential) {
        Write-Debug "Get-StoredPSCredential: No credentials provided yet. Requesting credentials."
        if (Get-CredentialFromUser -eq -1) {
            Write-Verbose "Get-StoredPSCredential: User refused to provide credential. Returning -1."
            return -1
        }
    }
    return $script:StoredPSCredential
}

function Set-StoredPSCredential {
    param(
        [pscredential]$Credential
    )
    $script:StoredPSCredential = $Credential
}

function Get-CredentialFromUser {
    Add-Type -AssemblyName System.Windows.Forms

    $CredMessage = "Please provide valid credentials."
    $user = "$env:UserDomain\$env:USERNAME"
    $Credential = Get-Credential -Message $CredMessage -UserName $user
    if (-Not $Credential) {
        Write-Verbose "Get-CredentialFromUser: User probably clicked Cancel."
        return -1
    }

    Write-Verbose "Get-CredentialFromUser: Testing PSCredential object with username $($Credential.UserName)"

    try {
        Start-Process Powershell -ArgumentList "return 0" -Credential $Credential -WorkingDirectory 'C:\Windows\System32' -NoNewWindow
    } catch {
        if ($_ -like "*password*") {
            Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
            "[System.Windows.Forms.MessageBox]::Show('Bad credentials provided, please try again.','Invalid Credentials')" -WindowStyle Hidden
            $Credential = Get-CredentialFromUser
        } elseif ($_ -like "*is not null or empty*") {
            $OKC = Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
            "[System.Windows.Forms.MessageBox]::Show('Please enter a password. Click Cancel to cancel the operation.','Whoopsie.',OKCancel)" -WindowStyle Hidden
            if ($OKC -eq "Cancel") { return -1 }
            $Credential = Get-CredentialFromUser
        } else {
            throw $_
        }
    }

    Set-StoredPSCredential $Credential
}

Export-ModuleMember -Function Get-StoredPSCredential