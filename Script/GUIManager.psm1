<#
  PUSH GUI Manager
  Author: Kyle Ketchell
  Version: 1.0
  Creation Date: 9/4
#>

if (-Not (Get-Module ConfigManager)) {Import-Module $PSScriptRoot\ConfigManager.psm1}

function Invoke-RefreshColors ($Form) {
  $Form.BackColor = Get-BackgroundColor
  $Form.ForeColor = Get-ForegroundColor
  $Form.Controls | ForEach-Object {
    $_.BackColor = Get-BackgroundColor
    $_.ForeColor = Get-ForegroundColor
    $_.Font = Get-FontSettings
  }
}

function New-Button ($Text, $Location, $Size) {
  $Button = New-Object System.Windows.Forms.Button
  $Button.Text = $Text
  $Button.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $Button.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
  $Button.BackColor = Get-BackgroundColor
  $Button.ForeColor = Get-ForegroundColor
  $Button.Font = Get-FontSettings
  $Button.FlatStyle = Get-FlatStyle
  return $Button
}

function New-Label ($Text, $Location) {
  $Label = New-Object System.Windows.Forms.Label
  $Label.Text = $Text
  $Label.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $Label.AutoSize = $true
  $Label.BackColor = Get-BackgroundColor
  $Label.ForeColor = Get-ForegroundColor
  $Label.Font = Get-FontSettings
  return $Label
}

function New-ComboBox ($Location, $Size, $Text = "Select...") {
  $ComboBox = New-Object System.Windows.Forms.ComboBox
  $ComboBox.Text = $Text
  $ComboBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $ComboBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
  $ComboBox.BackColor = Get-BackgroundColor
  $ComboBox.ForeColor = Get-ForegroundColor
  $ComboBox.Font = Get-FontSettings
  $ComboBox.FlatStyle = Get-FlatStyle
  return $ComboBox
}

function New-TextBox ($Location, $Size) {
  $TextBox = New-Object System.Windows.Forms.TextBox
  $TextBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $TextBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
  $TextBox.BackColor = Get-BackgroundColor
  $TextBox.ForeColor = Get-ForegroundColor
  $TextBox.Font = Get-FontSettings
  return $TextBox
}

function New-ListBox ($Location, $Size) {
  $ListBox = New-Object System.Windows.Forms.ListBox
  $ListBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $ListBox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
  $ListBox.BackColor = Get-BackgroundColor
  $ListBox.ForeColor = Get-ForegroundColor
  $ListBox.Font = Get-FontSettings
  $ListBox.BorderStyle = Get-BorderStyle
  return $ListBox
}

function New-Checkbox ($Text, $Location, $Size) {
  $Checkbox = New-Object System.Windows.Forms.CheckBox
  $Checkbox.Text = $Text
  $Checkbox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $Checkbox.Size = New-Object System.Drawing.Size($Size[0], $Size[1])
  $Checkbox.BackColor = Get-BackgroundColor
  $Checkbox.ForeColor = Get-ForegroundColor
  $Checkbox.Font = Get-FontSettings
  return $Checkbox
}