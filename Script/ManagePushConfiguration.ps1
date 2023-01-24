<#
.SYNOPSIS
    A tool to manage the configuration of your favorite Push tool
.DESCRIPTION
    This script loads the Push configuration and edits/changes/sets preferences/etc in one handy place. Note that you'll need to refresh the Push app
    for some of these changes to be reflected
.NOTES
    Version:  1.0
    Author:   Kyle Ketchell
    Date:     January 17, 2023
#>
[cmdletBinding()]
param()

if (Get-Module ADIntegrationManager) { Remove-Module ADIntegrationManager }
if (Get-Module ConfigManager) { Remove-Module ConfigManager }
if (Get-Module GUIManager) { Remove-Module GUIManager }
if (Get-Module ToolStripManager) { Remove-Module ToolStripManager }
if (Get-Module MDTManager) { Remove-Module MDTManager }

Import-Module $PSScriptRoot\ADIntegrationManager.psm1
Import-Module $PSScriptRoot\ConfigManager.psm1
Import-Module $PSScriptRoot\GUIManager.psm1
Import-Module $PSScriptRoot\ToolStripManager.psm1
Import-Module $PSScriptRoot\MDTManager.psm1

$ConfigGUIForm = New-WinForm -Text "Manage Push Configuration" -Icon "$PSScriptRoot\..\Media\Icon.ico" -Size (500, 300)

$MDTShareLabel         = New-Label -Text "MDT Share:" -Location (10, 10)
$MDTShareTextBox       = New-TextBox -Location (150, 10) -Size (250, 23) -ReadOnly
$MDTShareTextBox.Text = "$(Get-DeploymentShareLocation)"
$ConnectMDTShareButton = New-Button -Text "Change" -Location (400, 10) -Size (100, 25)

$ConnectMDTShareButton.Add_Click({
    Connect-DeploymentShare
    $MDTShareTextBox.Text = "$(Get-DeploymentShareLocation)"
})

$GroupsFolderLabel         = New-Label -Text "Groups Folder:" -Location (10, 40)
$GroupsFolderTextBox       = New-TextBox -Location (150, 40) -Size (250, 23)
$GroupsFolderTextBox.Text = "$(Get-GroupsFolderLocation)"
$ConnectGroupsFolderButton = New-Button -Text "Set" -Location (400, 40) -Size (100, 25)

if (Use-ADIntegration) {
    $GroupsFolderTextBox.Enabled = $false
    $ConnectGroupsFolderButton.Enabled = $false
}

$ADIntegrateLabel         = New-Label -Text "Integrate with Active Directory" -Location (10, 70)
$ADIntegrateCheckBox      = New-CheckBox -Text "" -Location (200, 70) -Size (25, 25)
$ADIntegrateCheckBox.Checked = Use-ADIntegration
$ADIntegrateCheckBox.Add_Click({
    Set-ADIntegrationPreference -UseADIntegration $ADIntegrateCheckBox.Checked -ExcludedOUs ((Get-ADIntegrationPreference).ExcludedOUs)
    $GroupsFolderTextBox.Enabled = (-Not (Use-ADIntegration))
    $ConnectGroupsFolderButton.Enabled = (-Not (Use-ADIntegration))
})
$ADIntegrateExcludeButton = New-Button -Text "Exclude..." -Location (250, 70) -Size (100, 25)
$ADIntegrateExcludeButton.Add_Click({
    $ManageExcludedOUs = New-WinForm -Text "Manage excluded OUs" -Size (300, 300)
    $ListOfOUs = New-ListBox -Location (0, 0) -Size (300, 250)
    $ListOfOUs.SelectionMode = 'MultiSimple'
    Get-ADOUs | ForEach-Object {
        $ListOfOUs.Items.Add($_)
    }

    Get-ExcludedOUs | ForEach-Object {
        $ListOfOUs.Items.Add($_)
        $ListOfOUs.SelectedItems.Add($_)
    }

    $OKButton = New-Button -Text "Exclude Selected OUs" -Size (200, 25) -Location (10, 260)
    $OKButton.Add_Click({
        Write-Verbose "ManagePushConfiguration: ManageExcludedOUs. OK Button Clicked."
        Set-ExcludedOUs $ListOfOUs.SelectedItems
        <#$ExcludedOUs = Get-ExcludedOUs
        $ListOfOUs.SelectedItems | ForEach-Object {
            Write-Verbose "ManagePushConfiguration: ManageExcludedOUs. Testing if $_ is already excluded"
            if ($ExcludedOUs -contains $_) { continue }
            else { Add-ExcludedOU $_ }
        }
        $ExcludedOUs = Get-ExcludedOUs
        if ($ExcludedOUs.Count -gt $ListOfOUs.Count) {
            Write-Verbose "ManagePushConfiguration: ManageExcludedOUs. There are more ExcludedOUs than selected in the list."
            $ExcludedOUs | ForEach-Object {
                if ($ListOfOUs.SelectedItems -contains $_) { continue }
                else { Remove-ExcludedOU $_ }
                $ExcludedOUs = Get-ExcludedOUs
            }
        }#>
        $ManageExcludedOUs.Close()
    })

    $ManageExcludedOUs.Controls.AddRange(@($ListOfOUs, $OKButton))
    $ManageExcludedOUs.ShowDialog()
})

