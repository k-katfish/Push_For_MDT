<#
.SYNOPSIS
  Tool to Scan a remote computer for information.
.DESCRIPTION
  This tool is a sub component of PUSH_2.0, and can be used to scan a computer for hardware, software, user, file, etc. information.
.PARAMETER ComputerName
  The name of the computer to scan. 
.INPUTS
  A hostname to scan
.OUTPUTS
  A GUI window with information about the computer.
.NOTES
  Version:        1.0.8
  Author:         Kyle Ketchell, Matt Smith
  Creation Date:  May 29, 2022
.EXAMPLE
  Scan_Host.ps1 ETS_Test_Computer
#>
[cmdletBinding()]
param(
  [String]$Hostname=$env:COMPUTERNAME
)

Add-Type -AssemblyName System.Windows.Forms

if (Get-Module ConfigManager) {Remove-Module ConfigManager}
if (Get-Module ScanHost) { Remove-Module ScanHost }
if (Get-Module GUIManager) {Remove-Module GUIManager}
Import-Module $PSScriptRoot\ScanHost.psm1
Import-Module $PSScriptRoot\ConfigManager.psm1
Import-Module $PSScriptRoot\GUIManager.psm1

if (-not (Test-Connection $Hostname -quiet)) {[System.Windows.Forms.MessageBox]::Show("Computer offline", "Offline"); exit}
try {
  Invoke-WmiMethod -ComputerName $Hostname -Class Win32_Process 'Create' "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
  Start-Sleep 1
  Get-CimInstance -ComputerName $Hostname -ClassName Win32_ComputerSystem
} catch {
  [System.Windows.Forms.MessageBox]::Show("Computer appears to be online, but we're unable to scan it.")
  exit
}


$Form                       = New-Object System.Windows.Forms.Form
$Form.AutoSize              = $true
$Form.Text                  = "Scan results: $Hostname"
$Form.BackColor             = Get-BackgroundColor
#$Form.Icon = $Config.Design.Scan_Host_Icon

$ProcessorLabel = New-Label -Text "Processor" -Location (10, 10)
$ProcessorInfoBox = New-TextBox -Text "" -Location (10,33) -Size (300,210)
$PI = Get-ProcessorInfo $Hostname
$ProcessorInfoBox.Text      = "" 
$ProcessorInfoBox.AppendText("$($PI.Name)`r`n")
$ProcessorInfoBox.AppendText("$($PI.Speed)`r`n")
$ProcessorInfoBox.AppendText("$($PI.Cores) Cores`r`n")
$ProcessorInfoBox.AppendText("$($PI.LogicalProcessors) Logical Processors`r`n")
$ProcessorInfoBox.ReadOnly = $true
$ProcessorInfoBox.Multiline = $true


$HardwareLabel = New-Label -Text "Hardware" -Size (100, 23) -Location (315, 10)
$HardwareInfoBox = New-TextBox -Size (300,210) -Location (315,33)
$HardwareInfoBox.ReadOnly   = $true
$HardwareInfoBox.Multiline  = $true
#$HardwareInfoBox.ScrollBars = 'Vertical'
$HW = Get-HardwareInfo $Hostname
$HardwareInfoBox.Text       = ""
$HardwareInfoBox.AppendText("$($HW.Name)`r`n")
if ($HW.Name -ne $HW.DNSName) { $HardwareInfoBox.AppendText("Second Name: $($HW.DNSName)`r`n") }
if ($HW.OnDomain) { $HardwareInfoBox.AppendText("Domain: $($HW.Domain)`r`n") }
else { $HardwareInfoBox.AppendText("Workgroup: $($HW.Workgroup)`r`n") }
$HardwareInfoBox.AppendText("Make: $($HW.Manufacturer)`r`n")
$HardwareInfoBox.AppendText("Model: $($HW.Model)`r`n")
$HardwareInfoBox.AppendText("Serial: $($HW.Serial)`r`n")
$HardwareInfoBox.AppendText("Installed RAM: $($HW.RAM)`r`n")


