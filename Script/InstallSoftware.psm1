if (-Not (Get-Module ConfigManager)) { Import-Module $PSScriptRoot\ConfigManager.psm1 }
if (-Not (Get-Module MDTManager)) { Import-Module $PSScriptRoot\MDTManager.psm1 }

function Get-OnlineMachines {
    param(
        [Parameter()]$ComputerName,
        [Parameter()]$Protocol
    )

    $Online = Test-Connection $ComputerName -Quiet -Count 1
    Write-Verbose "ArrayList-ifying the computers: $ComputerName. There are $($ComputerName.Count) computers."
    if ($ComputerName.Count -eq 1) {
        Write-Verbose "Turning a string into an arraylist of one string item."
        $ComputerName = [System.Collections.ArrayList](@($ComputerName)) 
    } else {
        Write-Verbose "ArrayList-ifying $ComputerName, which is of type $($ComputerName.GetType().Name)"
        $ComputerName = [System.Collections.ArrayList]($ComputerName)
    }
    Write-Verbose "$ComputerName is now a $($ComputerName.GetType().Name)"
    (0..($Online.Length - 1)) | ForEach-Object {
        if (-Not ($Online[$_])) {
            Write-Verbose "Computer $($ComputerName[$_]) is offline."
            $OutputBox.AppendText("Offline: $($ComputerName[$_]).")
            $ComputerName.RemoveAt($_)
        }
    }

    return $ComputerName
}

function Invoke-RunTaskSequence {
    <#
    .SYNOPSIS
        Connects to a remote computer using best available protocol (determined automatically in this function) and launches an MDT Task Sequence.
    .DESCRIPTION
        Provide a name, list of names, or existing CimSession, as well as a Task Sequence name to this function.
        It will connect to those computers (through DCOM, WMI methods, or CimSessions) and execute a short set of commands.
        It will connect to the MDT share stored in %APPDATA%\Push\config.xml (the configuration existing in the current powershell session running push)
        and then run cscript.exe '\\MDTServer\MDTShare\Scripts\LiteTouch.wsf' /OSDComputerName:$env:COMPUTERNAME /TaskSequenceID:[TS ID pulled from the 
        provided Name] /SKIPComputerName:YES /SKIPTaskSequence:YES. If you have a poorly designed task sequence, you'll likely run into issues.

        Your MDT share also needs to be configured correctly, with rules to skip all startup pages and MDT credentials already saved on your server.
        Also, you need to have well-configured task sequences for your machines which will actually work for an Operating System Refresh.
    .INPUTS
        String: Computer Name OR CimSession: existing Cim Session
        String: Task Sequence Name
        Credentials: a PSCredential Object for a domain user who has Admin on the remote machine and access to the MDT share.
    .OUTPUTS
        Nothing.
    .NOTES
        Version:          1.0.0
        Authors:          Kyle Ketchell
        Version Creation: January 15, 2023
        Orginal Creation: January 15, 2023
    .PARAMETER ComputerList
        A list of computer names you intend to run the task sequence on. Either -ComputerList or -ComputerName must be specified.
    .PARAMETER ComputerName
        A single computer to connect to and run the task sequence on. Either -ComputerList or -ComputerName must be specified.
    .Parameter TaskSequenceName
        [Required] The visible name of a task sequence to run. [Optionally, you could pass the Task Sequence ID instead with the -TaskSequenceID parameter].
    .PARAMETER Credential
        [Required] A PSCredential object for a domain user who has Admin on the remote machine and access to the MDT share.
    .EXAMPLE
        Invoke-RunTaskSequence -ComputerName My_Computer -TaskSequence "Windows 10 Upgrade" -Credential (Get-Credential)
    #>
    [cmdletBinding()]
    param(
      [Parameter(ParameterSetName="Default")][Alias("h")][Switch]$help,
      #[Parameter(ParameterSetName="ComputerList")][System.Collections.ArrayList]$ComputerList,
      [Parameter(ParameterSetName="ComputersByName")][String]$ComputerName,
      [Parameter(ParameterSetName="CimSession")][CimSession]$CimSession,
      [Parameter()][String]$TaskSequenceID,
      [Parameter()][Alias("TaskSequence")][String]$TaskSequenceName,
      [Parameter()][PSCredential]$Credential
    )

    if ($help) { Write-Host "$(Get-Help Invoke-RunTaskSequence)"; return "help" }

    if ($TaskSequenceName) { $TaskSequenceID = Get-TaskSequenceIDFromName $TaskSequenceName }

    if ($ComputerName) {
        $ComputerName = Get-OnlineMachines $ComputerName
    }

    #if ($ComputerName.Count -gt 1) {
    #    <# Run TS on multiple computers #>
    #} else {
    #    Test-WSMan -ComputerName $ComputerName
    #}

    if (-Not ($CimSession)) {
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol DCOM)
    } else {
        $ComputerName = $CimSession.ComputerName
    }
    
    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline = "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
    }

    <#Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="powershell.exe /c Enable-WSManCredSSP -Role Server -Force"
    }

    $ComputerName | ForEach-Object {
        Start-Process powershell.exe -ArgumentList "EnableWSManCredSSP", "Client","$_", "-Force" -Wait
    }#>

    #$CimSession = New-CimSession -ComputerName $ComputerName -Authentication CredSsp -Credential $Credential

    <#Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="NET USE X: $MDTShare"
    }

    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="cscript.exe '\\labs-mdt\LABS-MDT$\Scripts\LiteTouch.wsf' /OSDComputerName:%COMPUTERNAME% /TaskSequenceID:$TaskSequenceID /SkipComputerName:YES /SkipTaskSequence:YES"
    }#>

    #New-PSSession -ComputerName -ComputerName 

    #$ComputerName | ForEach-Object {
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Wait
    #}

    #Invoke-Command -ComputerName $ComputerName -ScriptBlock {          
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force"
    #}  -Authentication Kerberos

    $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential #-Authentication Credssp

    try{
        Invoke-Command -Session $Session -ScriptBlock {
            Set-ExecutionPolicy Bypass -Scope Process -Force
        }
    } catch {
        Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
            commandline = "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
        }
        Start-Sleep -Seconds 2
        try {
            Invoke-Command -Session $Session -ScriptBlock {
                Set-ExecutionPolicy Bypass -Scope Process -Force
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Could not connect to the session. WinRM is not yet enabled. Most likely due to slow startup-should work after waiting for a few minutes. Error: $_", "Unable to connect.")
        }
    }#>

    $MDTShare = Get-DeploymentShareLocation
    Invoke-Command -Session $Session -ScriptBlock {
        New-PSDrive -Name M -Root $using:MDTShare -PSProvider "Filesystem" -Credential $using:Credential
        $env:SEE_MASK_NOZONECHECKS = 1
        cscript.exe "$using:MDTShare\Scripts\LiteTouch.wsf" /OSDComputerName:$env:COMPUTERNAME /TaskSequenceID:$using:TaskSequenceID /SKIPTaskSequence:YES /SKIPComputerName:YES
    }

    #Write-Verbose "Planning to execute Task Sequence $TaskSequenceID on $ComputerName."
    Remove-PSSession -Session $Session

    #Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
    #    #commandline = "powershell.exe /c New-PSDrive -Name M -Root $MDTShare -PSProvider 'Filesystem' -Credential $"
    #    commandline = "NET USE X: $MDTShare"
    #}

    #Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
    #    commandline = "cscript.exe '$MDTShare\Scripts\LiteTouch.wsf' /OSDComputerName:%COMPUTERNAME% /TaskSequenceID:$TaskSequenceID /SkipComputerName:YES /SkipTaskSequence:YES"
    #}

    try {
        $DoneLabel.Text = "Launched $TaskSequenceID on $ComputerName" #rebooted to continue $TaskSequenceID" 
        $DoneLabel.Forecolor = Get-SuccessColor
        $DoneLabel.Visible = $true 
    } catch { Write-Host "Finished Installing $TaskSequenceName" }
    
    try {
        $DoneLabel.Visible = $true
    } catch {}

    return 0
}

