function Get-OnlineMachines ($ScanMachines) {
  $OnlineHosts = @()
  $ScanMachines | ForEach-Object {
    $online = Test-Connection -Count 1 -ComputerName $_ -Quiet
    if ($online) {
      $OnlineHosts += ($_)
    } else {
      Write-Verbose "Unable to connect to $_"
    }
  }
  return $OnlineHosts
}

function Get-ValidPushInstallers {
  param(
    [Parameter()]
    $SetOfFiles,
    [Parameter()][switch]
    $EXEs,
    [Parameter()][switch]
    $PSs,
    [Parameter()][switch]
    $BATs,
    [Parameter()][switch]
    $TestUCSSP
  )

  if ($TestUCSSP) {
    if ($SetOfFiles | Where-Object -Property Name -like "UseCredSSP.txt") {
      return $true
    }
  }

  $ExecutableFiles = $SetOfFiles | Where-Object  -Property Name -Like "*.exe" # Get any .exe files
  $ScriptFiles1 = $SetOfFiles | Where-Object -Property Name -Like "*.ps1" # Get any .ps1 files
  $BatchFiles = $SetOfFiles | Where-Object -Property Name -like "*.bat" # Get any .bat files

  if ($BATs) {
    return $BatchFiles
  }

  if ($EXEs) {
    return $ExecutableFiles
  }

  if ($PSs) {
    [System.Collections.ArrayList]$ScriptFiles = @()
    try {
      if ($ScriptFiles1.GetType() -is [System.IO.FileInfo]) {
        $ScriptFiles.add($ScriptFiles1)
      } else {
        $ScriptFiles1 | ForEach-Object { 
          $ScriptFiles.add($_) *> $null
        } 
      }
    } catch { }

    $ExecutableFiles | ForEach-Object {
      for ($i = 0; $i -lt $ScriptFiles1.Count; $i++) { 
        if ($ScriptFiles1[$i].BaseName -eq $_.BaseName) { 
          $ScriptFiles.Remove($ScriptFiles1[$i])
        } 
      }
    }
    return $ScriptFiles
  }
}

function Start-Install {
  <#
  .SYNOPSIS
    Install software on remote machines
  .DESCRIPTION
    Pass a list of machines to act on (these can be online or offline, the function will skip the offline machines and make a note of it)
    Pass a list of install folder names to act on (these must be folders in the Push\Software drive)
  .PARAMETER Machines, ListOfMachines
    [Array of Strings] A list of machine names 
    [String] A single machine name
    RfI will connect to these machines when it attempts to install software
  .PARAMETER Installers, ListOfInstallers
    [Array of Strings] the name of an installer folder which exists in PUSH\Software
    RfI will install the software(s) listed.
  .PARAMETER UseCredSSP
    Pass this flag to use CredSSP authentication when installing software.
  .EXAMPLE 
    RefactoredInstall -Machines ["Machine01", "Server1", "OfficeComputer"] -Installers ["Test_Silent_Installer"]
    This will run Executables, PS1 scripts, and BAT files from the Test_Silent_Installer folder in PUSH\Software on Machine01, Server1 and OfficeComputer
  .EXAMPLE
    RefactoredInstall -Machines ["Lab1-04"] -Installers ["My_Complicated_Software"] -C
    This will install "My_Complicated_Software" from the PUSH\Software folder onto Lab1-04 using CredSSP Authentication.
  #>
  param(
    [Parameter()][Alias("Machines")]
    $ListOfMachines,

    [Parameter()][Alias("Installers")]
    $ListOfInstallers,
    
    [Parameter()][Alias("UseCredSSP")][Switch]
    $ForceUseCredSSPAuthentication,

#    [Parameter()]
#    $Config,
    
    [Parameter()][PSCredential]
    $Credential
  )

  $WorkingMachines = Get-OnlineMachines($ListOfMachines)

  if ($WorkingMachines) {                                
    $AUTHMETHOD = "Kerberos"

    if ($ForceUseCredSSPAuthentication) {
      $WorkingMachines | ForEach-Object {            
        Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Verb RunAs -Wait 
      }                                                          
      Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","-Role","'Client'","-DelegateComputer",'"*.engr.colostate.edu"',"-Force" -Verb RunAs -Wait 
      Invoke-Command -ComputerName $WorkingMachines -ScriptBlock {          
        Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force" -Verb RunAs -Wait  
      }                         

      $AUTHMETHOD = "CredSSP"    
      #$SESSION = New-PSSession $WorkingMachines -Credential $Credential -Authentication Credssp # Create the PSSession
    }

    $SESSION = New-PSSession -ComputerName $WorkingMachines -Credential $Credential -Authentication $AUTHMETHOD

    try { 
      Invoke-Command -Session $SESSION -ScriptBlock { 
        Set-ExecutionPolicy Bypass -Scope Process -Force
      } 
    } catch { 
      [System.Windows.Forms.MessageBox]::Show("Could not connect to the session. WinRM is not yet enabled. Most likely due to slow startup-should work after waiting for a few minutes.", "WinRM not enabled.")
      return (2, "FAILED to act on created session.", "Session was created, but was unable to be configured after creation.")
    } 
    $PDriveLocation = Get-SoftwareFolderLocation
    Invoke-Command -Session $SESSION -ScriptBlock {
      New-PSDrive -Name P -Root $using:PDriveLocation -PSProvider "Filesystem" -Credential $using:Credential
      $env:SEE_MASK_NOZONECHECKS = 1 
    }
    
    ForEach ($Software in $ListOfInstallers) {

      $files = Get-ChildItem "$(Get-SoftwareFolderLocation)\$Software"   

      $executables = $null
      $scripts = $null
      $bats = $null

      $executables = Get-ValidPushInstallers $files -EXEs
      $scripts = Get-ValidPushInstallers $files -PSs
      $bats = Get-ValidPushInstallers $files -BATs

      $executables | ForEach-Object {
        Invoke-Command -Session $SESSION -ScriptBlock { & $using:_.FullName } -AsJob | Get-Job | Wait-Job
      }
      
      $scripts | ForEach-Object {                           
        Set-ExecutionPolicy Bypass -Scope Process
        Invoke-Command -Session $SESSION -FilePath $_.FullName
      }
      
      $bats | ForEach-Object { 
        log "4.1: BAT: Found $($_.FullName), batching." 1   
        Invoke-Command -Session $SESSION -ScriptBlock { & $using:_.FullName } 
      } 
    } 

    Invoke-Command -Session $SESSION -ScriptBlock {  
      $env:SEE_MASK_NOZONECHECKS = 0
      Remove-PSDrive -Name P 
    }
    Remove-PSSession -Session $SESSION 
  } else { 
    try {
      $DoneLabel.Text = "All selected machines were offline."
      $DoneLabel.ForeColor = Get-WarningColor
      $DoneLabel.Visible = $true 
    } catch { }
    return (1, "All of $ListOfMachines were offline.", "Please ensure that at least 1 selected machine is online.") 
  }   
  return 0  
}

