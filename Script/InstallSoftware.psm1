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

    if (-Not ($CimSession)) {
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol DCOM)
    } else {
        $ComputerName = $CimSession.ComputerName
    }

    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="powershell.exe /c Enable-WSManCredSSP -Role Server -Force"
    }

    $ComputerName | ForEach-Object {
        Enable-WSManCredSSP -Role Client -DelegateComputer $_ -Force
    }

    $CimSession = New-CimSession -ComputerName $ComputerName -Authentication CredSsp -Credential $Credential

    $Command = "pushd $(Get-DeploymentShareLocation)&&cscript.exe Scripts\LiteTouch.wsf /OSDComputerName:%COMPUTERNAME% /TaskSequenceID:$TaskSequenceID /SKIPTaskSequence:YES /SKIPComputerName:YES"
    Write-Verbose "Planning to run TS: $TaskSequenceID on $($CimSession.ComputerName) with command '$Command'"

    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName Create -Arguments @{
        commandline="cmd /e:on /c $Command"
    }
    Write-Verbose "Started LiteTouch on $($CimSession.ComputerName) to run TS $TaskSequenceID"

    # Clean up
    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName Create -Arguments @{
        commandline="powershell.exe /c Disable-WSManCredSSP -Role Server"
    }
    Disable-WSManCredSSP -Role Client
    Remove-CimSession $CimSession
    Write-Verbose "Reset WSManCredSSP on this machine and remote session, and removed the session."

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
      [Parameter()][Alias("App")]$ApplicationName,
      [Parameter()][PSCredential]$Credential
    )

    if ($help) { Write-Host "$(Get-Help Invoke-InstallSoftware)"; return "help" }

    $ApplicationData = New-Object System.Collections.ArrayList

    $ApplicationName | ForEach-Object {
        Write-Verbose "Getting data for $_"
        $AppData = Get-ApplicationData -Name $_
        if ($AppData.Count -gt 1) {
            Write-Verbose "App has dependencies"
            $ApplicationData.AddRange($AppData) 
        }
        else { $ApplicationData.Add($AppData) }
    }

    $ApplicationData | ForEach-Object { Write-Verbose "Appd: $($_.Name) | $($_.GUID) | $($_.CommandLine) | $($_.WorkingDirectory)" }

    if ($ComputerName) { $ComputerName = Get-OnlineMachines $ComputerName }
    if (-Not ($CimSession)) {
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol DCOM) -Credential $Credential
    } else { $ComputerName = $CimSession.ComputerName }

    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="powershell.exe /c Enable-WSManCredSSP -Role Server -Force"
    }

    $ComputerName | ForEach-Object { Enable-WSManCredSSP -Role Client -DelegateComputer $_ -Force }

    $CimSession = New-CimSession -ComputerName $ComputerName -Authentication CredSsp -Credential $Credential

    $ApplicationData | ForEach-Object {
        Write-Verbose "Attempting to install $($_.Name) on $($Session.ComputerName) using cmd: $($_.CommandLine) and dir: $($_.WorkingDirectory) as: $($Credential.UserName)"
        $Command = "pushd $($_.WorkingDirectory)&&$($_.CommandLine)"
        Write-Verbose "Command: $Command"

        $ProcessData = Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
            commandline="cmd /e:on /c $Command"
        }

        While (Get-CimInstance -CimSession $CimSession -ClassName CIM_Process | Where-Object {$_.ProcessID -eq $ProcessData.ProcessId}) {
            Write-Verbose "Waiting 1s for host $($CimSession.ComputerName) to finish process $($ProcessData.ProcessID)"
            Start-Sleep -Seconds 1
        }

        Write-Verbose "Finished Invoking command."
    }

    # Clean up
    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline="powershell.exe /c Disable-WSManCredSSP -Role Server -Force"
    }
    Disable-WSManCredSSP -Role Client
    Remove-CimSession $CimSession
    Write-Verbose "Disabled WSManCredSSP on local machine and remote session. Removed session."

    try {
        $DoneLabel.Text = "Launched $ApplicationID on $ComputerName" #rebooted to continue $TaskSequenceID" 
        $DoneLabel.Forecolor = Get-SuccessColor
        $DoneLabel.Visible = $true 
    } catch { Write-Host "Finished Installing $ApplicationName" }
    
    try {
        $DoneLabel.Visible = $true
    } catch {}

    return 0
}