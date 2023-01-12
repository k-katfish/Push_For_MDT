function Invoke-ConfigureTSItem {
    param($TSItem, $Text)
    $TSItem.Text = "&$Text"
    $TSItem.Font = Get-FontSettings
    $TSItem.BackColor = Get-ToolStripBackgroundColor
    $TSItem.ForeColor = Get-ForegroundColor
    $TSItem.Add_MouseEnter({ $this.ForeColor = Get-ToolStripHoverColor })
    $TSItem.Add_MouseLeave({ $this.ForeColor = Get-ForegroundColor })
    $TSItem.DropDownItems | ForEach-Object {
        Invoke-ConfigureTSItem $_ $_.Text.SubString(1)
    }
}
  
function Get-NewTSItem {
    param($Text)
    $NewTSItem = New-Object System.Windows.Forms.ToolStripMenuItem
    Invoke-ConfigureTSItem $NewTSItem -Text $Text
    return $NewTSItem
}

function RefreshToolStrip {
    param($ToolStrip)
 
    $ToolStrip.BackColor = Get-ToolStripBackgroundColor
    $ToolStrip.ForeColor = Get-ForegroundColor

    $ToolStrip.Items | ForEach-Object {
        Invoke-ConfigureTSItem $_ $_.Text.Substring(1)
    }
}
  
function Invoke-TSManageComputer ($ManageComponent) {
    $InputForm               = New-Object System.Windows.Forms.Form
    $InputForm.ClientSize    = New-Object System.Drawing.Size(250,125)
    $InputForm.text          = "$ManageComponent"
    $InputForm.TopMost       = $true
    $InputForm.StartPosition = 'CenterScreen'
    $InputForm.BackColor     = Get-BackgroundColor
    $HostnameLabel = New-Label -Text "Enter Computer name:" -Location (10, 20)
    $InputBox = New-TextBox -Location (10, 50) -Size (200, 23)
    $OKButton = New-Button -Text "GO" -Location (10, 80) -Size (50, 23)
    $OKButton.Add_Click({
      $TSManageComputerName = $InputBox.Text
      $InputForm.Close()
      switch ($ManageComponent) {
        "scan" { Start-Process powershell -ArgumentList "Powershell $PSScriptRoot\Scan_Host.ps1 -Hostname $TSManageComputerName" -WindowStyle:Hidden}
        "explorer.exe" { Start-Process \\$TSManageComputerName\c$ }
        "lusrmgr.msc" { Start-Process Powershell -ArgumentList "Powershell lusrmgr.msc /computer:$TSManageComputerName" -NoNewWindow }
        "gpedit.msc" { Start-Process Powershell -ArgumentList "Powershell gpedit.msc /gpcomputer: $TSManageComputerName" -NoNewWindow }
        "gpupdate" { Start-Process Powershell -ArgumentList "Powershell Invoke-Command -ScriptBlock { gpupdate /force } -ComputerName $TSManageComputerName" -NoNewWindow }
        "compmgmt.msc" { Start-Process Powershell -ArgumentList "Powershell compmgmt.msc /computer:$TSManageComputerName" -NoNewWindow }
        "restart" { Restart-Computer -ComputerName $TSManageComputerName -Credential $(Get-Credential -Message "Please provide credentials to Restart this Computer." -Username "$env:USERDOMAIN\$env:USERNAME") -Force }
        "shutdown" { Stop-Computer -ComputerName $TSManageComputerName -Credential $(Get-Credential -Message "Please provide credentials to Shut Down this Computer." -Username "$env:USERDOMAIN\$env:USERNAME") -Force }
      }
    })
    $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Enter") { $OKButton.PerformClick() }})
    $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})
    $InputForm.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})
    $InputForm.Controls.AddRange(@($HostnameLabel,$InputBox,$OKButton))
    $InputForm.ShowDialog()
}
  
function Invoke-TSHelpReader ($HelpOption) {
    $HelpForm               = New-Object System.Windows.Forms.Form
    $HelpForm.text          = "Push Help"
    $HelpForm.AutoSize      = $true
    $HelpForm.TopMost       = $true
    $HelpForm.StartPosition = 'CenterScreen'
    $HelpForm.BackColor     = $script:PushConfiguration.ColorScheme.Background
    $HelpForm.Icon          = Convert-Path($Config.Design.Icon)
    $HelpText            = New-Object System.Windows.Forms.TextBox
    $HelpText.Location   = New-Object System.Drawing.Point(0,0)
    $HelpText.Size       = New-Object System.Drawing.Size(700,300)
    $HelpText.Font       = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize)
    $HelpText.ForeColor  = $script:PushConfiguration.ColorScheme.Foreground
    $HelpText.BackColor  = $script:PushConfiguration.ColorScheme.Background
    $HelpText.ReadOnly   = $true
    $HelpText.MultiLine  = $true
    $HelpText.ScrollBars = 'Vertical'
    Get-Content "$($script:PushConfiguration.Location.Documentation)\$HelpOption" | ForEach-Object {
      $HelpText.AppendText("$_`r`n")
    }
    $HelpForm.Controls.Add($HelpText)
    $HelpForm.ShowDialog()
}