function Invoke-Install {
  param(
    [Parameter()][Alias("Machines")]
    $ListOfMachines,

    [Parameter()][Alias("Installers")]
    $ListOfInstallers,
    
    [Parameter()][Alias("UseCredSSP")][bool]
    $ForceUseCredSSPAuthentication=$false,

    [Parameter()]
    $Config,
    
    [Parameter()][PSCredential]
    $Credential
  )

  try {
    $DoneLabel.Visible = $false
  } catch {}

  ForEach ($Software in $ListOfInstallers) {
    $files = Get-ChildItem "$(Get-SoftwareFolderLocation)\$Software"

    if (Get-ValidPushInstallers $files -TestUCSSP) { 
      Start-Install -ListOfMachines $ListOfMachines -ListOfInstallers $Software -Credential $Credential -ForceUseCredSSPAuthentication 
    }
    else { 
      Start-Install -ListOfMachines $ListOfMachines -ListOfInstallers $Software -Credential $Credential 
    }
  }

  try {
    $DoneLabel.Text = "Finished Installing $ListOfInstallers" 
    $DoneLabel.Forecolor = Get-SuccessColor
    $DoneLabel.Visible = $true 
  } catch { Write-Host "Finished Installing $ListOfSoftware" }

  try {
    $DoneLabel.Visible = $true
  } catch {}
}

function Start-Uninstall {
  param(
    [Parameter()][Alias("Machines")]
    $ListOfMachines,

    [Parameter()][Alias("UninstallString")]
    $ListOfUninstallStrings,
    
    [Parameter()][Alias("UseCredSSP")][bool]
    $ForceUseCredSSPAuthentication=$false,

    [Parameter()]
    $Config,
    
    [Parameter()][PSCredential]
    $Credential
  ) 
  
  try { log "Attempting to invoke $ListOfUninstallStrings on $ListOfMachines using CredSSP=$ForceUseCredSSPAuthentication" 0 }
  catch { if ($_ -like "*The term 'log' is not recognized*") { return (1, "Unable to log.", "attempting to log information failed, the term 'log' is not recognized. Please ensure log has been imported to the sesion correctly.") } return (1, "Unable to log.", "There was an issue with logging. Message: $_") }

  $WorkingMachines = Get-OnlineMachines($ListOfMachines)
  log $WorkingMachines 0  

  if ($WorkingMachines) {                                
    log "Acting on '$WorkingMachines'" 0  

#    $AUTHMETHOD = "Kerberos"
<#
    log "1.1: Testing for CredSSP..." 0 
    if ($ForceUseCredSSPAuthentication) {
      log "1.1: Using CredSSP Authentication." 0  
      log "1.2: Configuring enable CredSSP Session." 0  
      log "1.3: Enabling WSManCredSSP for working machines..." 0  
      $WorkingMachines | ForEach-Object {            
        log "1.3: Enabling CSSP for $_" 0  
        Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Verb RunAs -Wait 
      }                                                          
      log "1.4: Enabling WSManCredSSP for *.engr.colostate.edu..." 0  
      Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","-Role","'Client'","-DelegateComputer",'"*.engr.colostate.edu"',"-Force" -Verb RunAs -Wait 
      log "1.4: Enabling WSManCredSSP on Session..." 0  
      Invoke-Command -ComputerName $WorkingMachines -ScriptBlock {          
        Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force" -Verb RunAs -Wait  
      }                                     
      log "1.5: Setting AUTHMETHOD to 'CredSSP" 0  
      $AUTHMETHOD = "CredSSP"    
      log "1.6: Ready for CredSSP Session" 0  
      #$SESSION = New-PSSession $WorkingMachines -Credential $Credential -Authentication Credssp # Create the PSSession
    }

    log "2.0: Creating PS Sessions..." 0  
    log "2.0: i) This session will be with $WorkingMachines" 0  
    log "2.0: i) This session will be run by user: $($Credential.UserName)" 0  
    log "2.0: i) This session will have authentication: $AUTHMETHOD" 0  
    $SESSION = New-PSSession -ComputerName $WorkingMachines -Credential $Credential -Authentication $AUTHMETHOD
    log "2.1: i) Session created." 0
    log "2.2: Session: $SESSION" 0
#>
    <#Configure the sessions#>
    log "3.0: Configuring session..." 0  
    log "3.1: Configuring Session: Setting EP" 0   
    try { 
      Invoke-Command -Session $SESSION -ScriptBlock { 
        Set-ExecutionPolicy Bypass -Force  
      } 
    } catch { 
      [System.Windows.Forms.MessageBox]::Show("Could not connect to the session. WinRM is not yet enabled. Most likely due to slow startup-should work after waiting for a few minutes.", "WinRM not enabled.")
      return (2, "FAILED to act on created session.", "Session was created, but was unable to be configured after creation.")
    } 
    log "3.1: Configuring session: Set EP." 0   
    log "3.2: Configuring Session: Mapping P drive" 0  
    log "3.3: Configuring Session: Setting SMNZC = 1" 0   
    #$PDriveLocation = $Config.Package.Location
    $PDriveCallOutput = Invoke-Command -Session $SESSION -ScriptBlock {
#      New-PSDrive -Name P -Root $using:PDriveLocation -PSProvider "Filesystem" -Credential $using:Credential
      $env:SEE_MASK_NOZONECHECKS = 1 
    }
    log "3.2: SESSION INFO: $PDriveCallOutput" 0
    log "3.2: Configuring Session: Mapped P Drive" 0   
    log "3.3: Configuring Session: Set SMNZC = 1" 0    
    
    <#Installing software from $ALISTOFINSTALLERS#>
    log "4.0: Beginning install of selected software..." 1   
    ForEach ($UninstallString in $ListOfUninstallStrings) { 
      Invoke-Command -Session $SESSION -ScriptBlock { & $UninstallString } -Credential $Credential
    } 

    log "5.0: Cleanup: Beginning clean up on Remote machine" 0    
    log "5.1: Cleanup: Setting env:SMNZC to 0" 0  
    log "5.2: Cleanup: NOT RESETTING EP: will let bypass expire naturally." 0  
    log "5.3: Cleanup: Removing P drive" 0  
    Invoke-Command -Session $SESSION -ScriptBlock {  
      $env:SEE_MASK_NOZONECHECKS = 0
    #  Set-ExecutionPolicy Restricted  
#      Remove-PSDrive -Name P 
    } 
    log "5.1: Cleanup: Set env:smz to 0" 0   
    log "5.3: Cleanup: Removed P drive" 0   
    log "5.4: Cleanup: Removing session $SESSION" 0   
    Remove-PSSession -Session $SESSION 
    log "5.4: Cleanup: Removed session" 0   
    log "Finished Cleanup" 1     

  } else { 
    log "All of $ListOfMachines were offline." 1    
    try {
      $DoneLabel.Text = "All selected machines were offline."
      $DoneLabel.ForeColor = $Config.ColorScheme.Warning 
      $DoneLabel.Visible = $true 
    } catch { }      
    return (1, "All of $ListOfMachines were offline.", "Please ensure that at least 1 selected machine is online.") 
  }   
  return 0  
}

