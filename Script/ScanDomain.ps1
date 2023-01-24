<#
.SYNOPSIS
  Tool to Scan a Domain, OU, or CN for information.
.DESCRIPTION
  This tool will create a csv file (which you can then open in Excel and do with what you will) of data gathered about
  all of the computers in a particular domain, OU, or CN. Provide the Active Directory Search Base style string with the
  parameter -SearchBase. It'd better be right 'cause I won't check it.
.PARAMETER SearchBase
  An Active Directory Search Base string. Example: "OU=Domain Computers,DC=MyDomain,DC=COM"
.INPUTS
  A searchbase to scan
.OUTPUTS
  A .csv file with information about all [online] computers in your SearchBase string.
.NOTES
  Version:        1.1
  Author:         Kyle Ketchell
  Creation Date:  January 16, 2023
.PARAMETER SearchBase
  An AD SearchBase string. This script uses Get-ADComputer to find Active Directory computers in your Search Base.
.PARAMETER Filter
  An AD Filter. By default this script will use the filter "Enabled -eq 'true'"
.PARAMETER OutputFile
  [Optional], the name of a file to write this information to. It ought to be a .csv file. The default file is "%DESKTOP%\[SearchBase]_MM_dd_yyy-hh.mm.csv"
.EXAMPLE
  ScanDomain.ps1 -SearchBase "OU=Domain Computers,DC=MyDomain,DC=COM"
#>
[cmdletBinding()]
param(
    [Parameter(Mandatory=$true)][String]$SearchBase,
    [String]$Filter = "Enabled -eq 'true'",
    [Parameter()][String]$OutputFile
)

if (-Not ($SearchBase)) { 
  Import-Module $PSScriptRoot\GUIManager.psm1
  $SelectOUForm = New-WinForm -Text "Scan OU/Domain" -Size (400, 400) -Icon "$PSScriptRoot\..\Media\scan_host_icon.ico"
  $OUDropdown   = New-ComboBox -Text "Select OU/Domain..." -Location (16,25) -Size (300, 25)
  $OFLabel      = New-Label -Text "Output File Location: " -Location (16, 50)
  $OutFileBox   = New-TextBox -Location (150, 50) -Size (300, 25)
  $OutFileBox.Text = "$env:USERPROFILE\Desktop\ScanResults.csv"
  $ScanButton   = New-Button -Location (16, 75) -Size (100, 25)
  $ScanButton.Add_Click({
    $SearchBase = Get-OUFromDNString $OUDropdown.SelectedItem
    $OutputFile = $OutFileBox.Text
    Start-Process Powershell -ArgumentList "powershell /c $PSScriptRoot\ScanDomain.ps1 -SearchBase $SearchBase -OutputFile $OutputFile" <#-NoNewWindow#> -WindowStyle:Hidden;
    exit
  })
  $SelectOUForm.Control.Items.AddRange(@($OUDropdown, $OFLabel, $OutFileBox, $ScanButton))
  $SelectOU.ShowDialog()
}

if (Get-Module ScanHost) { Remove-Module ScanHost }
Import-Module $PSScriptRoot\ScanHost.psm1

if (-Not ($OutputFile)) {
    $OutputFile = "$env:USERPROFILE\Desktop\$($SearchBase.Substring(3, $SearchBase.IndexOf(',')-3))_$(Get-Date -Format MM_dd_yyyy-hh.mm).csv"
}

if (-Not (Test-Path $OutputFile)) {
    New-Item $OutputFile -ItemType File
}

Add-Content $OutputFile "Name,Model,RAM,Manufacturer,Serial,Processor,Cores,Speed,OS Install Date,Version,Uptime,Caption,BootTime,Disk Letter,Disk Name,Disk Model,Disk Size,NIC Manufacturer,NIC MAC Address,NIC Name,NIC ServiceName,NIC Product Name,GPU Name,GPU Driver,GPU Chip,GPU Resolution,vRAM"

$ComputerName = Get-ADComputer -SearchBase $SearchBase -Filter $Filter

$ScanHostModule = "$PSScriptRoot\ScanHost.psm1"

