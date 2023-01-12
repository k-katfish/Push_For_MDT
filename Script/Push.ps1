<#
.SYNOPSIS
  Tool to remotely install software, manage, and do other fun things with on domain-joined computers.
.DESCRIPTION
  PUSH is like any other Windows tool, it's better if you use the GUI.
.INPUTS
  nothing
.OUTPUTS
  A log file, optionally (enabled by default). You can disable the log file if you're running push in silent mode.
.NOTES
  Version:          2.1.1
  Authors:          Kyle Ketchell, Matt Smith
  Version Creation: November 7, 2022
  Orginal Creation: May 29, 2022
.PARAMETER configure, Configuration_File
  The path to a configuration file. For example, you might have a push configuration file stored somewhere else that you use for debugging or something idk.
.EXAMPLE
  push_2.0
.EXAMPLE
  push_2.0 -configure C:\Users\me\Desktop\push_config.xml
#>
[cmdletBinding()]
param(
  [Parameter()][Alias("h")][Switch]$help,
  [Parameter()][Alias("configure")]$Configuration_File,
  [Parameter()][PSCredential]$Credential
)

if ($help) {
  Get-Help "$PSScriptRoot\Push.ps1"
  exit
}

if (Get-Module ConfigManager) { Remove-Module ConfigManager }
if (Get-Module Install_Software) { Remove-Module Install_Software }
if (Get-Module GUIManager) { Remove-Module GUIManager }
if (Get-Module ToolStripManager) { Remove-Module ToolStripManager }
if (Get-Module CredentialManager) {Remove-Module CredentialManager}

Import-Module $PSScriptRoot\ConfigManager.psm1
Import-Module $PSScriptRoot\Install_Software.psm1
Import-Module $PSScriptRoot\GUIManager.psm1
Import-Module $PSScriptRoot\ToolStripManager.psm1
Import-Module $PSScriptRoot\CredentialManager.psm1

if ($Configuration_File) { Set-ConfigurationFile $Configuration_File }
if ($Credential) { Set-StoredPSCredential $Credential }

#$Config = Get-PUSH_Configuration $Configure -ColorScheme $ColorScheme -Design $DesignScheme -Application "PUSH"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#[System.Windows.Forms.Application]::EnableVisualStyles() # maybe this is a color thing?



<#
function GetCreds {
  param([PSCredential]$Credential)
  if (-Not $Credential) {
    $CredMessage = "Please provide valid credentials."
    $user = "$env:UserDomain\$env:USERNAME"
    $Credential = Get-Credential -Message $CredMessage -UserName $user
    if (-Not $Credential) {
      return -1
    }
  }

  try {
    Start-Process Powershell -ArgumentList "Start-Sleep",0 -Credential $Credential -WorkingDirectory 'C:\Windows\System32' -NoNewWindow
    Powershell -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope CurrentUser"
  } catch {
    if ($_ -like "*password*") {
      Write-Verbose "GetCred: Bad password provided."
      Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
      "[System.Windows.Forms.MessageBox]::Show('Bad Password! Try again!','Uh-oh.')" -WindowStyle Hidden
      $Credential = GetCreds
    } elseif ($_ -like "*is not null or empty*") {
      Write-Verbose "GetCred: No password provided."
      $OKC = Start-Process Powershell -ArgumentList "Add-Type -AssemblyName System.Windows.Forms;",
      "[System.Windows.Forms.MessageBox]::Show('Please enter a password. Click Cancel to cancel the operation.','Whoopsie.',OKCancel)" -WindowStyle Hidden
      if ($OKC -eq "Cancel") { return -1 }
      $Credential = GetCreds
    }
  }

  log "GetCreds: Returning Credential Object: $($Credential.Username)"
  return $Credential
}#>

$GUIForm                    = New-Object System.Windows.Forms.Form
$GUIForm.ClientSize         = New-Object System.Drawing.Point(900,400)
$GUIForm.Text               = "Push"
$GUIForm.Icon               = "$PSScriptRoot\..\Media\Icon.ico"
$GUIForm.StartPosition      = 'CenterScreen'
$GUIForm.BackColor = Get-BackgroundColor

#$SelectGroupLabel     = New-Label -Text "Select Group:" -Location (5,27)
$SelectGroup          = New-ComboBox -Text "Select Group..." -Location (16,25) -Size (256, 23)

$SelectAll            = New-Button -Text "Select All" -Location (16,50) -Size (128,23)
$SelectNone           = New-Button -Text "Select None" -Location (144,50) -Size (128,23)
$MachineList          = New-ListBox -Size (256,300) -Location (16,73)
$InstallOnSelMachines = New-Button -Text "Install Now" -Location (16,369) -Size (256,23)

