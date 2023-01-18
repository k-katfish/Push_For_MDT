if (-Not (Get-Module ConfigManager)) { Import-Module $PSScriptRoot\ConfigManager.psm1 }

#$script:ADPreference = Get-ADIntegrationPreference

function Use-ADIntegration {
    #$ADPreference = Get-ADIntegrationPreference
    return (Get-ADIntegrationPreference).UseIntegration
}

function Convert-DNToString ($DistinguishedName) {
    $OU_DNdata = $DistinguishedName.SubString(0, $DistinguishedName.IndexOf("DC=")-1).Split(',')
    [Array]::Reverse($OU_DNdata)
    $OU_DNString = ""
    
    (0..($OU_DNData.Count-1)) | ForEach-Object {
        if ($_ -eq 0) {
            $OU_DNString += "$($OU_DNdata[$_].Substring(3))"
        } else {
            $OU_DNString += "\$($OU_DNdata[$_].Substring(3))"
        }
    }

    return $OU_DNString
}

function Get-OUFromDNString ($CleanDistinguishedName) {
    Write-Verbose "Converting $CleanDistinguishedName to existing DN"
    $OU_DNData = $CleanDistinguishedName.Split('\')
    [Array]::Reverse($OU_DNData)
    $OU_DNString = ""

    $OU_DNData | ForEach-Object {
        $OU_DNString += "OU=$_,"
    }

    $DistinguishedName = $OU_DNString + "$((Get-ADDomain).DistinguishedName)" #$script:OrganizationalUnits | Where-Object { $_.DistinguishedName -like "$OU_DNString*" }
    Write-Verbose $DistinguishedName
    return $DistinguishedName
}

function Get-ADOUs {
    $script:OrganizationalUnits = Get-ADOrganizationalUnit -Filter *
    $OUs = New-Object System.Collections.ArrayList
    $OrganizationalUnits | ForEach-Object {
        <#$OU_DNdata = $_.DistinguishedName.SubString(0, $_.DistinguishedName.IndexOf("DC=")-1).Split(',')
        [Array]::Reverse($OU_DNdata)
        $OU_DNString = ""
        
        (0..($OU_DNData.Count-1)) | ForEach-Object {
            if ($_ -eq 0) {
                $OU_DNString += "$($OU_DNdata[$_].Substring(3))"
            } else {
                $OU_DNString += "\$($OU_DNdata[$_].Substring(3))"
            }
        }#>

        $OU_DNString = Convert-DNToString $_.DistinguishedName

        if ((Get-ADIntegrationPreference).ExcludedOUs -contains $OU_DNString) {} 
        else { $OUs.Add($OU_DNString) *> $null }
    }
    return $OUs
}

function Get-ADComputersInOU ($CleanOUDNString) {
    $OU = Get-OUFromDNString $CleanOUDNString
    $Computers = New-Object System.Collections.ArrayList
    Get-ADComputer -SearchBase "$OU" -Filter "Enabled -eq 'true'" | ForEach-Object {
        $Computers.Add($_.Name) *> $null
    }
    $Computers.Sort()
    return $Computers
}

function Get-ExcludedOUs {
    return (Get-ADIntegrationPreference).ExcludedOUs
}

function Set-ExcludedOUs ($ExcludedOUs) {
    #$ExcludedOUs = New-Object System.Collections.ArrayList
    #$ExcludedOUs.AddRange((Get-ADIntegrationPreference).ExcludedOUs)
    #$ExcludedOUs.Add($ExcludeThisOU)
    Set-ADIntegrationPreference -UseADIntegration (Get-ADIntegrationPreference).UseIntegration -ExcludedOUs $ExcludedOUs
}

function Add-ExcludedOU ($ExcludeThisOU) {
    $ExcludedOUs = New-Object System.Collections.ArrayList
    $ExcludedOUs.AddRange((Get-ADIntegrationPreference).ExcludedOUs)
    $ExcludedOUs.Add($ExcludeThisOU)

    Set-ADIntegrationPreference -UseADIntegration (Get-ADIntegrationPreference).UseIntegration -ExcludedOUs $ExcludedOUs
}

function Remove-ExcludedOU ($IncludeThisOU) {
    $ExcludedOUs = New-Object System.Collections.ArrayList
    $ExcludedOUs.AddRange((Get-ADIntegrationPreference).ExcludedOUs)
    $ExcludedOUs.Remove($IncludeThisOU)

    Set-ADIntegrationPreference -UseADIntegration (Get-ADIntegrationPreference).UseIntegration -ExcludedOUs $ExcludedOUs
}