function Invoke-Uninstall {
  param(
    [Parameter()][Alias("Machines")]
    $ListOfMachines,

    [Parameter()][Alias("UninstallString")]
    $ListOfUninstallStrings,
    
    [Parameter()][Alias("UseCredSSP")][bool]
    $ForceUseCredSSPAuthentication=$false,

    [Parameter()]
    $Config,
    
    [Parameter()][PSCredential]
    $Credential
  ) 

}









<#CAUTION! LEGACY CODE BELOW THIS LINE! EDIT AT YOUR OWN RISK!#>

###########################################################################
# Documentation: Install Software                                         #
# Iterate through a list of machines and software to run an executable on #
# a remote machine to install software.                                   #
###########################################################################
function softwareinstall {                                                # Create softwareinstall function
  <#DEPRECATED SINCE PUSH 2.8, USE THE INVOKE-INSTALL FUNCTION INSTEAD#>
  param($global:SelectedMachines,$global:SelectedSoftware)                #
  if (-Not $silent) {                                                     #
    $DoneLabel.Visible = $false                                           # If there's a GUI, hide the done label
    $DoneLabel.ForeColor = $global:DoneLabelColor                         # Reset the color too
  }                                                                       # 
  $WorkingMachines = Get-OnlineMachines($global:SelectedMachines)         # Create a new array
                                                                            #
  log $WorkingMachines 1                                                   ### Debug, write out the working machines
  if ("" -ne $WorkingMachines) {                                          # If there are working machines then:
    log "Acting on '$WorkingMachines'" 1                                   ### Debug, which machines we selected
    ##############################################################        #
    # Documentation: Create a powershell sesion                  #        #
    # We need to connect to a remote computer and command it to  #        #
    # do things. This is accomplished through a PSSession. Create#        #
    # it with New-PSSession and the arguments, and we'll use     #        #
    # invoke-command -session to send it commands.               #        #
    ##############################################################        #
    log "1. Creating pssessions..." 0                              #       ### log that sessions are being made
    $SESSION = New-PSSession -ComputerName $WorkingMachines -Credential $global:Creds # Create the sessions
    $TestSessions = Get-Pssession                                #        # Get a list of all sessions
    $WorkingMachines | ForEach-Object {                          #        # iterate through the working machines:
      log $TestSessions 1                                          #       ### log the sessions
      if ($TestSessions.ComputerName -like $_) {                 #        # if there is a session with it:
        log "1. Created pssession with $_" 0                       #        # log it
      } else {                                                   #        # otherwise
        log "E: UNABLE TO CREATE SESSION WITH $_" 2                #        # its bad, let the user know
        return 1                                                 #        # go back to the main form
      }                                                          #        # 
    }                                                            #        #
    log $SESSION 0                                                 #       ### log the sessions
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Set-ExecutionPolicy                         #        #
    # Windows computers don't like executing powershell scripts, #        #
    # its a security risk. but we need to in order to use PUSH.  #        #
    # So we'll set the execution policy (and reset it later).    #        #
    ##############################################################        #
    log "2. Trying to Set Execution Policy on selected machines" 0         ### log tried to set execution policy
    try {                                                        #        # try this:
      Invoke-Command -Session $SESSION -ScriptBlock {            #        # on the remote machine:
        Set-ExecutionPolicy Bypass -Force                        #        #   set the execution policy
      }                                                          #        #
    } catch {                                                    #        # if that failed:
      [System.Windows.Forms.MessageBox]::Show($_)                #        # show why in a message box
      Return 0                                                   #        # crash gently back into Push
    }                                                            #        #
    log "2. Set execution policy" 0                                #       ### log execution policy changed
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Map P drive on remote machine               #        #
    # To access the software installers from PUSH, the remote    #        #
    # computer needs access to the network share. this chunk maps#        #
    # that share on the remote machine.                          #        #
    ##############################################################        #
    log "Trying to map P drive" 0                                  #       ### log that we're mapping the P drive
    $PDriveLocation = $Config.Package.Location                   #        #
    Invoke-Command -Session $SESSION -ScriptBlock {              #        #
      New-PSDrive -Name P -Root $using:PDriveLocation -PSProvider "Filesystem" -Credential $using:Creds 
      $ldrives = Get-PSDrive                                     #        #
      If (-Not (test-path "$using:lfilename-$env:COMPUTERNAME.txt")) { New-Item "$using:lfilename-$env:COMPUTERNAME.txt" }
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "PSDRIVES: $($ldrives)"
    }                                                            #        #
    log "Mapped P drive on remote machines" 1                      #       ### log that we did it
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Set environment to not check for trusts     #        #
    # Windows has trust issues, so it brings up a popup when you #        #
    # try to run software from an untrusted location. SO... this #        #
    # sets an environment variable which tells windows not to    #        #
    # bring up that popup.                                       #        #
    # For the record, this thing has absolutely Zero documentation        #
    # from Microsoft, and was created for Windows XP then totally         #
    # forgotten about.                                           #        #
    ##############################################################        #
    log "Setting env:SEE_MASK_NOZONECHECKS to 1" 0                 #       ### Log, we're going to set env:smnzc
    Invoke-Command -Session $SESSION -ScriptBlock {              #        # do it on the remote machine:
      $env:SEE_MASK_NOZONECHECKS = 1                             #        # Set the variable
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "SMNZC = $env:SEE_MASK_NOZONECHECKS" 
    }                                                            #        # log it
    log "Set env:smz to 1" 0                                       #       ### Log we did it
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: install all of the software                 #        #
    # This will iterate through each folder in the $SOFTWARE     #        #
    # folder and run (on the remote computer) any executable files        #
    # for the selected software.                                 #        #
    ##############################################################        #
    log "Beginning of foreachsoftware loop" 1                      #       ### log we're iterating through software
    ForEach ($Software in $global:SelectedSoftware) {            #        # iterate through the selected software
      $files = Get-ChildItem "$($Config.Package.Software)\$Software"      # get every file in the selected folders
      $executables = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object  -Property Name -Like "*.exe" # Get any .exe files
      $scripts1 = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object -Property Name -Like "*.ps1" # Get any .ps1 files
      $bats = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object -Property Name -like "*.bat" # Get any .bat files
      [System.Collections.ArrayList]$scripts = @()               #        #
      #Write-Host $Scripts1.GetType()                             #        #
      #Write-Host $scripts1                                       #        #
      if ($scripts1.GetType() -is [System.IO.FileInfo]) {        #        #
        $scripts.add($scripts1)                                  #        # 
      } else {                                                   #        #
        $scripts1 | ForEach-Object {                             #        #
          log "Found Object $_" 1                                  #        # 
          log "Has name $($_.Name)" 1                              #        #
          $scripts.add($_)                                       #        #
        }                                                        #        #
      }                                                          #        # Create an arraylist of scripts
      log "Found these files: $files" 1                            #       ### log, write name of all files found 
      log "And our scripts: $scripts" 1                            #        #
      if (Test-Path "$($Config.Package.Software)\$Software\*" -Include README* ) { # if there are any README files:
        log "Found a README, displaying as a popup" 1              #        # log that we found a README
        $Info_flag = $files | Where-Object {$_.Name -like "README*"}      #
        $Info_flag_Content = Get-Content -Path $Info_flag.FullName        # read the contents of the file
        log "Readme: '$Info_flag_Content'" 1                                #
        [System.Windows.Forms.MessageBox]::Show($Info_flag_Content)       # popup a message showing that content
      }                                                          #        #
      ########################################################   #        #
      # Documentation: don't execute matching executables &  #   #        #
      # scripts. Basically I want to keep the source script  #   #        #
      # in the same place as my .exe generated with ps2exe.  #   #        #
      # So I go through all .exes, and remove any .ps1s with #   #        #
      # a matching name from the $scripts arraylist.         #   #        #
      ########################################################   #        #
      $executables | ForEach-Object {                        #   #        # Iterate through the executables list
        for ($i = 0; $i -lt $scripts1.Count; $i++) {         #   #        # Iterate through the files in the $scripts1 list
          log "Looking at $($scripts1[$i].BaseName) and $($_.BaseName)" 1  
          if ($scripts1[$i].BaseName -eq $_.BaseName) {      #   #        # if the name of any script matches the name of the current .exe:
            log "Found a match: $($Scripts1[$i].BaseName) & $($_.BaseName)" 1  
            $scripts.Remove($scripts1[$i])                   #   #        # remove that .ps1 script from the $scripts list
          }                                                  #   #        #
        }                                                    #   #        #
      }                                                      #   #        #
      ########################################################   #        #
      log "Installing $Software..." 2                              #       ### write that we're starting the install
      log "Here's what we've got:" 1                               #       ### log, the files we found
      log "Files: $files" 1                                        #       ### log the files
      log "executables: $executables" 1                            #       ### log the executables
      log "scripts: $scripts" 1                                    #       ### log the .ps1s
      log "bats: $bats" 1                                          #       ### log the .bats
                                                                 #        #
      #########################################################  #        #
      # Documentation: foreach file in the folder             #  #        #
      # Execute any .exes, and run any .ps1 scripts.          #  #        #
      #########################################################  #        #
      $executables | ForEach-Object {                         #  #        # Iterate through executables
        log "Found $($_.FullName), attempting to execute" 1     #  #       ### Debug, we're going to execute it
        Invoke-Command -Session $SESSION -ScriptBlock {       #  #        # On the remote computer:
          Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "STARTING EXECUTION OF $($using:_.Name)"### log that the install started
          & $using:_.FullName                                 #  #        # Call the script
        } -AsJob | Get-Job | Wait-Job                         #  #        # Run it as a job and pass it back, wait for the job to finish.
      }                                                       #  #        #
      $scripts | ForEach-Object {                             #  #        # iterate through powershell scripts
        log "Found $($_.FullName), attempting to run with powershell" 1   ### Debug, we're going to run it
        Invoke-Command -Session $SESSION -FilePath $_.FullName   #        # run the script on the remote computer
      }                                                       #  #        #
      $bats | ForEach-Object {                                #  #        # iterate through batch files
        log "Found $($_.FullName), batching." 1                 #  #       ### debug, we're going to batch it
        Invoke-Command -Session $SESSION -ScriptBlock {       #  #        # On the remote computer:
          Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "STARTING EXECUTION OF BATCH $($using:_.Name)" ### log that the batch started
          & $using:_.FullName                                 #  #        # run the .bat file
        }                                                     #  #        #
      }                                                       #  #        #
      #########################################################  #        #
                                                                 #        #
      log "Finished $Software" 1                                   #       ### debug that we finished $software
      if (-Not $silent) {                                        #        # If we're not running in silent mode:
        $DoneLabel.Text = "Still working..."                     #        # set Done label that it is working
        $DoneLabel.Visible = $true                               #        # make the done label visible
      }                                                          #        #
    }                                                            #        # [end of the for-each loop]
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Check to see if the software was installed  #        #
    # Sometimes software is a torking nightmare and doesn't      #        #
    # install, But its anoying to go into every machine and check#        #
    # so this automates that process.                            #        #
    ##############################################################        # Get Installed software from remote:
    Invoke-Command -Session $SESSION -ScriptBlock {              #        # On the remote computer:
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" ":::This is is $env:COMPUTERNAME:::"      # Write out the name to the logfile
      $Installed = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" # get installed software from the registry
      $Installed | ForEach-Object {                              #        # Iterate through the installed software
        Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "::: $($_.GetValue('DisplayName')) - $($_.GetValue('DisplayVersion'))" # put it in the log file
      }                                                          #        #
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "Done Listing Software:::" # No more software to list.
    }                                                            #        #
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Wrapping up from the installs               #        #
    # After we're done installing everything, let the user know  #        #
    # via the done label. Then remove the P:\ drive on the remote#        #
    # computer, reset the execution policy, and close the pssession       #
    ##############################################################        #
    log "Beginning clean up on Remote machine" 0                   #       ### Log, we're going to set env:smnzc
    Invoke-Command -Session $SESSION -ScriptBlock {              #        # On the remote computer:  
      $env:SEE_MASK_NOZONECHECKS = 0                             #        # Set the env:SMNZC variable = 0
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "SMNZC = $env:SEE_MASK_NOZONECHECKS" # log the value
      Set-ExecutionPolicy Restricted                             #        # Set the executionpolicy to restricted
      $execp = Get-ExecutionPolicy                               #        # query the executionpolicy
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "ExecutionPolicy = $execp" # write it to the log file
      Remove-PSDrive -Name P                                     #        # remove the P:\ drive
      Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "logoff. Goodbye!" # End of log from Remote computer
    }                                                            #        # End of work on remote machine   
    log "Set env:smz to 0" 0                                       #       ### Log we did it    
    log "Reset ExecutionPolicy to Restricted" 0                    #       ### log, we reset the execution policy
    log "Removed P drive" 0                                        #       ### log that we removed the P:\ drive
    log "Removing session $SESSION" 0                              #       ### log that we're removing the session
    Remove-PSSession -Session $SESSION                           #        # end the remote session
    log "Removed session" 0                                        #       ### log, we ended the session
    log "Finished Cleanup" 1                                       #       ### debug that we're all done cleaning up
    if (-Not $silent) {                                          #        # If were running with a GUI
      $DoneLabel.Text = "Finished Installing $global:SelectedSoftware"    # Update the Done Label
      $DoneLabel.Visible = $true                                 #        # Make the Done label visible
    }                                                            #        #
    log "Done." 2                                                  #        #
    ##############################################################        #
                                                                          #
  ################################################################        #
  # Documentation: there were no online machines                 #        #
  # Tell the user every machine they selected (usually if they   #        #
  # only selected the one machine) were/was offline.             #        #
  ################################################################        #
  } else {                                                       #        # OTHERWISE all of them were offline.
    log "All of $global:SelectedMachines were offline." 1          #       ### debug, say that they were offline
    if (-Not $silent) {                                          #        # if there's a GUI (and a done label)
      $DoneLabel.Text = "All selected machines were offline."    #        # change the text
      $DoneLabel.ForeColor = $Config.ColorScheme.Warning         #        # change the color
      $DoneLabel.Visible = $true                                 #        # make it visible
    }                                                            #        #
  }                                                              #        #
  ################################################################        #
                                                                          #
  <#NOTE: PlaySound at the end of install is slated for removal in
  Push 2.9 (Jerzy Jobs), with the ability to schedule jobs for execution
  as soon as possible, the sounds at the end of an install would be
  confusing. Which job just finished? idk, don't really care, cause Jobs.#>
  ################################################################        #
  # Documentation: play a sound to indicate that PUSH finished.  #        #
  # This little chunk plays a sound from the Media folder to     #        #
  # audibly indicate that PUSH has finished acting on the remote #        #
  # computers.                                                   #        #
  ################################################################        #
  #if (-Not $silent) {                                            #        # If we're not running in silent mode:
  #  $PlayWav=New-Object System.Media.SoundPlayer                 #        # Create a soundplayer object
  #  $Location = Get-Item (Convert-Path $Config.Package.Media + '\Windows XP Notify.wav')  # That's where the file is
  #  $PlayWav.SoundLocation = $Location                           #        # Tell it to play that^ file
  #  $PlayWav.playsync()                                          #        # play it
  #}                                                              #        #
  ################################################################        #
}                                                                         #
#log "Read through SoftwareInstall function" 0 # Debugging checkpoint      #
########################################################################### End of the SoftwareInstall function
  