$SoftwareLabel = New-Label -Text "Operating System" Size (130,23) -Location (620, 10)
$SoftwareInfoBox = New-TextBox -Size (300,210) -Location (620,33)
$SoftwareInfoBox.ReadOnly   = $true
$SoftwareInfoBox.Multiline  = $true
#$SoftwareInfoBox.ScrollBars = 'Vertical'
$SI = Get-SoftwareInfo $Hostname
$SoftwareInfoBox.Text = ""
$SoftwareInfoBox.AppendText("$($SI.Caption)`r`n")
$SoftwareInfoBox.AppendText("$($SI.Version)`r`n")
switch ($SI.Version) {
  '10.0.19044' { $SoftwareInfoBox.AppendText("21H2`r`n") }
  '10.0.19043' { $SoftwareInfoBox.AppendText("21H1`r`n") }
  '10.0.19042' { $SoftwareInfoBox.AppendText("20H2`r`n") }
  '10.0.19041' { $SoftwareInfoBox.AppendText("2004`r`n") }
  '10.0.18363' { $SoftwareInfoBox.AppendText("1909`r`n") }
  '10.0.18362' { $SoftwareInfoBox.AppendText("1903`r`n") }
  '10.0.17763' { $SoftwareInfoBox.AppendText("1809`r`n") }
  '10.0.17134' { $SoftwareInfoBox.AppendText("1803`r`n") }
  '10.0.16299' { $SoftwareInfoBox.AppendText("1709`r`n") }
  '10.0.14393' { $SoftwareInfoBox.AppendText("1607`r`n") }
}
$SoftwareInfoBox.AppendText("It is currently: $($SI.Time)`r`n")
$SoftwareInfoBox.AppendText("Boot time: $($SI.BootTime)`r`n")
$SoftwareInfoBox.AppendText("Current up-time: $($SI.Uptime)`r`n")
$SoftwareInfoBox.AppendText("OS Install Date: $($SI.InstallDate)`r`n")
$SoftwareInfoBox.AppendText("Registered to: $($SI.RUser), $($SI.ROrganization)`r`n")
$SoftwareInfoBox.AppendText("$($SI.Users)`r`n")



$DiskLabel = New-Label -Text "Disks" -Location (925, 10)
$DiskInfoBox = New-TextBox -Size (300, 210) -Location (925, 33)
$DiskInfoBox.ReadOnly       = $true
$DiskInfoBox.Multiline      = $true
$DiskInfoBox.ScrollBars     = 'Vertical'
$DI                         = Get-DiskInfo $Hostname
$DiskInfoBox.Text           = ""
$DI | ForEach-Object {
  if ($_.DeviceName) {
    $DiskInfoBox.AppendText("$($_.DeviceName) $($_.VolumeName)`r`n")
    $DiskInfoBox.AppendText("  $($_.UsedSpace) Used, $($_.PartitionSize) Available`r`n")
    $DiskInfoBox.AppendText("  $($_.FreeSpace) free`r`n")
    $DiskInfoBox.AppendText("  $($_.FileSystem)`r`n")
    $DiskInfoBox.AppendText("Physical Disk Information: $($_.DiskModel)`r`n")
    $DiskInfoBox.AppendText("  $($_.TotalDiskSize) Total Size of Disk`r`n")
    $DiskInfoBox.AppendText("  $($_.MediaType)`r`n")
#    $DiskInfoBox.AppendText("  $($_.DiskSerial)`n")
    $DiskInfoBox.AppendText("`r`n")
  }
}


$NetworkLabel = New-Label -Text "Network Card" -Location (315,245) 
$NetworkInfoBox = New-TextBox -Size (300, 210) -Location (315,268)
$NetworkInfoBox.ReadOnly       = $true
$NetworkInfoBox.Multiline      = $true
$NetworkInfoBox.ScrollBars     = 'Vertical'
$NI                         = Get-NetworkInfo $Hostname
$NetworkInfoBox.Text           = ""
$NetworkInfoBox.AppendText("Name: $($NI.Name)`r`n")
#$NetworkInfoBox.AppendText("Manufacturer: $($NI.Manufacturer)`r`n")
$NetworkInfoBox.AppendText("IP: $($NI.IPAddress)`r`n")
$NetworkInfoBox.AppendText("Subnet: $($NI.IPSubnet)`r`n")
$NetworkInfoBox.AppendText("Gateway: $($NI.DefaultIPGateway)`r`n")
$NetworkInfoBox.AppendText("MAC Address: $($NI.MACAddress)`r`n")
$NetworkInfoBox.AppendText("Adapter Type: $($NI.AdapterType)`r`n")
$NetworkInfoBox.AppendText("Speed: $($NI.Speed)`r`n")

if ($NI.DHCPEnabled) {
  $NetworkInfoBox.AppendText("DHCP Server: $($NI.DHCPServer)`r`n")
  $NetworkInfoBox.AppendText("Lease Obtained: $($NI.DHCPLeaseObtained)`r`n")
  $NetworkInfoBox.AppendText("Lease Expires: $($NI.DHCPLeaseExpires)`r`n")
}

