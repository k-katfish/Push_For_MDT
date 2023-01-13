$script:ControlApplicationsXML = ""
$script:ControlTaskSequencesXML = ""

function Connect-DeploymentShare {
    if (-Not (Get-Module GUIManager)) { Import-Module $PSScriptRoot\GUIManager.psm1 }
    
    $ConnectShareDialog = New-WinForm -Text "Connect to MDT Deployment Share" -Size (430, 120) -Icon "$PSScriptRoot\..\Media\Icon.ico" -StartPosition "CenterScreen"
    
    $PathLabel = New-Label -Text "Deployment Share Path:" -Location (10, 30)
    $PathTextBox = New-TextBox -Location (10, 50) -Size (300, 25)   

    $BrowseButton = New-Button -Text "Browse" -Location (320, 50) -Size (100, 25)
    $BrowseButton.Add_Click({
        $SelectedPath = Get-FolderPathLameUI
        if ($SelectedPath) { $PathTextBox.Text = $SelectedPath }
    })
    
    $ConnectButton = New-Button -Text "Connect" -Location (10, 75) -Size (100, 25)
    $ConnectButton.Add_Click({
        try {
            $ProspectiveMDTShareLocation = $PathTextBox.Text
            if ($ProspectiveMDTShareLocation -like "\:") { $ProspectiveMDTShareLocation = (Get-PSDrive $ProspectiveMDTShareLocation.Substring(0,1)).Root }
            
            if (Test-Path "$($ProspectiveMDTShareLocation)\Control\Applications.xml") {
                Set-DeploymentShareLocation $ProspectiveMDTShareLocation
                Set-MDTControlData
                #New-ToastNotification -Title "Success" -Content "Successfully connected to the deployment share at $ProspectiveMDTShareLocation. You can change this at any time by going to File -> Connect to Deployment Share." -TitleIcon 'Information'
                $ConnectShareDialog.Close()
            } else {
                New-MessageBox -Text "Unable to connect. Please verify that this is a valid MDT share." -Caption "Error" -Icon 'Error'
            }
        } catch {
            New-MessageBox -Text "Unable to connect to deployment share: $($PathTextBox.Text). Please verify that this share exists or is a valid MDT deployment share"
            #New-ToastNotification -Title "Error" -Content "Unable to connect to deployment share at $($PathTextBox.Text). Please verify that this share exists and is a vaild MDT share."
        }
    })

    $PathTextBox.Add_KeyDown({
        If ($PSItem.KeyCode -eq "Enter"){
            $ConnectButton.PerformClick()
        }
    })

    $ConnectShareDialog.Controls.AddRange(@($PathLabel, $PathTextBox, $BrowseButton, $ConnectButton))

    $ConnectShareDialog.ShowDialog()
}

function Set-DeploymentShareLocation ($Path) {
    $script:MDTShareLocation = $Path #I'm an idiot. I wrote $script:MDTShareLocation and then forgot to add the = $Path, and spent like 2 days trying to figure out why the rest of everything else wasn't working :facepalm:
}

function Get-DeploymentShareLocation {
    return $script:MDTShareLocation
}

function Set-MDTControlData {
    $script:ControlApplicationsXML = [xml](Get-Content "$script:MDTShareLocation\Control\Applications.xml")
    $script:VisibleApplications    = New-Object System.Collections.ArrayList
    $script:HiddenApplications     = New-Object System.Collections.ArrayList
    $script:ControlApplicationsXML.applications.application | ForEach-Object {
        if ($_.hide -eq "True") {
            $script:HiddenApplications.Add($_.Name)
        } else {
            $script:VisibleApplications.Add($_.Name)
        }
    }
#    $script:VisibleApplications = $script:ControlApplicationsXML.applications.application | Where-Object {-Not ($_.hide -eq "True")}
#    $script:HiddenApplications = $script:ControlApplicationsXML.applications.application | Where-Object {$_.hide -eq "True"}

    $script:ControlTaskSequencesXML = [xml](Get-Content "$script:MDTShareLocation\Control\TaskSequences.xml")
    $script:VisibleTaskSequences    = New-Object System.Collections.ArrayList
    $script:HiddenTaskSequences     = New-Object System.Collections.ArrayList
    $script:ControlTaskSequencesXML.tss.ts | ForEach-Object {
        if ($_.hide -eq "True") {
            $script:HiddenTaskSequences.Add($_.Name)
        } else {
            $script:VisibleTaskSequences.Add($_.Name)
        }
    }
    #$script:VisibleTaskSequences = $script:ControlTaskSequencesXML.tss.ts | Where-Object {-Not ($_.hide -eq "True")}
    #$script:HiddenTaskSequences = $script:ControlTaskSequencesXML.tss.ts | Where-Object {$_.hide -eq "True"}
}

function Get-AvailableTaskSequences {
    #return ""
    #if ($script:MDTShareLocation) {
    #    $TSxml = [XML](Get-Content "$script:MDTShareLocation\Control\")
    #}
    if ($script:MDTShareLocation) { 
        #$TaskSequences = Get-ChildItem "$script:MDTShareLocation\Control" | Where-Object {$_.Mode -eq "d-----"}
        #$TSxml = $script:ControlTaskSequencesXML
        #$TSxml.tss.ts | ForEach-Object {
#
        #}
        $TaskSequences = $script:ControlTaskSequencesXML.tss.ts
        return $TaskSequences
    }
}

#function Get-AvailableApplications {
#    if ($script:MDTShareLocation) {
#        #$Appsxml = $script:ControlApplicationsXML
#        return $script:ControlApplicationsXML.applications.application
#        #$Appsxml.applications.application | ForEach-Object {
#        #}
#    } else {
#        Write-Verbose "MDT share not connected."
#        return $null 
#    }
#}

function Get-MDTAppsList ($IncludeHidden) {
    $AppsList = New-Object System.Collections.ArrayList
#    $Apps = Get-AvailableApplications
    if ($script:MDTShareLocation) {
        #$Apps | ForEach-Object {
        #    if (-Not ($_.hide)) {
        #        $AppsList.Add($_.Name) *> $null
        #    } elseif ($IncludeHidden) {
        #        $AppsList.Add($_.Name) *> $null
        #    }
        #}
        $AppsList.AddRange($script:VisibleApplications)
        if ($IncludeHidden) {$AppsList.AddRange($script:HiddenApplications)}
    }
    $AppsList.Sort()
    return $AppsList
}

function Get-MDTTSList ($IncludeHidden) {
    $TSList = New-Object System.Collections.ArrayList
    #$TS = Get-AvailableTaskSequences
    #if ($TS) {
    #    $TS | ForEach-Object {
    #        if (-Not ($_.hide -eq "True")) {
    #            $TSList.Add($_.Name) *> $null
    #        } elseif ($IncludeHidden) {
    #            $TSList.Add($_.Name) *> $null
    #        }
    #    }
    #}
    if ($script:MDTShareLocation) {
        $TSList.AddRange($script:VisibleTaskSequences)
        if ($IncludeHidden) {$TSList.AddRange($script:HiddenTaskSequences)}
    }
    $TSList.Sort()
    return $TSList
}