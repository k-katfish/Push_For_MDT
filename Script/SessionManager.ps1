<#
.SYNOPSIS
  Script to remotely view, manage, and end user sessions on a remote Windows 10 computer. For which you are an administrator (duh).
.DESCRIPTION
  This script will scan a host and find any logged on users. You can then select user sessions to shadow or end. Alternativly, scan one or more hosts for a particular user by searching through the resutls of an AD querey.
.PARAMETER c, computer
  Required: Provide a computer name to scan for
.NOTES
  Version:       1.5
  Author:        Kyle Ketchell
  Creation Date: 6/21/22
.EXAMPLE
  .\SessionManager.ps1
.EXAMPLE
  .\SessionManager.ps1 -s -c MyOfficeComputer
#>
[cmdletBinding()]
param(
  [Alias("C")][String]$Computer
)

#######################################################################################
# PUSH Session Manager                                                                #
# View and Edit sessions on a remote computer                                         #
#                                                                                     #
# Author: Kyle Ketchell (Software Guru)                                               #
#         kkatfish@cs.colostate.edu                                                   #
#         6/21/2022                                                                   #
#######################################################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (Get-Module ConfigManager) { Remove-Module ConfigManager }
if (Get-Module SessionManager) { Remove-Module SessionManager}
if (Get-Module GUIManager) { Remove-Module GUIManager }

Import-Module $PSScriptRoot\ConfigManager.psm1
Import-Module $PSScriptRoot\SessionManager.psm1
Import-Module $PSScriptRoot\GUIManager.psm1

$global:Sessions = ""