$ManualSectionHeader  = New-Label -Text "Work on a single computer: " -Location (625, 25) 
$OrLabel              = New-Label -Text "Enter Name:" -Location (625,50)
$ManualNameTextBox    = New-TextBox -Location (625,75) -Size (256, 25)
$ApplyToManualEntry   = New-Button -Text "Install Now" -Location (625,100) -Size (256,25)
$EnterPS              = New-Button -Text "Enter PSSession" -Location (625,125) -Size (256,25)
$ScanComputer         = New-Button -Text "Scan Computer" -Location (625,150) -Size (256,25)

$RunExecutablesList   = New-ListBox -Size (345, 150) -Location (275,25)
$SoftwareFilterTextBox= New-TextBox -Size (150,23) -Location (330,174)
$SoftwareFilterLabel  = New-Label -Text "Search:" -Location (276,177)
$ShowHiddenCheckbox   = New-Checkbox -Text "Show Hidden" -Location (500,175) -Size (150,23)

$OutputBox            = New-TextBox -Size (345, 190) -Location (275,200)
$DoneLabel            = New-Label -Text "Done" -Location (($OutputBox.Location.X + 2), ($OutputBox.Location.Y + $OutputBox.Height + 130))

$GUIForm.Controls.AddRange(@(
  $SelectGroupLabel, $SelectGroup,
  $SelectAll, $SelectNone, $MachineList, $InstallOnSelMachines,
  $ManualSectionHeader, $OrLabel, $ManualNameTextBox,
  $ApplyToManualEntry, $EnterPS, $ScanComputer,
  $RunExecutablesList, $FixesCheckBox,
  $SoftwareFilterTextBox, $ShowHiddenCheckbox,
  $SoftwareFilterLabel, $OutputBox, $DoneLabel
))

$RunExecutablesList.SelectionMode = 'MultiExtended'
$MachineList.SelectionMode        = 'MultiExtended'
$OutputBox.ReadOnly               = $true
$OutputBox.MultiLine              = $true
$OutputBox.TextAlign              = "Left"
$OutputBox.WordWrap               = $false
$OutputBox.ScrollBars             = "Vertical,Horizontal"

$SelectGroup.Items.Add("All Machines") *> $null

Get-ChildItem -Path (Get-GroupsFolderLocation) | ForEach-Object {
  $GroupName = $_.Name.Substring(0,$_.Name.length-4)
  $SelectGroup.Items.Add($GroupName) *> $null
}

$SelectGroup.Add_SelectedIndexChanged({
  $SelectedGroup = $SelectGroup.SelectedItem
  $MachineList.Items.Clear()
  if ($SelectedGroup -ne "All Machines") {
    $GroupFileName = "$(Get-GroupsFolderLocation)\$SelectedGroup.txt"
    Get-Content -Path $GroupFileName | ForEach-Object {
      $MachineList.Items.Add($_) *> $null
    }
  } else {
    Get-ChildItem -Path (Get-GroupsFolderLocation) | ForEach-Object {
      $Groupfilename = "$(Get-GroupsFolderLocation)\$_"
      Get-Content -Path $GroupFileName | ForEach-Object {
        $MachineList.Items.Add($_) *> $null
      }
    }
  }
})

$SelectAll.Add_Click({
  For ($itemsLength = 0; $itemsLength -lt $MachineList.Items.Count; $itemsLength++){
    $MachineList.SetSelected($itemsLength,$true)
  }
})

$SelectNone.Add_Click({
  For ($itemsLength = 0; $itemsLength -lt $MachineList.Items.Count; $itemsLength++){
    $MachineList.SetSelected($itemsLength,$false)
  }
})


$InstallOnSelMachines.Add_Click({
  $CredentialObject = Get-StoredPSCredential
  if ($CredentialObject -eq -1) {
    return
  }
  $ListSelectedMachines = $MachineList.SelectedItems
  $ListSelectedSoftware = $RunExecutablesList.SelectedItems
  Write-Verbose "Installing $ListSelectedSoftware on $ListSelectedMachines"
  Invoke-Install -Machines $ListSelectedMachines -Installers $ListSelectedSoftware -Credential $CredentialObject -Config $Config
})

$ManualNameTextBox.Add_KeyDown({
  If ($PSItem.KeyCode -eq "Enter"){
    $ScanComputer.PerformClick()
  }
})

$ApplyToManualEntry.Add_Click({
  $CredentialObject = Get-StoredPSCredential
  if ($CredentialObject -eq -1) {
    return
  }
  $SelectedComputer = $ManualNameTextBox.text
  $SelectedSoftware = $RunExecutablesList.SelectedItems
  Write-Verbose "Installing $SelectedSoftware on $SelectedComputer"
  Invoke-Install -Machines $SelectedComputer -Installers $SelectedSoftware -Config $Config -Credential $CredentialObject
})

