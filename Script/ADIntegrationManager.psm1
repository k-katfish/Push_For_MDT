if (-Not (Get-Module ConfigManager)) { Import-Module $PSScriptRoot\ConfigManager.psm1 }

$script:ADPreference = Get-ADIntegrationPreference

function Use-ADIntegration {
    #$ADPreference = Get-ADIntegrationPreference
    return $script:ADPreference.UseIntegration
}

function Get-ADOUs {
    $OrganizationalUnits = Get-ADOrganizationalUnit -Filter *
    $OUs = New-Object System.Collections.ArrayList
    $OrganizationalUnits | ForEach-Object {
        $OU_DNdata = $_.DistinguishedName.SubString(0, $_.DistinguishedName.IndexOf("DC=")-1).Split(',')
        [Array]::Reverse($OU_DNdata)
        $OU_DNString = ""
        $OU_DNdata | ForEach-Object {
            $OU_DNString += "$($_.Substring(3))\"
        }
        if ($script:ADPreference.ExcludedOUs -contains $OU_DNString) {} 
        else { $OUs.Add($OU_DNString) *> $null }
    }
    return $OUs
}

function Get-ADComputersInOU ($OrganizationalUnit) {

}

function Get-ExcludedOUs {
    return $script:ADPreference.ExcludedOUs
}

function Add-ExcludedOU ($ExcludeThisOU) {
    $ExcludedOUs = New-Object System.Collections.ArrayList
    $ExcludedOUs.AddRange($script:ADPreference.ExcludedOUs)
    $ExcludedOUs.Add($ExcludeThisOU)

    Set-ADIntegrationPreference -UseADIntegration $script:ADPreference.UseIntegration -ExcludedOUs $ExcludedOUs
}