function Invoke-InstallSoftware {
    <#
    .SYNOPSIS
        Connects to a remote computer using best available protocol (determined automatically in this function) and installs an application from MDT.
    .DESCRIPTION
        Provide a name, list of names, or existing CimSession, as well as an Application name to this function.
        It will connect to those computers (through DCOM, WMI methods, or CimSessions) and execute the install string for that application, pulled from MDT.
        It will connect to the MDT share stored in %APPDATA%\Push\config.xml (the configuration existing in the current powershell session running push)
        and then run the install string for the app.
    .INPUTS
        String: Computer Name OR CimSession: existing Cim Session
        String: Application name
        Credentials: a PSCredential Object for a domain user who has Admin on the remote machine and access to the MDT share (or the saved working directory of the app).
    .OUTPUTS
        Nothing.
    .NOTES
        Version:          1.0.0
        Authors:          Kyle Ketchell
        Version Creation: January 15, 2023
        Orginal Creation: January 15, 2023
    .PARAMETER ComputerName
        One or more computers to connect to and install the application on.
    .Parameter Application
        One or more names of applications from MDT to install.
    .PARAMETER Credential
        [Required] A PSCredential object for a domain user who has Admin on the remote machine and access to the MDT share.
    .EXAMPLE
        Invoke-RunTaskSequence -ComputerName My_Computer -TaskSequence "Windows 10 Upgrade" -Credential (Get-Credential)
    #>
    [cmdletBinding()]
    param(
      [Parameter(ParameterSetName="Default")][Alias("h")][Switch]$help,
      [Parameter(ParameterSetName="ComputersByName")][String]$ComputerName,
      [Parameter(ParameterSetName="CimSession")][CimSession]$CimSession,
      [Parameter()][Alias("App")][String]$ApplicationName,
      [Parameter()][PSCredential]$Credential
    )

    if ($help) { Write-Host "$(Get-Help Invoke-InstallSoftware)"; return "help" }

    $ApplicationData = New-Object System.Collections.ArrayList

    $ApplicationName | ForEach-Object {
        Write-Verbose "Getting data for $_"
        $ApplicationData.Add((Get-ApplicationData -Name $_))
    }

    $ApplicationData | ForEach-Object {
        Write-Verbose "Appd: $($_.Name) | $($_.GUID) | $($_.CommandLine) | $($_.WorkingDirectory)"
    }

    #if ($ApplicationName) { $TaskSequenceID = Get-TaskSequenceIDFromName $TaskSequenceName }

    if ($ComputerName) {
        $ComputerName = Get-OnlineMachines $ComputerName
    }

    #if ($ComputerName.Count -gt 1) {
    #    <# Run TS on multiple computers #>
    #} else {
    #    Test-WSMan -ComputerName $ComputerName
    #}

    if (-Not ($CimSession)) {
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol DCOM) -Credential $Credential
    } else {
        $ComputerName = $CimSession.ComputerName
    }
    
    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline = "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
    }

    <#Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="powershell.exe /c Enable-WSManCredSSP -Role Server -Force"
    }

    $ComputerName | ForEach-Object {
        Start-Process powershell.exe -ArgumentList "EnableWSManCredSSP", "Client","$_", "-Force" -Wait
    }#>

    #$CimSession = New-CimSession -ComputerName $ComputerName -Authentication CredSsp -Credential $Credential

    <#Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="NET USE X: $MDTShare"
    }

    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="cscript.exe '\\labs-mdt\LABS-MDT$\Scripts\LiteTouch.wsf' /OSDComputerName:%COMPUTERNAME% /TaskSequenceID:$TaskSequenceID /SkipComputerName:YES /SkipTaskSequence:YES"
    }#>

    #New-PSSession -ComputerName -ComputerName 

    #$ComputerName | ForEach-Object {
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Wait
    #}

    #Invoke-Command -ComputerName $ComputerName -ScriptBlock {          
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force"
    #}  -Authentication Kerberos
    Write-Verbose "Creating a new powershell session with $ComputerName as $($Credential.Username)"
    $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential #-Authentication Credssp

    try{
        Invoke-Command -Session $Session -ScriptBlock {
            Set-ExecutionPolicy Bypass -Scope Process -Force
        }
    } catch {
        Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
            commandline = "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
        }
        Start-Sleep -Seconds 2
        try {
            Invoke-Command -Session $Session -ScriptBlock {
                Set-ExecutionPolicy Bypass -Scope Process -Force
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Could not connect to the session. WinRM is not yet enabled. Most likely due to slow startup-should work after waiting for a few minutes. Error: $_", "Unable to connect.")
        }
    }#>

    $ApplicationData | ForEach-Object {
        Write-Verbose "Attempting to install $($_.Name) on $($Session.ComputerName) using cmd: $($_.CommandLine) and dir: $($_.WorkingDirectory) as: $($Credential.UserName)"
        $App = $_
        Write-Verbose "Appd: $($App.Name) $($App.WorkingDirectory) $($App.CommandLine)"
        Invoke-Command -Session $Session -ScriptBlock {
            #if (Get-PSDrive -Name M) { Remove-PSDrive -Name M }
            Write-Host "$env:COMPUTERNAME"
            Write-Verbose "$env:COMPUTERNAME"
            Write-Host "Appd: $($using:_.Name)"
            Write-Host "Appd: $($_.Name)"
            Write-Host "Appd: $($App.Name)"
            Write-Host "Appd: $($using:App.Name)"
            Write-Verbose "$env:COMPUTERNAME Appd: $($using:_.Name)"
            New-PSDrive -Name M -Root $using:_.WorkingDirectory -PSProvider "Filesystem" -Credential $using:Credential
            $env:SEE_MASK_NOZONECHECKS = 1
            Set-Location "M:\"
            & "$($using:App.CommandLine)"
        }
        Write-Verbose "Finished Invoking command."
    }

<#    $MDTShare = Get-DeploymentShareLocation
    Invoke-Command -Session $Session -ScriptBlock {
        New-PSDrive -Name M -Root $using:MDTShare -PSProvider "Filesystem" -Credential $using:Credential
        $env:SEE_MASK_NOZONECHECKS = 1
        cscript.exe "$using:MDTShare\Scripts\LiteTouch.wsf" /OSDComputerName:$env:COMPUTERNAME /TaskSequenceID:$using:TaskSequenceID /SKIPTaskSequence:YES /SKIPComputerName:YES
    }
#>
    #Write-Verbose "Planning to execute Task Sequence $TaskSequenceID on $ComputerName."
    Remove-PSSession -Session $Session

    try {
        $DoneLabel.Text = "Launched $TaskSequenceID on $ComputerName" #rebooted to continue $TaskSequenceID" 
        $DoneLabel.Forecolor = Get-SuccessColor
        $DoneLabel.Visible = $true 
    } catch { Write-Host "Finished Installing $TaskSequenceName" }
    
    try {
        $DoneLabel.Visible = $true
    } catch {}

    return 0
}