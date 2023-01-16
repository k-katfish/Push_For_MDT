if (-Not (Get-Module ConfigManager)) { Import-Module $PSScriptRoot\ConfigManager.psm1 }
if (-Not (Get-Module MDTManager)) { Import-Module $PSScriptRoot\MDTManager.psm1 }

function Get-OnlineComputers ($ComputerName) {
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

function New-RemoteSession {
    <#
    .SYNOPSIS
        Creates a remote session using best (or specified) available protocol and returns that session.
    .DESCRIPTION
        Provide a name or list of names to this function.
        It will connect to those computers (first through DCOM, then WMI methods (WinRM), or CimSessions, then PowershellSessions) and execute anything necessary
        to elevate that session to make the next type of session available until it is able to return the desired session to you.

        For example, if you want a PSSession using CredSSP Authentication, this will connect with DCOM and ensure that WMI is enabled, then connect
        with WMI to ensure that PSRemoting is enabled, then set up this and the remote machine for using CredSSP authentication, then it will return
        a PSSession object which was created with the provided credentials and CredSSP authentication.

        Another example: if you only need a WMI session, the computer will connect with DCOM and ensure that WinRM is enabled, then it will create and
        return a WMI session.
    .INPUTS
        String: ComputerName OR (listof) Strings: ComputerName
        String: Protocol | One of: 'DCOM' [default], 'WMI', 'CIM', 'PSSession'
        String: Authentication | One of: Negotiate [default], Kerberos, CredSSP, 
        Credentials: a PSCredential Object for a domain user who has Admin on the remote machine and access to the MDT share.
    .OUTPUTS
        A remote session as you described in INPUTS
    .NOTES
        Version:          1.0
        Authors:          Kyle Ketchell
        Version Creation: January 16, 2023
        Orginal Creation: January 16, 2023
    .PARAMETER ComputerName
        One or more computers to connect to
    .Parameter Protocol
        [Required] The protocol used to connect to the computer. The type returned will be as follows:
            DCOM: will return a CimSession using DCOM protocol
            WMI: ??? (plz don't ask for a WMI session cause IDK what this is)
            CIM: a CimSession using WSMAN protocol
            PSSession: a Powershell Session with the remote computer running over WinRM
    .PARAMETER Authentication
        [Optional] The type of authentication used for the remote session. Please do not specify Basic authentication.
    .PARAMETER Credential
        [Maybe Required] A PSCredential object for a user who has remote access to the remote machine.
        Only required for some types of sessions.
    .EXAMPLE
        New-RemoteSession -ComputerName My_Computer -Protocol PSSession -Authentication CredSSP -Credential $MyPSCredentialObject
    #>
    [cmdletBinding()]
    param(
        [Parameter()]$ComputerName,
#        [Parameter()]$SessionType,
        [Parameter()]$Protocol = 'DCOM',
        [Parameter()]$Authentication = 'Negotiate',
        [Parameter()][pscredential]$Credential
    )

    $ComputerName = Get-OnlineComputers $ComputerName

    switch ($Protocol) {
        "DCOM" {
            return (New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol DCOM))
        }

        "CIM" {
            return (New-CimSession -ComputerName $ComputerName -Authentication $Authentication)
        }

        "PSSession" {
            $CimSession = New-CimSession -ComputerName $ComputerName
            <#$PSRemotingEnabling =#> Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{ commandline = "Powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force" }
            $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential -Authentication Kerberos
            if ($Authentication -eq "CredSSP") {
                <#CredSSP elevation#>
            }
            return $Session
        }
    }
}

function Connect-SessionToShare ($Session, $Share) {
    if ($Session.ConfigurationName -eq "Microsoft.Powershell") {
        # configure pssession
    }

    if ($Session.Protocol -eq "WSMAN") {
        # configure WSMAN CIM session
        Invoke-CimMethod -CimSession $Session -ClassName Win32_Process -MethodName create -Arguments @{
            commandline = "NET USE X $Share"
        } 
    }

    if ($Session.Protocol -eq "DCOM") {
        # configure DCOM CIM session
    }
}

function Disconnect-SessionToMDTShare ($Session) {
    if ($Session.Protocol -eq "WSMAN") {
        # configure WSMAN CIM session
        Invoke-CimMethod -CimSession $Session -ClassName Win32_Process -MethodName create -Arguments @{
            commandline = "NET USE X /DELETE"
        } 
    }
}

function Invoke-StartTaskSequence {
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
    .PARAMETER ComputerName
        One or more computers to run the task sequence on. You do not need to provide -ComputerName if you are already providing a -CimSession.
    .Parameter TaskSequenceName
        [Required] The visible name of a task sequence to run. [Optionally, you could pass the Task Sequence ID instead with the -TaskSequenceID parameter].
    .PARAMETER Credential
        [Required] A PSCredential object for a domain user who has Admin on the remote machine and access to the MDT share.
    .EXAMPLE
        Invoke-StartTaskSequence -ComputerName My_Computer -TaskSequence "Windows 10 Upgrade" -Credential (Get-Credential)
    #>
    [cmdletBinding()]
    param(
      [Parameter(ParameterSetName="Default")][Alias("h")][Switch]$help,
      #[Parameter(ParameterSetName="ComputerList")][System.Collections.ArrayList]$ComputerList,
      [Parameter(ParameterSetName="ComputersByName")][String]$ComputerName,
      [Parameter(ParameterSetName="CimSession")][CimSession]$CimSession,
      [Parameter()][Alias("TaskSequence")][String]$TaskSequenceName,
      [Parameter()][String]$TaskSequenceID,
      [Parameter()][PSCredential]$Credential
    )

    if ($help) { Write-Host "$(Get-Help Invoke-StartTaskSequence)"; return "help" }

    if ($TaskSequenceName) { $TaskSequenceID = Get-TaskSequenceIDFromName $TaskSequenceName }

    if ($ComputerName) {
        $ComputerName = Get-OnlineComputers $ComputerName
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
    } # TODO: Maybe un-necessary grabing computer names from passed cim sessions
    
    Invoke-CimMethod -CimSession $CimSession -ClassName Win32_Process -MethodName create -Arguments @{
        commandline = "powershell.exe /c Enable-PSRemoting -SkipNetworkProfileCheck -Force"
    }


    <# This is how we would prep the computers for CredSSP if that becomes necessary:
    #New-PSSession -ComputerName -ComputerName 

    #$ComputerName | ForEach-Object {
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Wait
    #}

    #Invoke-Command -ComputerName $ComputerName -ScriptBlock {          
    #    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force"
    #}  -Authentication Kerberos
    #>

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
    }

    $MDTShare = Get-DeploymentShareLocation
    Invoke-Command -Session $Session -ScriptBlock {
        New-PSDrive -Name M -Root $using:MDTShare -PSProvider "Filesystem" -Credential $using:Credential
        $env:SEE_MASK_NOZONECHECKS = 1
        cscript.exe "$using:MDTShare\Scripts\LiteTouch.wsf" /OSDComputerName:$env:COMPUTERNAME /TaskSequenceID:$using:TaskSequenceID /SKIPTaskSequence:YES /SKIPComputerName:YES
    }

    #Write-Verbose "Planning to execute Task Sequence $TaskSequenceID on $ComputerName."
    Remove-PSSession -Session $Session

    try {
        $DoneLabel.Text = "$Computer rebooted to continue $TaskSequenceID" 
        $DoneLabel.Forecolor = Get-SuccessColor
        $DoneLabel.Visible = $true 
    } catch { Write-Host "Finished Installing $ListOfSoftware" }
    
    try {
        $DoneLabel.Visible = $true
    } catch {}

    return 0
}

