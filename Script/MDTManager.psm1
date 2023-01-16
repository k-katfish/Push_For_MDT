$script:ControlApplicationsXML = ""
$script:ControlTaskSequencesXML = ""
$script:MDTShareLocation = ""

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
            Write-Verbose "Is this a UNC Path?"
            if ($ProspectiveMDTShareLocation -like "*:*") { 
                Write-Verbose "Mapped Drive path provided. Grabbing UNC path from PSDrive information" 
                $ProspectiveMDTShareLocation = (Get-PSDrive $ProspectiveMDTShareLocation.Substring(0,1)).DisplayRoot
                Write-Verbose "Using MDT Share Location $ProspectiveMDTShareLocation"
            }
            
            Write-Verbose "Looking for Applications.xml file in Control folder at $ProspectiveMDTShareLocation"
            if (Test-Path "$($ProspectiveMDTShareLocation)\Control\Applications.xml") {
                Write-Verbose "Found Applications file: $($ProspectiveMDTShareLocation)\Control\Applications.xml"
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
    Set-CachedMDTShareLocation $Path
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

function Get-TaskSequenceIDFromName ($TaskSequenceName) {
    $script:ControlTaskSequencesXML.tss.ts | ForEach-Object {
        if ($_.Name -eq $TaskSequenceName) {
            return $_.ID
        }
    }
}

function Get-ApplicationData {
    <#
    .SYNOPSIS
        Provided the name of an application on MDT, this will return an object with the Name, GUID, CommandLine, and Working Directory of the app
    .DESCRIPTION
        Pass one or more names to this function. It will look at the connected MDT share under Control\Applications.xml and read that file,
        then it will find any applications which match the name(s) you provided. It will gather that data into a PSCustomObject as described in OUTPUTS.
        Note: the returned WorkingDirectory will be modified to include the name of the MDT share. For example, if you have an application
        who's working directory is .\Applications\My-App, the returned PS object will prepend the MDT share: \\[MDTServer]\[MDTShare]\Applications\My-App.
        If the application's working directory is located on a different share (ex. \\MySoftwareServer\MySoftwareShare\Software\My-App) then the returned
        working directory string will not be altered (ex. \\MySoftwareServer\MySoftwareShare\Software\My-App)
    #>
    [cmdletBinding()]
    param(
        [Parameter()]$Name
    )

    $ApplicationData = New-Object System.Collections.ArrayList

    ForEach ($N in $Name) {
        $App = $script:ControlApplicationsXML.applications.application | Where-Object {$_.Name -eq $N}
        $ApplicationData.Add([PSCustomObject]@{
            Name = $App.Name
            guid = $App.guid
            CommandLine = $App.CommandLine
            WorkingDirectory = $App.WorkingDirectory
        })
    }

    $ApplicationData | ForEach-Object {
        if ($_.WorkingDirectory -like ".\*") {
            $_.WorkingDirectory = "$(Get-DeploymentShareLocation)\$($_.WorkingDirectory.Substring(2))"
        }
    }
}


if (-Not (Get-Module ConfigManager)) { Import-Module $PSScriptRoot\ConfigManager.psm1 }
if (Get-CachedMDTShareLocation) {
    Write-Verbose "Loading MDTShare Location of $(Get-CachedMDTShareLocation) from Cache"
    $script:MDTShareLocation = Get-CachedMDTShareLocation
    Set-MDTControlData
}