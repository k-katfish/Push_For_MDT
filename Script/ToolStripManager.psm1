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

function New-ToolStripItem {
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
    if (-Not (Get-Module GUIManager)) { Import-Module $PSScriptRoot\GUIManager.psm1}

    $InputForm = New-WinForm -Text "$ManageComponent" -Size (250, 125)
    $HostnameLabel = New-Label -Text "Enter Computer name:" -Location (10, 20)
    $InputBox = New-TextBox -Location (10, 50) -Size (200, 23)
    $OKButton = New-Button -Text "GO" -Location (10, 80) -Size (50, 23)
    $OKButton.Add_Click({
      $TSManageComputerName = $InputBox.Text
      $InputForm.Close()
      switch ($ManageComponent) {
        "scan" { Start-Process powershell -ArgumentList "Powershell $PSScriptRoot\Scan_Host.ps1 -Hostname $($InputBox.Text)" -WindowStyle:Hidden}
        "explorer.exe" { Start-Process \\$TSManageComputerName\c$ }
        "lusrmgr.msc" { Start-Process Powershell -ArgumentList "Powershell lusrmgr.msc /computer:$($InputBox.Text)" -NoNewWindow }
        "gpedit.msc" { Start-Process Powershell -ArgumentList "Powershell gpedit.msc /gpcomputer: $($InputBox.Text)" -NoNewWindow }
        "gpupdate" { Start-Process Powershell -ArgumentList "Powershell Invoke-Command -ScriptBlock { gpupdate /force } -ComputerName $($InputBox.Text)" -NoNewWindow }
        "compmgmt.msc" { Start-Process Powershell -ArgumentList "Powershell compmgmt.msc /computer:$($InputBox.Text)" -NoNewWindow }
        "restart" { Restart-Computer -ComputerName $($InputBox.Text) -Credential (Get-StoredPSCredential) <#$(Get-Credential -Message "Please provide credentials to Restart this Computer." -Username "$env:USERDOMAIN\$env:USERNAME")#> -Force }
        "shutdown" { Stop-Computer -ComputerName $($InputBox.Text) -Credential (Get-StoredPSCredential) <#$(Get-Credential -Message "Please provide credentials to Shut Down this Computer." -Username "$env:USERDOMAIN\$env:USERNAME")#> -Force }
      }
    })
    $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Enter") { $OKButton.PerformClick() }})
    $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})
    $InputForm.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})
    $InputForm.Controls.AddRange(@($HostnameLabel,$InputBox,$OKButton))
    $InputForm.ShowDialog()
}
  
function Invoke-TSHelpReader ($HelpOption) {
    if (-Not (Get-Module GUIManager)) { Import-Module $PSScriptRoot\GUIManager.psm1}
    $HelpForm = New-WinForm -Text "Push Help" -AutoSize $true
    $HelpText = New-TextBox -Location (0, 0) -Size (700, 300)
    $HelpText.ReadOnly   = $true
    $HelpText.MultiLine  = $true
    $HelpText.ScrollBars = 'Vertical'
    Get-Content "$PSScriptRoot\..\Documentation\$HelpOption" | ForEach-Object {
      $HelpText.AppendText("$_`r`n")
    }
    $HelpForm.Controls.Add($HelpText)
    $HelpForm.ShowDialog()
}