$EnterPS.Add_Click({
  $name = $ManualNameTextBox.text
  Start-Process powershell -ArgumentList "-NoExit","Enter-PSSession",$name
})

$ScanComputer.Add_Click({
  $OutputBox.AppendText("Scanning")
  Start-Sleep -Milliseconds 300
  $OutputBox.AppendText(".")
  Start-Sleep -Milliseconds 300
  $OutputBox.AppendText(".")
  Start-Sleep -Milliseconds 300
  $OutputBox.AppendText(".`r`n") # kind of rudimentary but its also awesome looking so deal with it - Matt
  Start-Process Powershell -ArgumentList "powershell $PSScriptRoot\ScanHost.ps1 -Hostname $($ManualNameTextBox.Text)" -WindowStyle:Hidden
})

function loadSoftware {
  $RunExecutablesList.Items.Clear()
  if ($ShowHiddenCheckbox.Checked) {
    Get-ChildItem -Path (Get-SoftwareFolderLocation) -filter "*$($SoftwareFilterTextBox.Text)*" -Force | ForEach-Object {
      $RunExecutablesList.Items.Add($_.Name) *> $null
    }
  } else {
    Get-ChildItem -Path (Get-SoftwareFolderLocation) -filter "*$($SoftwareFilterTextBox.Text)*" | ForEach-Object {
      $RunExecutablesList.Items.Add($_.Name) *> $null
    }
  }
}
loadSoftware

$SoftwareFilterTextBox.Add_TextChanged({ loadSoftware })

$ShowHiddenCheckbox.Add_Click({ loadSoftware })

$DoneLabel.Text      = "Not done yet"
$DoneLabel.Forecolor = Get-SuccessColor
$DoneLabel.visible   = $false
$DoneLabel.BringToFront()



$ToolStrip = New-Object System.Windows.Forms.MenuStrip
$ToolStrip.BackColor = Get-ToolStripBackgroundColor
$ToolStrip.ForeColor = Get-ForegroundColor