function Invoke-InstallApplication {
    <#
    .SYNOPSIS
        Connects to a remote computer using best available protocol (determined automatically in this function) and installs an application found on MDT.
    .DESCRIPTION
        Provide a name, list of names, or existing CimSession, as well as an Application Name name (or list of application names) to this function.
        It will connect to those computers (through DCOM, WMI methods, or CimSessions) and execute a short set of commands.
        It will connect to the MDT share stored in %APPDATA%\Push\config.xml (the configuration existing in the current powershell session running push)
        and then pull the application installer information (the location & install string), connect the computer to those locations, and run the install
        string. If you have a broken silent installer Push will fail to install the application, same as MDT.
    .INPUTS
        String: Computer Name OR CimSession: existing Cim Session
        String: Application Name OR (listof) Strings: Application Names
        Credentials: a PSCredential Object for a domain user who has Admin on the remote machine and access to the MDT share (AND any other shares referenced by MDT if necessary).
    .OUTPUTS
        (Nothing for now)
        TODO: A list of computer names which successfully installed the applications.
        TODO: A list of computer names which were offline at time of connection.
        TODO: any additional error messages that might be generated
    .NOTES
        Version:          2.0.0 <'Cause I already have Application installation under my belt from regular Push ;)>
        Authors:          Kyle Ketchell
        Version Creation: January 16, 2023
        Orginal Creation: January 16, 2023
    .PARAMETER ComputerName
        One or more computers to connect to and run the task sequence on. If you provide a -CimSession, you do not need to also provide the -ComputerName.
    .Parameter Application
        [Required] The visible name of an Application to install. The application name must match with the <Name> tag of an application in the Applications.xml file in MDT's Contro folder.
    .PARAMETER Credential
        [Required] A PSCredential object for a domain user who has Admin on the remote machine and access to the MDT share.
    .EXAMPLE
        Invoke-InstallApplication -ComputerName My_Computer -Application "Inkscape" -Credential (Get-Credential)
    .EXAMPLE
        Invoke-InstallApplication -ComputerName "My_Computer","Server-01","Workstation-04" -Application "Python (Current)","GIMP" -Credential $MyPSCredentialObject
    #>
    [cmdletBinding()]
    param(
      [Parameter(ParameterSetName="Default")][Alias("h")][Switch]$help,
      [Parameter(ParameterSetName="ComputersByName")][String]$ComputerName,
      [Parameter(ParameterSetName="CimSession")][CimSession]$CimSession,
      [Parameter()][Alias("A")]$Application,
      [Parameter()][PSCredential]$Credential
    )

    if ($help) { Write-Host "$(Get-Help Invoke-InstallApplication)"; return "help" }

    $ApplicationData = Get-ApplicationData -Name $Application
    $ComputerName = Get-OnlineComputers $ComputerName

    $Session = New-RemoteSession -ComputerName $ComputerName -Protocol 'CIM' -Authentication Kerberos -Credential $Credential

    Connect-SessionToMDTShare -Session $Session -Share (Get-DeploymentShareLocation)

    $ApplicationData | ForEach-Object {
        #Name
        #GUID
        #WorkingDirectory
        #CommandLine

        # Invoke-WSManAction may be an option?
    }
}