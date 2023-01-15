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

function Invoke-RefreshDesign ($Form) {
  $Form.BackColor = Get-BackgroundColor
  $Form.ForeColor = Get-ForegroundColor
  $Form.Controls | ForEach-Object {
    try {
      $_.BorderStyle = Get-BorderStyle
      $_.FlatStyle = Get-FlatStyle
    } catch {}
    $_.BackColor = Get-BackgroundColor
    $_.ForeColor = Get-ForegroundColor
    $_.Font = Get-FontSettings
  }
}

function New-WinForm ($Text, $Size, $Icon, $StartPosition = 'CenterScreen', $AutoSize) {
  $Form = New-Object System.Windows.Forms.Form
  $Form.Text = $Text
  if ($Size) { $Form.ClientSize = New-Object System.Drawing.Size($Size[0], $Size[1]) }
  if ($AutoSize) { $Form.AutoSize = $true }
  $Form.BackColor = Get-BackgroundColor
  $Form.ForeColor = Get-ForegroundColor
  $Form.Icon = $Icon
  $Form.StartPosition = $StartPosition
  return $Form
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

function New-PictureBox ($Image, $Location) {
  $Image = Get-Item "$Image"
  Write-Verbose "Testing for image at $("$env:APPDATA\Push\Media\$($Image.Name)")"
  if (-Not (Test-Path "$env:APPDATA\Push\Media\$($Image.Name)")) {
    Write-Verbose "Not found. Copying image from $Image to $("$env:APPDATA\Push\Media\$($Image.Name)")"
    Copy-Item $Image "$env:APPDATA\Push\Media\$($Image.Name)"
  }
  $Picture = [System.Drawing.Image]::FromFile("$env:APPDATA\Push\Media\$($Image.Name)")

  $PictureBox = New-Object System.Windows.Forms.PictureBox
  $PictureBox.Location = New-Object System.Drawing.Point($Location[0], $Location[1])
  $PictureBox.Size = New-Object System.Drawing.Size($Picture.Width,$Picture.Height)
  $PictureBox.Image = $Picture

  return $PictureBox
}

function New-MessageBox ($Text, $Caption, $Buttons = 'OKCancel', $DefaultButton = 0, $Icon = 'Asterisk') {
  <#  Button types: AbortRetryIgnore , CancelTryContinue , OK , OKCancel , RetryCancel , YesNo , YesNoCancel
      Default Button: 0 (first), 256 (second), 512 (third), 768 (help) 
      Icon types: Asterisk/Information, Error/Hand/Stop, Exclamation/Warning, None, Question 
  #>
  return [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $Buttons, $Icon, $DefaultButton)
}

function New-ToastNotification ($Title, $Content, $TitleIcon, $BodyIcon) {
  <# Icon types: Asterisk/Information, Error/Hand/Stop, Exclamation/Warning, None, Question #>
  switch ($TitleIcon) {
    {"Asterisk", "Information"} { $TitleIcon = [System.Drawing.SystemIcons]::Information }
    {"Error", "Hand", "Stop"} { $TitleIcon = [System.Drawing.SystemIcons]::Error }
    {"Exclamation", "Warning"} { $TitleIcon = [System.Drawing.SystemIcons]::Warning }
  }

  if ($BodyIcon) { 
    switch ($BodyIcon) {
      {"Asterisk", "Information"} { $BodyIcon = [System.Drawing.SystemIcons]::Information }
      {"Error", "Hand", "Stop"} { $BodyIcon = [System.Drawing.SystemIcons]::Error }
      {"Exclamation", "Warning"} { $BodyIcon = [System.Drawing.SystemIcons]::Warning }
    }
  } else {
    $BodyIcon = [System.Windows.Forms.ToolTipIcon]::None
  }

  $Notify = New-Object System.Windows.Forms.NotifyIcon
  $Notify.Icon = $TitleIcon
  $Notify.Visible = $true
  $Notify.ShowBalloonTip(10, $Title, $Content, $BodyIcon)
}

function Get-FolderPathLameUI {
  $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
  if ($FolderBrowser.ShowDialog() -eq "OK") { return $FolderBrowser.SelectedPath }
  else { return $null }
}

function Get-FolderPathUI {
  # 'tis broken. But I hate the actual folderbrowserdialog, and really want to use the same openfiledialog but to open a folder. i'll come back to this someday.
  return $null
  $FolderBrowser = New-Object System.Windows.Forms.OpenFileDialog
  $FolderBrowser.ValidateNames = $false
  $FolderBrowser.CheckFileExists = $false
  $FolderBrowser.CheckPathExists = $true
  $FolderBrowser.Filter = "Folders|*."
  $Null = $FolderBrowser.ShowDialog()
  return $FolderBrowser.SelectedPath
}