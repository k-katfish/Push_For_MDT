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
        $OUs.Add($OU_DNString) *> $null
    }
    return $OUs
}

function Get-ADComputersInOU ($OrganizationalUnit) {

}