$TSFile = Get-NewTSItem "File"
$TSFUser = Get-NewTSItem "Launch Session Manager"
$TSFUser.Add_Click({ Start-Process Powershell -ArgumentList "powershell $PSScriptRoot\SessionManager.ps1" <#-NoNewWindow#> -WindowStyle:Hidden })
$TSFMDTShare = Get-NewTSItem "Connect to MDT Share"
$TSFMDTShare.Add_Click({
  #do - the - mdt - share - things...
})
$TSFExitItem = Get-NewTSItem "Exit"
$TSFExitItem.Add_Click({ $GUIForm.Close(); exit })
$TSFile.DropDownItems.AddRange(@($TSFUser, $TSFMDTShare, $TSFExitItem))

$TSComputer  = Get-NewTSItem "Remote Computer"
$TSCScanHost  = Get-NewTSItem "Scan Host"
$TSCScanHost.Add_Click({ Invoke-TSManageComputer "scan" })
$TSCFiles    = Get-NewTSItem "Files on C:\ Drive"
$TSCFiles.Add_Click({ Invoke-TSManageComputer "explorer.exe" })
$TSCLusr     = Get-NewTSItem "Users and Groups" 
$TSCLusr.Add_Click({ Invoke-TSManageComputer "lusrmgr.msc" })
$TSCGPEdit   = Get-NewTSItem "Edit Group Policy"
$TSCGPEdit.Add_Click({ Invoke-TSManageComputer "gpedit.msc" })
$TSCGPUpdate = Get-NewTSItem "Force Group Policy Update"
$TSCGPUpdate.Add_Click({ Invoke-TSManageComputer "gpupdate" })
$TSCGPolicy  = Get-NewTSItem "Manage Group Policy"
$TSCGPolicy.DropDownItems.AddRange(@($TSCGPEdit,$TSCGPUpdate))
#$TSCSessions = Get-NewTSItem "Manage User Sessions"              #   #   #  |
#$TSCSessions.Add_Click({ Invoke-TSManageComputer "sessions" })   #   #   # do this if we click it
$TSCManage   = Get-NewTSItem "Computer Manager"
$TSCManage.Add_Click({ Invoke-TSManageComputer "compmgmt.msc" })
$TSCRestart  = Get-NewTSItem "Restart Computer"
$TSCRestart.Add_Click({ Invoke-TSManageComputer "restart" })
$TSCShutdown = Get-NewTSItem "Shutdown Computer"
$TSCShutdown.Add_Click({ Invoke-TSManageComputer "shutdown" }) 
$TSComputer.DropDownItems.AddRange(@($TSCScanHost, $TSCFiles, $TSCLusr, $TSCGPolicy, <#$TSCSessions,#> $TSCManage, $TSCRestart, $TSCShutdown))

$TSHAbout    = Get-NewTSItem "About"
$TSHAbout.Add_Click({ Invoke-TSHelpReader "About.txt" })
$TSHGroups   = Get-NewTSItem "Managing PUSH Groups"
$TSHGroups.Add_Click({ Invoke-TSHelpReader "Groups.txt" })
$TSHSoftware = Get-NewTSItem "Adding Software to PUSH"
$TSHSoftware.Add_Click({ Invoke-TSHelpReader "Software.txt" })
$TSHPatches  = Get-NewTSItem "Adding Fixes to Push"
$TSHPatches.Add_Click({ Invoke-TSHelpReader "Scripts-Patches-Fixes.txt" })
$TSHMessages = Get-NewTSItem "Creating a PopUp message for a software"
$TSHMessages.Add_Click({ Invoke-TSHelpReader "Messages_Install.txt" })
$TSHRemote   = Get-NewTSItem "About Remote Computer Tools"
$TSHRemote.Add_Click({ Invoke-TSHelpReader "Remote_Computer.txt" })
#$TSHUseCSSP  = Get-NewTSItem "What is CredSSP?"
#$TSHUseCSSP.Add_Click({ Invoke-TSHelpReader "UseCSSP.txt" })
$TSHelp = Get-NewTSItem "Help"
$TSHelp.DropDownItems.AddRange(@($TSHAbout, $TSHGroups, $TSHSoftware, $TSHPatches, $TSHMessages, $TSHRemote))

$ToolStrip.Items.AddRange(@($TSFile,$TSComputer, $TSHelp))

#$ToolStrip.Items.Item($ToolSTrip.GetItemAt(5, 2)).DropDownItems.Add($TSFExitItem)

$GUIForm.Controls.Add($ToolStrip)



$GUIContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$GCMSetDarkMode = New-Object System.Windows.Forms.ToolStripMenuItem
$GCMSetLightMode = New-Object System.Windows.Forms.ToolStripMenuItem

$GCMSetDarkMode.Text = "Change to Dark Mode"
$GCMSetDarkMode.Add_Click({
  $GUIContextMenu.Items.Remove($GCMSetDarkMode)
  $GUIContextMenu.Items.Add($GCMSetLightMode)
  Set-ColorScheme "Dark"
  Invoke-RefreshColors $GUIForm
  RefreshToolStrip -ToolStrip $ToolStrip 
})
$GCMSetLightMode.Text = "Change to Light Mode"
$GCMSetLightMode.Add_Click({
  $GUIContextMenu.Items.Remove($GCMSetLightMode)
  $GUIContextMenu.Items.Add($GCMSetDarkMode)
  Set-ColorScheme "Light"
  Invoke-RefreshColors $GUIForm
  RefreshToolStrip -ToolStrip $ToolStrip 
})

$GUIContextMenu.Items.Add($GCMSetLightMode)

$GUIForm.ContextMenuStrip = $GUIContextMenu



#Invoke-GenerateGUI -Config $Config -Application "PUSH"
$GUIForm.ShowDialog()

#########################################################################################################################################################################################################################
# Ref    (I know I didn't use MLA format but I used Code format citations so...)                                                                                                                                        #
# Reference      | Explanation                                    | URL                                                                                                                                                 #
# POSHGUI        | Create a Powershell GUI (like, drag'n'drop)    | https://poshgui.com/                                                                                                                                #
# Hide popups    | Hide the "are you sure" security popup         | https://www.atmosera.com/blog/handling-open-file-security-warning/
#                                                                                                                                                                                                                       #
# Microsoft Docs | Multi-selection list box                       | https://docs.microsoft.com/en-us/powershell/scripting/samples/multiple-selection-list-boxes?view=powershell-7.2                                     #
# Microsoft Docs | Get-Credential                                 | https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential?view=powershell-7.2                                 #
# Microsoft Docs | Colors                                         | https://docs.microsoft.com/en-us/dotnet/api/system.drawing.color?view=net-6.0                                                                       #
# Microsoft Docs | List of Colors                                 | https://docs.microsoft.com/en-us/dotnet/api/system.windows.media.brushes?view=windowsdesktop-6.0                                                    #
# Microsoft Docs | ComboBox                                       | https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.combobox?view=windowsdesktop-6.0                                                   #
# Microsoft Docs | Parameters                                     | https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parameter_sets?view=powershell-7                           #
# Microsoft Docs | Parameter Sets                                 | https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/how-to-declare-parameter-sets?view=powershell-7.2                            #
# StackOverflow  | if network path exists                         | https://stackoverflow.com/questions/46565176/powershell-checking-if-network-drive-exists-if-not-map-it-then-double-check                            #
# theITBros      | For each item in a folder                      | https://theitbros.com/powershell-script-for-loop-through-files-and-folders/                                                                         #
# itechguides    | For each line in a file                        | https://www.itechguides.com/foreach-in-file-powershell/                                                                                             #
#########################################################################################################################################################################################################################