$NetworkInfoBox.AppendText("DNS Hostname: $($NI.DNSHostName)`r`n")
$NetworkInfoBox.AppendText("DNS Domain: $($NI.DNSDomain)`r`n")
$NetworkInfoBox.AppendText("Last Reset: $($NI.TimeOfLastReset)`r`n")

<#
$UserLabel                  = New-Object System.Windows.Forms.Label       #
$UserLabel.Size             = New-Object System.Drawing.Size(100,23)      #
$UserLabel.Location         = New-Object System.Drawing.Point(10,277)     #
$UserLabel.Text             = "Disks"                                     #
# GUI options based on configuration                                      #
$UserLabel.Font             = New-Object System.Drawing.Font($Config.Design.FontName, $Config.Design.FontSize)
$UserLabel.BackColor        = $Config.ColorScheme.Background              #
$UserLabel.ForeColor        = $Config.ColorScheme.Foreground              #
                                                                          #
$UserInfoBox                = New-Object System.Windows.Forms.ListBox     #
$UserInfoBox.Size           = New-Object System.Drawing.Size(300,210)     # Needs to be changed because SansSkrit changes text size
# GUI options based on configuration                                      #
$UserInfoBox.Font           = New-Object System.Drawing.Font($Config.Design.FontName, $Config.Design.FontSize)
$UserInfoBox.BackColor      = $Config.ColorScheme.Background              #
$UserInfoBox.ForeColor      = $Config.ColorScheme.Foreground              # i got lazy ill finish it at work later
$UserInfoBox.Location       = New-Object System.Drawing.Point(10,300)     #
$UserInfoBox.ScrollBars     = 'Vertical'                                  #>

$MoreInfoButton = New-Button -Text "More Information" -Location (10, 245)
$MoreInfoButton.AutoSize    = $true

$MoreInfoButton.Add_Click({
  Start-Process powershell -ArgumentList "-NoExit",
    "Write-Host 'Win32_ComputerSystem'; Get-CimInstance Win32_ComputerSystem -ComputerName $Hostname | Format-List *;", 
    "Write-Host 'Win32_OperatingSystem'; Get-CimInstance Win32_OperatingSystem -ComputerName $Hostname | Format-List *;",
    "Write-Host 'Win32_LogicalDisk'; Get-CimInstance Win32_LogicalDisk -ComputerName $Hostname | Format-List *;",
    "Write-Host 'Win32_DiskDrive'; Get-CimInstance Win32_DiskDrive -ComputerName $Hostname | Format-List *;",
    "Write-Host 'Win32_Processor'; Get-CimInstance Win32_Processor -ComputerName $Hostname | Format-List *;",
    "Write-Host 'Win32_Processes'; Get-CimInstance Win32_Process -ComputerName $Hostname;",
    "Write-Host 'Win32_NetworkAdapter'; Get-CimInstance Win32_NetworkAdapter -ComputerName $Hostname | Format-List *;"
    "Write-Host 'Win32_NetworkAdapterConfiguration'; Get-CimInstance Win32_NetworkAdapter -ComputerName $Hostname | Format-List *;"
})

$ViewSoftwareButton          = New-Object System.Windows.Forms.Button     #
#$ViewSoftwareButton.Size     = New-Object System.Drawing.Size(110, 23)  # not sure if they were sized manually for a reason but we're trying autosizing
$ViewSoftwareButton.AutoSize = $true                                      #
$ViewSoftwareButton.Location = New-Object System.Drawing.Point(145, 245)  #
$ViewSoftwareButton.Text     = "View Installed Software"                  #
$ViewSoftwareButton.FlatStyle= $global:FlatStyle                          #

$ViewSoftwareButton.Add_Click({
  #$IS = Get-InstalledSoftware $Hostname                                   #
  [System.Windows.Forms.MessageBox]::Show("Looks like you've found a new feature! We haven't implemented this one quiiiiite yet, but someday we'll have this button launch a window where you can see a list of all the software on a computer, and remotely uninstall most of it.", "Pardon our dust!")                   #
})

$Form.Controls.AddRange(@(
  $ProcessorLabel,$ProcessorInfoBox,
  $HardwareLabel,$HardwareInfoBox,
  $SoftwareLabel,$SoftwareInfoBox,
  $DiskLabel,$DiskInfoBox,
  $NetworkLabel,$NetworkInfoBox
  #$UserLabel,$UserInfoBox
  $MoreInfoButton #,
#  $ViewSoftwareButton
))
$Form.ShowDialog()