$ConfigGUIForm.Controls.AddRange(@(
    $MDTShareLabel, $MDTShareTextBox, $ConnectMDTShareButton,
    $GroupsFolderLabel, $GroupsFolderTextBox, $ConnectGroupsFolderButton,
    $ADIntegrateLabel, $ADIntegrateCheckBox, $ADintegrateExcludeButton
))

#==========================================================================

$ColorSchemeLabel = New-Label -Text "Color Scheme:" -Location (10, 100)
$ColorSchemeDropDown = New-ComboBox -Text (Get-SelectedColorScheme) -Location (150, 100) -Size (200, 25)
$ColorSchemeDropDown.Items.AddRange((Get-AvailableColorSchemes))
$ColorSchemeDropDown.Add_SelectedIndexChanged({
  Set-ColorScheme $ColorSchemeDropDown.SelectedItem
  Invoke-RefreshColors ($ConfigGUIForm)
})
$EditColorScheme = New-Button -Text "Edit" -Location (375, 100) -Size (50, 25)
$EditColorScheme.Add_Click({
    $CSEditForm = New-WinForm -Text "Edit: $(Get-SelectedColorScheme)" -Size (300, 300)
    $BLabel = New-Label -Text "Background:" -Location (5, 10)
    $FLabel = New-Label -Text "Foreground:" -Location (5, 35, 10)
    $TSBLabel = New-Label -Text "Tool Strip Background:" -Location (5, 60, 10)
    $TSFLabel = New-Label -Text "Tool Strip Foreground:" -Location (5, 85, 10)
    $SLabel = New-Label -Text "Success:" -Location (5, 110, 10)
    $WLabel = New-Label -Text "Warning:" -Location (5, 135, 10)
    $ELabel = New-Label -Text "Error:" -Location (5, 160, 10)
    $BTextBox = New-TextBox -Location (150, 10, 200) -Size (150, 25); $BTextBox.Text = Get-BackgroundColor
    $FTextBox = New-TextBox -Location (150, 35, 200) -Size (150, 25); $FTextBox.Text = Get-ForegroundColor
    $TSBTextBox = New-TextBox -Location (150, 60, 200) -Size (150, 25); $TSBTextBox.Text = Get-ToolStripBackgroundColor
    $TSFTextBox = New-TextBox -Location (150, 85, 200) -Size (150, 25); $TSFTextBox.Text = Get-ToolStripHoverColor
    $STextBox = New-TextBox -Location (150, 110, 200) -Size (150, 25); $STextBox.Text = Get-SuccessColor
    $WTextBox = New-TextBox -Location (150, 135, 200) -Size (150, 25); $WTextBox.Text = Get-WarningColor
    $ETextBox = New-TextBox -Location (150, 160, 200) -Size (150, 25); $ETextBox.Text = Get-ErrorColor
    $SetCSButton = New-Button -Text "Set Color Scheme" -Location (100, 200, 150) -Size (200, 25)
    $SetCSButton.Add_Click({
        Set-ColorSchemeSettings -B $BTextBox.Text -F $FTextBox.Text -TSB $TSBTextBox.Text -TSF $TSFTextBox.Text -S $STextBox.Text -W $WTextBox.Text -E $ETextBox.Text
        $CSEditForm.Close()
    })
    $CSEditForm.Controls.AddRange(@(
        $BLabel, $FLabel,$TSBLabel,$TSFLabel,$SLabel,$WLabel,$ELabel,
        $BTextBox,$FTextBox,$TSBTextBox,$TSFTextBox,$STextBox,$WTextBox,$ETextBox,
        $SetCSButton
    ))
    $CSEditForm.ShowDialog()
}) 