###########################################################################
# Documentation: Install software with CredSSP authentication             #
# Some software needs special authenticaiton (via CredSSP) to install.    #
# Basically, instead of just telling the remote computer "hey, I'm good   #
# to log in, the Domain says so" (regular install) CredSSP actually sends #
# your credentials to the remote computer as if you were logging in for   #
# real. "Hey, I'm ____ and my password is ____" and the computer says "ok"#
# and does things with those credentials. This is great for software like #
# solidworks and autocad, but not so great cause it can be a _slight_     #
# security concern given a sufficently advanced attacker with sufficient  #
# permissions (basically only someone who works for ETS could do this)    #
# but to be on the safe side we don't want to install all software this   #
# way. So here it is, to install with CredSSP Authentication, but only to #
# be used if a particular software needs it.                              #
###########################################################################
function CSSPSoftwareInstall {                                            # Create CSSPSoftwareInstall function
  <#DEPRECATED SINCE 2.8 - USE THE INVOKE-INSTALL FUNCTION INSTEAD#>
  log "Starting Software Install with CSSP Authentication" 1               ### Debug, starting CredSSP installer
  if (-Not $silent) {                                                     #
    $DoneLabel.Visible = $false                                           # If there's a GUI, hide the done label
    $DoneLabel.ForeColor = $global:DoneLabelColor                         # Reset the color too
  }                                                                       # 
  $WorkingMachines = Get-OnlineMachines ($global:SelectedMachines)        # Create a new array
                                                                          #
  log $WorkingMachines 1                                                   ### Debug, write out the working machines
  if ("" -ne $WorkingMachines) {                                          # If there are working machines then:
    log "Acting on '$WorkingMachines'" 1                                   ### Debug, which machines we selected
    ##############################################################        #
    # Documentation: Create a powershell sesion                  #        #
    # We need to connect to a remote computer and command it to  #        #
    # do things. This is accomplished through a PSSession. Create#        #
    # it with New-PSSession and the arguments, and we'll use     #        #
    # invoke-command -session to send it commands.               #        #
    ##############################################################        #
    log "1. Creating pssessions..." 0                              #       ### log that sessions are being made
    $SESSION = New-PSSession -ComputerName $WorkingMachines -Credential $global:Creds # Create the sessions
    $TestSessions = Get-Pssession                                #        # Get a list of all sessions
    $WorkingMachines | ForEach-Object {                          #        # iterate through the working machines:
      log $TestSessions 1                                          #        # log the sessions
      if ($TestSessions.ComputerName -like $_) {                 #        # if there is a session with it:
        log "1. Created pssession with $_" 0                       #        # log it
      } else {                                                   #        # otherwise
        log "E: UNABLE TO CREATE SESSION WITH $_" 2                #        # its bad, let the user know
        return 1                                                 #        # stop and go back to the main form
      }                                                          #        # 
    }                                                            #        #
    log $SESSION 0                                                  #       ### log the sessions
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Set-ExecutionPolicy                         #        #
    # Windows computers don't like executing powershell scripts, #        #
    # its a security risk. but we need to in order to use PUSH.  #        #
    # So we'll set the execution policy (and reset it later).    #        #
    ##############################################################        #
    log "2. Trying to Set Execution Policy on selected machines" 0         ### log tried to set execution policy
    try {                                                        #        # try this:
      $PDriveLocation = $Config.Package.Location                 #        # set the P drive location
      Invoke-Command -Session $SESSION -ScriptBlock {            #        # on the remote machine:
        Set-ExecutionPolicy Bypass -Force                        #        #   set the execution policy
        New-PSDrive -Name P -Root $using:PDriveLocation -PSProvider "Filesystem" -Credential $using:Creds 
        $env:SEE_MASK_NOZONECHECKS = 1                           #        # Set the variable
      }                                                          #        #
    } catch {                                                    #        # if that failed:
      [System.Windows.Forms.MessageBox]::Show($_)                #        # show why in a message box
      Return 0                                                   #        # crash hard
    }                                                            #        #
    log "2. Set execution policy" 0                                #       ### log execution policy changed
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: set up the computers for CSSP auth          #        #
    # This will configure both computers to do the CredSSP Auth  #        #
    ##############################################################        #
    $WorkingMachines | ForEach-Object {                          #        # Iterate through the working machines
      Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Client","$_","-Force" -Verb RunAs -Wait                      #        #
    }                                                            #        # enable wsmancredssp for each one
    Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","-Role","'Client'","-DelegateComputer",'"*.engr.colostate.edu"',"-Force" -Verb RunAs -Wait # enable WSManCredSSP for anything on the domain
    Invoke-Command -Session $SESSION -ScriptBlock {              #        # On the remote computer:
      Start-Process powershell.exe -ArgumentList "Enable-WSManCredSSP","Server","-Force" -Verb RunAs -Wait  #        # Enable WSManCredSSP as a server
    }                                                            #        # 
    $CSSPSESSION = New-PSSession $WorkingMachines -Credential $Creds -Authentication Credssp # Create the PSSession
    Invoke-Command $CSSPSESSION -ScriptBlock {                   #        # On the remote computer, setup the session:
      Set-ExecutionPolicy Bypass -Force                          #        # set the executionpolicy
      New-PSDrive -Name P -Root $using:PDriveLocation -PSProvider "Filesystem" -Credential $using:Creds # Map the P drive
      $env:SEE_MASK_NOZONECHECKS = 1                             #        # Set the variable
    }                                                            #        #
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: install all of the software                 #        #
    # This will iterate through each folder in the $SOFTWARE     #        #
    # folder and run (on the remote computer) any executable files        #
    # for the selected software.                                 #        #
    ##############################################################        #
    ForEach ($Software in $global:SelectedSoftware) {            #        # iterate through the selected software
      $files = Get-ChildItem "$($Config.Package.Software)\$Software"      # get every file in the selected folders
      $executables = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object  -Property Name -Like "*.exe" # Get any .exe files
      $scripts1 = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object -Property Name -Like "*.ps1" # Get any .ps1 files
      $bats = Get-ChildItem "$($Config.Package.Software)\$Software" | Where-Object -Property Name -like "*.bat" # Get any .bat files
      [System.Collections.ArrayList]$scripts = @()               #        #
      if ($scripts1.GetType() -is [System.IO.FileInfo]) {        #        #
        $scripts.add($scripts1)                                  #        # 
      } else {                                                   #        #
        $scripts1 | ForEach-Object {                             #        #
          log "Found Object $_" 1                                  #        # 
          log "Has name $($_.Name)" 1                              #        #
          $scripts.add($_)                                       #        #
        }                                                        #        #
      }                                                          #        # Create an arraylist of scripts
      log "Found these files: $files" 1                           #       ### log, write name of all files found 
      log "And our scripts: $scripts" 1                            #        #
      if (Test-Path "$($Config.Package.Software)\$Software\*" -Include README* ) { # if there are any README files:
        log "Found a README, displaying as a popup" 1              #        # log that we found a README
        $Info_flag = $files | Where-Object {$_.Name -like "README*"}      #
        $Info_flag_Content = Get-Content -Path $Info_flag.FullName        # read the contents of the file
        log "Readme: '$Info_flag_Content'" 1                                #
        [System.Windows.Forms.MessageBox]::Show($Info_flag_Content)       # popup a message showing that content
      }                                                          #        #
      ########################################################   #        #
      # Documentation: don't execute matching executables &  #   #        #
      # scripts. Basically I want to keep the source script  #   #        #
      # in the same place as my .exe generated with ps2exe.  #   #        #
      # So I go through all .exes, and remove any .ps1s with #   #        #
      # a matching name from the $scripts arraylist.         #   #        #
      ########################################################   #        #
      $executables | ForEach-Object {                        #   #        # Iterate through the executables list
        for ($i = 0; $i -lt $scripts1.Count; $i++) {         #   #        # Iterate through the files in the $scripts1 list
          log "Looking at $($scripts1[$i].BaseName) and $($_.BaseName)" 1  
          if ($scripts1[$i].BaseName -eq $_.BaseName) {      #   #        # if the name of any script matches the name of the current .exe:
            log "Found a match: $($Scripts1[$i].BaseName) & $($_.BaseName)" 1  
            $scripts.Remove($scripts1[$i])                   #   #        # remove that .ps1 script from the $scripts list
          }                                                  #   #        #
        }                                                    #   #        #
      }                                                      #   #        #
      ########################################################   #        #
      log "Installing $Software..." 2                              #       ### write that we're starting the install
      log "Here's what we've got:" 1                               #       ### log, the files we found
      log "Files: $files" 1                                        #       ### log the files
      log "executables: $executables" 1                            #       ### log the executables
      log "scripts: $scripts" 1                                    #       ### log the .ps1s
      log "bats: $bats" 1                                          #       ### log the .bats
                                                                 #        #
      #########################################################  #        #
      # Documentation: foreach file in the folder             #  #        #
      # Execute any .exes, and run any .ps1 scripts.          #  #        #
      #########################################################  #        #
      $executables | ForEach-Object {                         #  #        # Iterate through every file in folder
        log "Found $($_.FullName), attempting to execute" 1     #  #       ### Debug, we're going to execute it
        Invoke-Command -Session $CSSPSESSION -ScriptBlock {       #  #        # On the remote computer:
          Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "STARTING EXECUTION OF $($using:_.Name)"### log that the install started
          & $using:_.FullName                                 #  #        # Call the script
        } -AsJob | Get-Job | Wait-Job                         #  #        # Run it as a job and pass it back, wait for the job to finish.
      }                                                       #  #        #
      $scripts | ForEach-Object {                             #  #        # 
        log "Found $($_.FullName), attempting to run with powershell" 1   ### Debug, we're going to run it
        Invoke-Command -Session $CSSPSESSION -FilePath $_.FullName   #        # run the script on the remote computer
      }                                                       #  #        #
      $bats | ForEach-Object {                                #  #        # iterate through batch files
        log "Found $($_.FullName), batching." 1                 #  #       ### debug, we're going to batch it
        Invoke-Command -Session $SESSION -ScriptBlock {       #  #        # On the remote computer:
          Add-Content "$using:lfilename-$env:COMPUTERNAME.txt" "STARTING EXECUTION OF BATCH $($using:_.Name)" ### log that the batch started
          & $using:_.FullName                                 #  #        # run the .bat file
        }                                                     #  #        #
      }                                                       #  #        #
      #########################################################  #        #
                                                                 #        #
      log "Finished $Software" 1                                   #       ### debug that we finished $software
      if (-Not $silent) {                                        #        # If we're not running in silent mode:
        $DoneLabel.Text = "Still working..."                     #        # set Done label that it is working
        $DoneLabel.Visible = $true                               #        # make the done label visible
      }                                                          #        #
    }                                                            #        # [end of the for-each loop]
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Clean up and remove CredSSP Session         #        #
    # clean up the Cred SSP Session, and remove it.              #        #
    ##############################################################        #
    Invoke-Command -Session $CSSPSESSION -ScriptBlock {          #        # On the remote computer:  
      $env:SEE_MASK_NOZONECHECKS = 0                             #        # Set the env:SMNZC variable = 0
      Set-ExecutionPolicy Restricted                             #        # Set the executionpolicy to restricted
      Remove-PSDrive -Name P                                     #        # remove the P:\ drive
    }                                                            #        # End of work on remote machine   
    Remove-PSSession $CSSPSESSION                                #        # remove the PSSession
    ##############################################################        #
                                                                          #
    ##############################################################        #
    # Documentation: Wrapping up from the installs               #        #
    # After we're done installing everything, let the user know  #        #
    # via the done label. Then remove the P:\ drive on the remote#        #
    # computer, reset the execution policy, and close the pssession       #
    ##############################################################        #
    log "Beginning clean up on Remote machine" 0                   #       ### Log, we're going to set env:smnzc
    Invoke-Command -Session $SESSION -ScriptBlock {              #        # On the remote computer:  
      Disable-WSManCredSSP Server                                #        # disable using this as a wsmancredsspserver
      $env:SEE_MASK_NOZONECHECKS = 0                             #        # Set the env:SMNZC variable = 0
      Set-ExecutionPolicy Restricted                             #        # Set the executionpolicy to restricted
      Remove-PSDrive -Name P                                     #        # remove the P:\ drive
    }                                                            #        # End of work on remote machine   
    log "Set env:smz to 0" 0                                       #       ### Log we did it    
    log "Reset ExecutionPolicy to Restricted" 0                    #       ### log, we reset the execution policy
    log "Removed P drive" 0                                        #       ### log that we removed the P:\ drive
    log "Removing session $SESSION" 0                              #       ### log that we're removing the session
    Remove-PSSession -Session $SESSION                           #        # end the remote session
    log "Removed session" 0                                        #       ### log, we ended the session
    log "Finished Cleanup on Remote Machine" 0                     #       ### log we're done with the remote machine
    log "Beginning Cleanup on Local Machine" 0                     #       ### log we're cleaning up this machine
    Disable-WSManCredSSP Client                                  #        # disable credssp client mode
    log "Finished Cleanup" 1                                       #       ### debug that we're all done cleaning up
    if (-Not $silent) {                                          #        # If were running with a GUI
      $DoneLabel.Text = "Finished Installing $global:SelectedSoftware"    # Update the Done Label
      $DoneLabel.Visible = $true                                 #        # Make the Done label visible
    }                                                            #        #
    log "Done." 2                                                  #        #
    ##############################################################        #
                                                                          #
  ################################################################        #
  # Documentation: there were no online machines                 #        #
  # Tell the user every machine they selected (usually if they   #        #
  # only selected the one machine) were/was offline.             #        #
  ################################################################        #
  } else {                                                       #        # OTHERWISE all of them were offline.
    log "All of $global:SelectedMachines were offline." 1          #       ### debug, say that they were offline
    if (-Not $silent) {                                          #        # if there's a GUI (and a done label)
      $DoneLabel.Text = "All selected machines were offline."    #        # change the text
      $DoneLabel.ForeColor = $Config.ColorScheme.Warning         #        # change the color
      $DoneLabel.Visible = $true                                 #        # make it visible
    }                                                            #        #
  }                                                              #        #
  ################################################################        #
                                                                          #
  <#NOTE: PlaySound at the end of install is slated for removal in
  Push 2.9 (Jerzy Jobs), with the ability to schedule jobs for execution
  as soon as possible, the sounds at the end of an install would be
  confusing. Which job just finished? idk, don't really care, cause Jobs.#>
  ################################################################        #
  # Documentation: play a sound to indicate that PUSH finished.  #        #
  # This little chunk plays a sound from the Media folder to     #        #
  # audibly indicate that PUSH has finished acting on the remote #        #
  # computers.                                                   #        #
  ################################################################        #
  #if (-Not $silent) {                                            #        # If we're not running in silent mode:
  #  $PlayWav=New-Object System.Media.SoundPlayer                 #        # Create a soundplayer object
  #  $Location = Get-Item (Convert-Path $Config.Package.Media + '\Windows XP Notify.wav')  # That's where the file is
  #  $PlayWav.SoundLocation = $Location                           #        # Tell it to play that^ file
  #  $PlayWav.playsync()                                          #        # play it
  #}                                                              #        #
  ################################################################        #
}                                                                         #
#log "Read through SoftwareInstall function" 0 # Debugging checkpoint      #
########################################################################### End of the SoftwareInstall function