function Main {
  $SessionManagerForm               = New-Object System.Windows.Forms.Form
  $SessionManagerForm.Text          = "Session Manager"
  $SessionManagerForm.Size          = New-Object System.Drawing.Size(600,400)
  $SessionManagerForm.StartPosition = 'CenterScreen'
  $SessionManagerForm.BackColor     = Get-BackgroundColor
  $SessionManagerForm.ForeColor     = Get-ForegroundColor
  #$SessionManagerForm.Icon          = $Config.Design.Icon                             #
  $SessionManagerForm.Font          = Get-FontSettings

  $FindLabel = New-Label -Text "Find:" -Location (10, 10)
  $FindDropdown = New-ComboBox -Location (50, 10) -Size (300, 23)
  $FindDropdown.Items.AddRange(@(
    "All users on [some computer]",
    "[Some user] on [some computer]",
    "[Some User] on a PUSH group of computers",
    "All Users on a PUSH group of Computers"
#    "[Some User] on an AD group of computers",                                        #
#    "All users on an AD group of computers"))                                         #
  ))
#  if ($Computer) { $FindDropdown.SelectedIndex = 0 }                                  #

  $HostnameLabel = New-Label -Text "Computer: " -Location (10, 35)
  $HostnameBox = New-TextBox -Location (85, 35) -Size (200, 23)
  $HostnameBox.ForeColor = Get-BackgroundColor
  $HostnameBox.BackColor = Get-ForegroundColor
  $HostnameBox.Add_KeyDown({
    if ($PSItem.KeyCode -eq "Enter") { $FindButton.PerformClick() }
  })
  $HostnameBox.Enabled   = $false

  $GroupLabel = New-Label -Text "Group: " -Location (290, 35)
  $GroupBox = New-ComboBox -Location (385, 35) -Size (200, 23)
  $GroupBox.ForeColor = Get-BackgroundColor
  $GroupBox.BackColor = Get-ForegroundColor
  $GroupBox.Enabled   = $false
  $GroupBox.Add_KeyDown({
    if ($PSItem.KeyCode -eq "Enter") { $FindButton.PerformClick() }
  })
  $SessionManagerForm.Controls.Add($GroupBox)

  $UsernameLabel = New-Label -Text "Username: " -Location (10, 60)
  $UsernameBox = New-TextBox -Location (85, 60) -Size (200, 23)
  $UsernameBox.ForeColor = Get-BackgroundColor #Yes this is intentional
  $UsernameBox.BackColor = Get-ForegroundColor #Yes this is intentional
  $UsernameBox.Enabled   = $false
  $UsernameBox.Add_KeyDown({
    if ($PSItem.KeyCode -eq "Enter") { $FindButton.PerformClick() }
  })
  $SessionManagerForm.Controls.AddRange(@($FindLabel, $FindDropdown, $HostnameLabel, $HostnameBox, $GroupLabel, $GroupBox, $UsernameLabel, $UsernameBox))
  
  $FindDropdown.Add_SelectedIndexChanged({
    switch ($FindDropdown.SelectedItem) {
      "All users on [some computer]" {
        $HostnameBox.BackColor = Get-BackgroundColor
        $HostnameBox.ForeColor = Get-ForegroundColor
        $HostnameBox.Enabled   = $true
        $UsernameBox.BackColor = Get-ForegroundColor
        $UsernameBox.ForeColor = Get-BackgroundColor
        $UsernameBox.Enabled   = $false
        $GroupBox.BackColor    = Get-ForegroundColor
        $GroupBox.ForeColor    = Get-BackgroundColor
        $GroupBox.Enabled      = $false
      }
      "[Some user] on [some computer]" {
        $HostnameBox.BackColor = Get-BackgroundColor
        $HostnameBox.ForeColor = Get-ForegroundColor
        $HostnameBox.Enabled   = $true
        $UsernameBox.BackColor = Get-BackgroundColor
        $UsernameBox.ForeColor = Get-ForegroundColor
        $UsernameBox.Enabled   = $true
        $GroupBox.BackColor    = Get-ForegroundColor
        $GroupBox.ForeColor    = Get-BackgroundColor
        $GroupBox.Enabled      = $false
      }
      "[Some User] on a PUSH group of computers" {
        $HostnameBox.BackColor = Get-ForegroundColor
        $HostnameBox.ForeColor = Get-BackgroundColor
        $HostnameBox.Enabled   = $false
        $UsernameBox.BackColor = Get-BackgroundColor
        $UsernameBox.ForeColor = Get-ForegroundColor
        $UsernameBox.Enabled   = $true
        $GroupBox.BackColor    = Get-BackgroundColor
        $GroupBox.ForeColor    = Get-ForegroundColor
        $GroupBox.Enabled      = $true
        $GroupLabel.Text       = "PUSH Group:"
        $GroupBox.Items.Clear()
        $GroupBox.Text = ""
        $Groups = Get-ChildItem (Get-GroupsFolderLocation) | Select-Object -Property Name
        $Groups | ForEach-Object {
          $GroupBox.Items.Add($_.Name.SubString(0, $_.Name.length-4))
        }
      }
      "All Users on a PUSH group of Computers" {
        $HostnameBox.BackColor = Get-ForegroundColor
        $HostnameBox.ForeColor = Get-BackgroundColor
        $HostnameBox.Enabled   = $false
        $UsernameBox.BackColor = Get-ForegroundColor
        $UsernameBox.ForeColor = Get-BackgroundColor
        $UsernameBox.Enabled   = $false
        $GroupBox.BackColor    = Get-BackgroundColor
        $GroupBox.ForeColor    = Get-ForegroundColor
        $GroupBox.Enabled      = $true
        $GroupLabel.Text = "PUSH Group:"
        $GroupBox.Items.Clear()
        $GroupBox.Text = ""
        $Groups = Get-ChildItem (Get-GroupsFolderLocation) | Select-Object -Property Name
        $Groups | ForEach-Object {
          $GroupBox.Items.Add($_.Name.SubString(0, $_.Name.length-4))
        }
      }
      <#"[Some User] on an AD group of computers"{                                      # Some user on an AD Group:
        $HostnameBox.BackColor = Get-ForegroundColor                              #
        $HostnameBox.ForeColor = Get-BackgroundColor                              #
        $HostnameBox.Enabled   = $false                                               #    Disable the hostname box
        $UsernameBox.BackColor = Get-BackgroundColor                              #
        $UsernameBox.ForeColor = Get-ForegroundColor                              #
        $UsernameBox.Enabled   = $true                                                #    Enable the username box
        $GroupBox.BackColor    = Get-BackgroundColor                              #
        $GroupBox.ForeColor    = Get-ForegroundColor                              #
        $GroupBox.Enabled      = $true                                                #    Enable the groups dropdown
        $GroupLabel.Text = "AD Group:"                                                #    Set the group label to "AD Group:"
        $GroupBox.Items.Clear()                                                       #    Clear the groups dropdown
        $GroupBox.Text = ""
        $Config.Preferences.AD_Preferences.OUs.OU | ForEach-Object {                  #    Get the OUs from the Config object (draws from the configuration file)
          $GroupBox.Items.Add($_.Name)                                                #    add the name of the OU to the group box
        }                                                                             #
      }                                                                               #
      "All users on an AD group of computers" {                                       # All users on an AD Group:
        $HostnameBox.BackColor = Get-ForegroundColor                              #
        $HostnameBox.ForeColor = Get-BackgroundColor                              #
        $HostnameBox.Enabled   = $false                                               #    Disable the hostname box
        $UsernameBox.BackColor = Get-ForegroundColor                              #
        $UsernameBox.ForeColor = Get-BackgroundColor                              #
        $UsernameBox.Enabled   = $false                                               #    Disable the username box
        $GroupBox.BackColor    = Get-BackgroundColor                              #
        $GroupBox.ForeColor    = Get-ForegroundColor                              #
        $GroupBox.Enabled      = $true                                                #    Enable the Group box
        $GroupLabel.Text = "AD Group:"                                                #    Set the group label to "AD Group:"
        $GroupBox.Items.Clear()                                                       #    Clear out the group box dropdown
        $GroupBox.Text = ""                                                           #
        $Config.Preferences.AD_Preferences.OUs.OU | ForEach-Object {
          $GroupBox.Items.Add($_.Name)
        }
      }#>
    }
  })

  $FindButton = New-Button -Text "Find!" -Location (290, 60) -Size (50, 23)
  $ResultList = New-ListBox -Location (10, 100) -Size (300, 200)
  $CountLabel = New-Label -Text "Count: " -Location (10, 305)
  $SessionManagerForm.Controls.AddRange(@($FindButton, $ResultList, $CountLabel))
  
  $FindButton.Add_Click({
    $ResultList.Items.Clear()
    switch ($FindDropdown.SelectedItem) {
      "All users on [some computer]" {
        $Hostname = $HostnameBox.Text
        $global:Sessions = Get-Quser -ServerName $Hostname
        $global:Sessions | ForEach-Object {
          if ($_.Server -and $_.Username) { $ResultList.Items.Add("$($_.Server) : $($_.UserName)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }
      "[Some user] on [some computer]" {
        $Username = $UsernameBox.Text
        $Hostname = $HostnameBox.Text
        $global:Sessions = Get-Quser -ServerName $Hostname | Where-Object { $_.UserName -eq $Username }
        $global:Sessions | ForEach-Object {
          if ($_.Server -and $_.Username) { $ResultList.Items.Add("$($_.Server) : $($_.UserName)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }
      "[Some User] on a PUSH group of computers" {
        $Username = $UsernameBox.Text
        $Content = Get-Content "$(Get-GroupsFolderLocation)\$($GroupBox.Text).txt"
        $Hostnames = New-Object System.Collections.ArrayList
        $Content | ForEach-Object { Write-Host $_; $Hostnames.Add($_) }
        $Hostnames | ForEach-Object { Write-Host $_ }
        $global:Sessions = $Hostnames | Get-QUser | Where-Object {$_.Username -eq $Username }
        $global:Sessions | ForEach-Object {
          if ($_.Server -and $_.Username) { $ResultList.Items.Add("$($_.Server) : $($_.Username)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }
      "All Users on a PUSH group of Computers" {
        $Content = Get-Content "$(Get-GroupsFolderLocation)\$($GroupBox.Text).txt"
        $Hostnames = New-Object System.Collections.ArrayList
        $Content | ForEach-Object { Write-Host $_; $Hostnames.Add($_) }
        $Hostnames | ForEach-Object { Write-Host $_ }
        $global:Sessions = $Hostnames | Get-Quser
        $global:Sessions | ForEach-Object {
          if ($_.Server -and $_.Username) { $ResultList.Items.Add("$($_.Server) : $($_.Username)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }
      <#"[Some User] on an AD group of computers" {
        $Username = $UsernameBox.Text
        $ADQuery = $Config.Preferences.AD_Preferences.OUs.OU | Where-Object { $_.Name -eq $GroupBox.SelectedItem } | Select-Object -ExpandProperty AD_Query
        $global:Sessions = Get-ADComputer -Filter * -SearchBase $ADQuery | Get-Quser | Where-Object { $_.Username -eq $Username }
        $global:Sessions | ForEach-Object {
          if (-Not $_.Server -and -Not $_.Username) { }
          else { $ResultList.Items.Add("$($_.Server) : $($_.Username)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }
      "All users on an AD group of computers" {
        $ADQuery = $Config.Preferences.AD_Preferences.OUs.OU | Where-Object { $_.Name -eq $GroupBox.SelectedItem } | Select-Object -ExpandProperty AD_Query
        $global:Sessions = Get-ADComputer -Filter * -SearchBase $ADQuery | ForEach-Object { $_ | Get-Quser } # -WarningAction SilentlyContinue  #
        $global:Sessions | ForEach-Object {
          if (-Not $_.Server -and -Not $_.Username) { }
          else { $ResultList.Items.Add("$($_.Server) : $($_.Username)") }
        }
        $CountLabel.Text = "Count: $($ResultList.Items.Count)"
      }#>
    }
  })
  
  $DetailsButton = New-Button -Text "Details" -Location (320, 100) -Size (100, 23)
  $SessionManagerForm.Controls.Add($DetailsButton)

  $DetailsButton.Add_Click({
    $SelectedItem = $ResultList.SelectedItem -split ' +'
    $SelectedSession = $global:Sessions | Where-Object { $_.Server -eq $SelectedItem[0] -and $_.Username -eq $SelectedItem[2] }
    $Message = "Details about $($SelectedSession.Username) on $($SelectedSession.Server)`r`n" +
               "ID: $($SelectedSession.Id)`r`n" +
               "Name: $($SelectedSession.SessionName)`r`n" +
               "Logon time: $($SelectedSession.LogonTime)`r`n" +
               "State: $($SelectedSession.State)`r`n" +
               "IdleTime: $($SelectedSession.IdleTime)`r`n" +
               "IsCurrentSession: $($SelectedSession.IsCurrentSession)"
    [System.Windows.Forms.MessageBox]::Show($Message, $Config.About.Title)
  })

  $ShadowButton = New-Button -Text "Shadow" -Location (320, 125) -Size (100, 23)
  $SessionManagerForm.Controls.Add($ShadowButton)

  $ShadowButton.Add_Click({
    $SelectedItem = $ResultList.SelectedItem -split ' +'
    $SelectedSession = $global:Sessions | Where-Object { $_.Server -eq $SelectedItem[0] -and $_.Username -eq $SelectedItem[2] }
    $isok = [System.Windows.Forms.MessageBox]::Show("In order to use this feature you must be ON THE PHONE with the client. Are you ON THE PHONE with the client?", "Shadow Confirmation", "YESNO")
    if ($isok -eq "YES") {
      $isreallyok = [System.Windows.Forms.MessageBox]::Show("Are you sure? And they're ok with this?", "Extra Confirmation", "YESNO")
      if ($isreallyok -eq "YES") {
        Write-Host "Shadowing"
        ShadowForm $SelectedSession
      }
    }
  })
  
  $LogoffButton = New-Button -Text "Logoff" -Location (320, 150) -Size (100, 23)
  $SessionManagerForm.Controls.Add($LogoffButton)
  
  $LogoffButton.Add_Click({
    $SelectedItem = $ResultList.SelectedItem -split ' +'
    $SelectedSession = $global:Sessions | Where-Object { $_.Server -eq $SelectedItem[0] -and $_.Username -eq $SelectedItem[2] }
    $isok = [System.Windows.Forms.MessageBox]::Show("You are about to log off $($SelectedSession.Username) from $($SelectedSession.Server). OK?", "Logoff Confirmation", "OKCancel")
    if ($isok -eq "OK") {
      $SelectedSession | Invoke-EndUserSession
    }
    $FindButton.PerformClick()
  })
  
  $RefreshButton = New-Button -Text "Refresh" -Location (320, 175) -Size (100, 23)
  $SessionManagerForm.Controls.Add($RefreshButton)

  $RefreshButton.Add_Click({
    $FindButton.PerformClick()
  })

  if ($Computer) {
    $FindDropdown.SelectedIndex = 0
    $HostnameBox.Text = $Computer
    $Hostname = $HostnameBox.Text
    $global:Sessions = Get-Quser -ServerName $Hostname
    $global:Sessions | ForEach-Object {
      if ($_.Server -and $_.Username) { $ResultList.Items.Add("$($_.Server) : $($_.Username)") }
    }
    $CountLabel.Text = "Count: $($ResultList.Items.Count)"
  }

  $SessionManagerForm.ShowDialog()
}

function ShadowForm {
  param($Session)
  $shadow_form = New-Object System.Windows.Forms.Form
  $shadow_form.Text = 'Shadow User Session'
  $shadow_form.Size = New-Object System.Drawing.Size(300,200)
  $shadow_form.StartPosition = 'CenterScreen'
  $shadow_form.TopMost = $true
  $shadow_form.BackColor = Get-BackgroundColor
  $shadow_form.ForeColor = Get-ForegroundColor

  $mstscControlFlag = New-Checkbox -Text "Control" -Location (10, 20) -Size (250,23)
  $mstscPromptFlag = New-Checkbox -Text "Connect as other user" -Location (10, 66) -Size (250, 23)
  $mstscAdminflag = New-Checkbox -Text "Admin" -Location (10, 43) -Size (250,23)
  $shadow_form.Controls.AddRange(@($mstscControlFlag, $mstscPromptFlag, $mstscAdminflag))

  $mstscCPFlag = New-Checkbox -Text "Consent" -Location (10, 89) -Size (250, 23)
  $mstscCPFlag.Checked = $true
  $mstscCPFlag.Visible = $false

  $SFContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
  $ToggleVisible = New-Object System.Windows.Forms.ToolStripMenuItem
  $ToggleVisible.Text = "Show Consent Prompt Flag"
  $ToggleVisible.Add_Click({ $mstscCPFlag.Visible = $true })
  $SFContextMenu.Items.Add($ToggleVisible)
  $shadow_form.ContextMenuStrip = $SFContextMenu

  $HasSeenNoPermissionMessage = $false
  $mstscCPFlag.Add_CheckStateChanged({
    if ($script:mstscCP) {
      if (-Not $HasSeenNoPermissionMessage) {[System.Windows.Forms.MessageBox]::Show("You do not have permission to perform that action.", "ETS requires consent", "OK")}
      $HasSeenNoPermissionMessage = $true
      $mstscCPFlag.Checked = $true
    }
    $script:mstscCP = $mstscCPFlag.checked
    $HasSeenNoPermissionMessage = $false
  })

  $CM = New-Object System.Windows.Forms.ContextMenuStrip
  $DisableCPMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
  $DisableCPMenuItem.Text = "Disable Consent Prompt"
  $DisableCPMenuItem.Add_Click({
    $yes = [System.Windows.Forms.MessageBox]::Show("Are you sure? You are about to connect to a users personal session without their _explicit_ consent given through a software popup. By clicking 'Yes' you accept full legal and ethical responsiblity for your actions. If you are sure of what you're doing, you may proceed, otherwise click NO.", "Disable consent prompt", "YesNo")
    if ($yes -eq "Yes") {
      $script:mstscCP = $false
      $mstscCPFlag.checked = $false
    }
  })
  $CM.Items.Add($DisableCPMenuItem)
  $mstscCPFlag.ContextMenuStrip = $CM
  $shadow_form.Controls.Add($mstscCPFlag)

  $okButton = New-Button -Text "OK" -Location (75, 132) -Size (75, 23)
  $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $shadow_form.AcceptButton = $okButton
  $shadow_form.Controls.Add($okButton)

  $cancelButton = New-Button -Text "Cancel" -Location (150, 132) -Size (75, 23)
  $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $shadow_form.CancelButton = $cancelButton
  $shadow_form.Controls.Add($cancelButton)

  $result = $shadow_form.ShowDialog()

  if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $shadow_form.Close()
    $Session | Invoke-ShadowUserSession -control:$mstscControlFlag.Checked -admin:$mstscAdminFlag.Checked -prompt:$mstscPromptFlag.Checked -noconsentprompt:(-Not $mstscCPFlag.Checked) -Force
  }
}

Main