$DesignSchemeLabel = New-Label -Text "Design Scheme:" -Location (10, 125)
$DesignSchemeDropDown = New-ComboBox -Text (Get-SelectedDesignScheme) -Location (150, 125) -Size (200, 25)
$DesignSchemeDropDown.Items.AddRange((Get-AvailableDesignSchemes))
$DesignSchemeDropDown.Add_SelectedIndexChanged({
  Set-DesignScheme $DesignSchemeDropDown.SelectedItem
  Invoke-RefreshColors ($ConfigGUIForm)
})
$EditDesignScheme = New-Button -Text "Edit" -Location (375, 125) -Size (50, 25)
$EditDesignScheme.Add_Click({
    $DSEditForm = New-WinForm -Text "Edit: $(Get-SelectedDesignScheme)" -Size (300, 300)
    $FSLabel = New-Label -Text "Flat Style:" -Location (5, 10)
    $BSLabel = New-Label -Text "Border Style:" -Location (5, 35, 10)
    $FNLabel = New-Label -Text "Font Name:" -Location (5, 60, 10)
    $FSiLabel = New-Label -Text "Font Size:" -Location (5, 85, 10)
    #$SLabel = New-Label -Text "Success:" -Location (5, 110, 10)
    #$WLabel = New-Label -Text "Warning:" -Location (5, 135, 10)
    #$ELabel = New-Label -Text "Error:" -Location (5, 160, 10)
    $FSTextBox = New-TextBox -Location (150, 10, 200) -Size (150, 25); $FSTextBox.Text = Get-FlatStyle
    $BSTextBox = New-TextBox -Location (150, 35, 200) -Size (150, 25); $BSTextBox.Text = Get-BorderStyle
    $FNTextBox = New-TextBox -Location (150, 60, 200) -Size (150, 25); $FNTextBox.Text = Get-FontName
    $FSiTextBox = New-TextBox -Location (150, 85, 200) -Size (150, 25); $FSiTextBox.Text = Get-FontSize
    #$STextBox = New-TextBox -Location (150, 110, 200) -Size (150, 25); $STextBox.Text = Get-SuccessColor
    #$WTextBox = New-TextBox -Location (150, 135, 200) -Size (150, 25); $WTextBox.Text = Get-WarningColor
    #$ETextBox = New-TextBox -Location (150, 160, 200) -Size (150, 25); $ETextBox.Text = Get-ErrorColor
    $SetDSButton = New-Button -Text "Set Design Scheme" -Location (100, 200, 150) -Size (200, 25)
    $SetDSButton.Add_Click({
        Set-DesignSchemeSettings -FS $FSTextBox.Text -BS $BSTextBox.Text -FName $FNTextBox.Text -FSize $FSiTextBox.Text
        $DSEditForm.Close()
    })
    $DSEditForm.Controls.AddRange(@(
        $FSLabel, $BSLabel, $FNLabel, $FSiLabel,
        $FSTextBox, $BSTextBox, $FNTextBox, $FSiTextBox,
        $SetDSButton
    ))
    $DSEditForm.ShowDialog()
}) 

$ConfigGUIForm.Controls.AddRange(@(
    $ColorSchemeLabel, $ColorSchemeDropDown, $EditColorScheme,
    $DesignSchemeLabel, $DesignSchemeDropDown, $EditDesignScheme
))

$ConfigGUIForm.ShowDialog()