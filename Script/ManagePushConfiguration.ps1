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
$MDTShareTextBox       = New-TextBox -Location (150, 10) -Size (250, 23)
$MDTShareTextBox.Text = "$(Get-DeploymentShareLocation)"
$ConnectMDTShareButton = New-Button -Text "Test" -Location (400, 10) -Size (50, 25)

$GroupsFolderLabel         = New-Label -Text "Groups Folder:" -Location (10, 40)
$GroupsFolderTextBox       = New-TextBox -Location (150, 40) -Size (250, 23)
$GroupsFolderTextBox.Text = "$(Get-GroupsFolderLocation)"
$ConnectGroupsFolderButton = New-Button -Text "Set" -Location (400, 40) -Size (50, 25)

$ADIntegrateLabel         = New-Label -Text "Integrate with Active Directory" -Location (10, 70)
$ADIntegrateCheckBox      = New-CheckBox -Text "" -Location (200, 70) -Size (25, 25)
$ADIntegrateCheckBox.Checked = Use-ADIntegration
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

$ConfigGUIForm.ShowDialog()