if ($PSVersionTable.PSVersion.Major -gt 6) {
    <#GottaGoFast!#>

    $ComputerName | ForEach-Object -Parallel {
        if (-Not (Test-Connection $_.Name -Quiet)) {
            Write-Host "Unable to connect to host: $($_.Name)"
            continue
        }

        Write-Host "Scanning host $($_.Name)"

        Import-Module $using:ScanHostModule
        $CimSession = New-CimSession -ComputerName $_.Name -SessionOption (New-CimSessionOption -Protocol DCOM)

        $HardwareInfo  = Get-HardwareInfo  -CimSession $CimSession
        $ProcessorInfo = Get-ProcessorInfo -CimSession $CimSession
        $SoftwareInfo  = Get-SoftwareInfo  -CimSession $CimSession
        $DiskInfo      = Get-DiskInfo      -CimSession $CimSession
        $NetworkInfo   = Get-NetworkInfo   -CimSession $CimSession
        $GPUInfo       = Get-GPUInfo       -CimSession $CimSession

        #$Items = (@($HardwareInfo.Count, $ProcessorInfo.Count, $SoftwareInfo.Count, $DiskInfo.Count, $NetworkInfo.Count, $GPUInfo.Count) | Measure-Object).Maximum

#        (0..$Items) | ForEach-Object {
        #if ($HardwareInfo.Count -gt 1) {

        #}
            $InfoString = "$($HardwareInfo.Name)," +
            "$($HardwareInfo.Model)," +
            "$($HardwareInfo.RAM)," +
            "$($HardwareInfo.Manufacturer)," +
            "$($HardwareInfo.Serial)," +
            "$($ProcessorInfo.Name)," +
            "$($ProcessorInfo.Cores)," +
            "$($ProcessorInfo.Speed)," +
            "$($SoftwareInfo.InstallDate)," +
            "$($SoftwareInfo.Version)," +
            "$($SoftwareInfo.Uptime)," +
            "$($SoftwareInfo.Caption)," +
            "$($SoftwareInfo.BootTime)," +
            "$($DiskInfo.DeviceLetter)," +
            "$($DiskInfo.DeviceName)," +
            "$($DiskInfo.DiskModel)," +
            "$($DiskInfo.TotalDiskSize)," +
            "$($NetworkInfo.Manufacturer)," +
            "$($NetworkInfo.MACAddress)," +
            "$($NetworkInfo.Name)," +
            "$($NetworkInfo.ServiceName)," +
            "$($NetworkInfo.ProductName)," +
            "$($GPUInfo.Name)," +
            "$($GPUInfo.DriverVersion)," +
            "$($GPUInfo.ChipName)," +
            "$($GPUInfo.CurrentResolution)," + 
            "$($GPUInfo.VRAM)"

            Add-Content $using:OutputFile $InfoString #| Out-Null
#        }
    } -ThrottleLimit 16

} else {
    <#% -Parallel isn't an option in older versions of PS, so this is gonna take awhile.#>
    $ComputerName | ForEach-Object {
        if (-Not (Test-Connection $_.Name -Quiet)) {
            Write-Host "Unable to connect to host: $($_.Name)"
            continue
        }

        Write-Host "Scanning host $($_.Name)"

        Import-Module $using:ScanHostModule
        $CimSession = New-CimSession -ComputerName $_.Name -SessionOption (New-CimSessionOption -Protocol DCOM)

        $HardwareInfo  = Get-HardwareInfo  -CimSession $CimSession
        $ProcessorInfo = Get-ProcessorInfo -CimSession $CimSession
        $SoftwareInfo  = Get-SoftwareInfo  -CimSession $CimSession
        $DiskInfo      = Get-DiskInfo      -CimSession $CimSession
        $NetworkInfo   = Get-NetworkInfo   -CimSession $CimSession
        $GPUInfo       = Get-GPUInfo       -CimSession $CimSession

        $InfoString = "$($HardwareInfo.Name)," +
            "$($HardwareInfo.Model)," +
            "$($HardwareInfo.RAM)," +
            "$($HardwareInfo.Manufacturer)," +
            "$($HardwareInfo.Serial)," +
            "$($ProcessorInfo.Name)," +
            "$($ProcessorInfo.Cores)," +
            "$($ProcessorInfo.Speed)," +
            "$($SoftwareInfo.InstallDate)," +
            "$($SoftwareInfo.Version)," +
            "$($SoftwareInfo.Uptime)," +
            "$($SoftwareInfo.Caption)," +
            "$($SoftwareInfo.BootTime)," +
            "$($DiskInfo.DeviceLetter)," +
            "$($DiskInfo.DeviceName)," +
            "$($DiskInfo.DiskModel)," +
            "$($DiskInfo.TotalDiskSize)," +
            "$($NetworkInfo.Manufacturer)," +
            "$($NetworkInfo.MACAddress)," +
            "$($NetworkInfo.Name)," +
            "$($NetworkInfo.ServiceName)," +
            "$($NetworkInfo.ProductName)," +
            "$($GPUInfo.Name)," +
            "$($GPUInfo.DriverVersion)," +
            "$($GPUInfo.ChipName)," +
            "$($GPUInfo.CurrentResolution)," + 
            "$($GPUInfo.VRAM)"

        Add-Content $using:OutputFile $InfoString #| Out-Null
    }
}