if (Get-Module Microsoft.Powershell.Security) {Remove-Module Microsoft.PowerShell.Security}
Import-Module Microsoft.PowerShell.Security

function Get-StoredPSCredential {
    if (-Not $script:StoredPSCredential) {
        if (-Not (Test-Path "$env:APPDATA\Push\cmdata.dat")) {
            Write-Debug "Get-StoredPSCredential: No credentials provided yet. Requesting credentials."
            if (Get-CredentialFromUser -eq -1) {
                Write-Verbose "Get-StoredPSCredential: User refused to provide credential. Returning -1."
                return -1
            }
        } else {
            $CMData = [XML](Get-Content "$env:APPDATA\Push\cmdata.dat")
            $script:StoredPSCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $CMData.C.U.dat, ($CMData.C.P.dat | ConvertTo-SecureString)
            #$script:StoredPSCredential = $Credential
        }
    }

    return $script:StoredPSCredential
}

function Set-StoredPSCredential {
    param(
        [pscredential]$Credential
    )

    if (-Not (Test-Path "$env:APPDATA\Push\cmdata.dat")) {
        if (-Not (Test-Path "$env:APPDATA\Push")) { New-Item -Path "$env:APPDATA\Push" -ItemType Directory }
        New-Item -Path "$env:APPDATA\Push\cmdata.dat"
    }

    $CMData = New-Object xml
    $CMData.LoadXml("<C><U dat=''/><P dat=''/></C>")

    $CMData.C.U.dat = $Credential.UserName
    $CMData.C.P.dat = $Credential.Password | ConvertFrom-SecureString

    $CMData.Save("$env:APPDATA\Push\cmdata.dat")

    $script:StoredPSCredential = $Credential
}

function Test-Credential ([PSCredential]$Credential) {
    try {
        Start-Process Powershell -ArgumentList "return 0" -Credential $Credential -WorkingDirectory 'C:\Windows\System32' -NoNewWindow
    } catch {
        if ($_ -like "*password*") {
            Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
            "[System.Windows.Forms.MessageBox]::Show('Bad credentials provided, please try again.','Invalid Credentials')" -WindowStyle Hidden
            return -1
        } elseif ($_ -like "*is not null or empty*") {
            $OKC = Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
            "[System.Windows.Forms.MessageBox]::Show('Please enter a password. Click Cancel to cancel the operation.','Whoopsie.',OKCancel)" -WindowStyle Hidden
            if ($OKC -eq "Cancel") { return -3 }
            return -2
        } else {
            throw $_
        }
    }
}

function Test-StoredPSCredential {
    Test-Credential (Get-StoredPSCredential)
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

    if ((Test-Credential $Credential) -eq -1) {
        $Credential = Get-CredentialFromUser
    } elseif ((Test-Credential $Credential) -eq -2) {
        $Credential = Get-CredentialFromUser
    } elseif ((Test-Credential $Credential) -eq -3) {
        return -1
    } elseif ((Test-Credential $Credential) -eq 0) {
        Set-StoredPSCredential $Credential
    }
}

function New-StoredPScredential {
    $script:StoredPSCredential = ""
    Remove-Item -Path "$env:APPDATA\Push\cmdata.dat"
    Get-StoredPSCredential
}

Export-ModuleMember -Function New-StoredPScredential
Export-ModuleMember -Function Get-StoredPSCredential
Export-ModuleMember -Function Test-StoredPSCredential