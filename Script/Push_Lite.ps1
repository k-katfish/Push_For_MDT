<#
.SYNOPSIS
  Push Lite is the stripped down, no-gui, no-nonsense, cli-only version of Push.
.DESCRIPTION
  You need to specify a computer name and one or more softwares, and Push_lite will create a PUSH session and add those, but without any of the GUI stuff that normally happens.
.PARAMETER d
  Optional, runs push in debug mode (extra stuff output to console and to the outputbox if using GUI)
.PARAMETER logfile
  Optional, the name of the log file.
.INPUTS
  nothing
.OUTPUTS
  A log file, optionally (enabled by default). You can disable the log file if you're running push in silent mode.
.NOTES
  Version:          2.0.8
  Authors:          Kyle Ketchell
  Version Creation: August 29, 2022
  Orginal Creation: May 29, 2022
.EXAMPLE
  push_2.0
.EXAMPLE
  push_lite -d -logfile C:\Users\your_username\Documents\Push_log.log -ComputerName ComputerName -SoftwareTitle SoftwareTitle -Execution_Directory C:\Users\your_username\Push_2.0 -Configure C:\Users\your_username\Push_2.0\Configuration.xml
  Silently install "SoftwareTitle" on "ComputerName"
  The title of the software must match EXACTLY the name of the software's folder in the Push\Software directory
#>
#[CmdletBinding()]
param(                                                                    # Parameters Ref: Microsoft, Parameters
  [Parameter(ParameterSetName = "GUI")][Switch]$d=$false,                 # d (debug)
  [Parameter()][String]$ComputerName,
  [Parameter()][String]$SoftwareTitle,
  [Parameter()][Switch]$dolog,
  [Parameter()][String]$logfile="",                                       # specify name of log file
  [Parameter()][Alias("h")][Switch]$help=$false,                          # print a help message and quit
  [Parameter()][Alias("dir")][String]$Execution_Directory="\\software.engr.colostate.edu\software\ENS\Push_2.0", # Where is Push executing from?
  [Parameter()][String]$Configure="\\software.engr.colostate.edu\software\ENS\Push_2.0\Configuration.xml", # You can specify no parameters!
  [Parameter()][PSCredential]$Credential,
  [Parameter()][Switch]$UseCSSPAuth,
  [Parameter()][Switch][Alias("q")]$SupressOutput
)                                                                         #

if (-Not $Credential) {
  $CredMessage = "Push_Lite: Please provide valid credentials."             # Message to display
  $user = "$env:UserDomain\$env:USERNAME"                                   # Default username
  $global:Creds = Get-Credential -Message $CredMessage -UserName $user      # Ref Get-Credential
                                                                          #
} else { $global:Creds = $Credential }

try {                                                                     # Test the credentials!
  Start-Process Powershell -ArgumentList "Start-Sleep",0 -Credential $Creds -WorkingDirectory 'C:\Windows\System32' -NoNewWindow
  Powershell -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope CurrentUser"
} catch {                                                                 # If we were unable to start ^ process
  if ($_ -like "*password*") {                                            # the system will complain, bad password
    Write-Host "Please provide a valid username or password"; exit        # and quit
  } elseif ($_ -like "*is not null or empty*") {                          # If we didn't provide any password
    Write-Host "Please provide a valid username or password"; exit        # and quit
  } else {                                                                # if it wasn't a password issue
    throw $_                                                              # throw it up, this will quit the program
  }                                                                       #
}                                                                         #
###########################################################################

###########################################################################
# Documentation: Initialize Push                                          #
# Push needs a few helper modules and such to get imported, this imports  #
# those and gets everything set up to run.                                #
###########################################################################
# Step 1: Make our lives way easier and just move over to the right place #
Set-Location $Execution_Directory                                         # Move us to the location specified by the $Exectuion_Directory variable
if ($d) { Write-Host "Current Location: $((Get-Location).Path)" }         # if we're debugging, say where we are rn


if (Get-Module Push_Config_Manager) { Remove-Module Push_Config_Manager } # Remove the Configuration Manager (if imported)
Import-Module .\Build\Push_Config_Manager.psm1                            # Import the Configuration manager
$Config = Get-PUSH_Configuration $Configure -Application "PUSH" 

if (Get-Module Install_Software) { Remove-Module Install_Software }       # Remove the software install module (if imported)
Import-Module .\Build\Install_Software.psm1                               # Import the Software installer module
                                                                          #
if (Get-Module Push_Logger) { Remove-Module Push_Logger }                 # Remove the logger module (if imported)
Import-Module .\Build\Push_Logger.psm1                                    #

if ($dolog) {
  Enable-PushLogging
}

if ($SupressOutput) {
  Disable-PushConsoleOutput
}

########################################################################  #
# Documentation: Create a log file                                     #  #
# Just for the sake of making sure we know what happened, PUSH creates #  #
# log files of stuff that happened. Things get added to this file via  #  #
# the log function. The file is created here.                          #  #
########################################################################  #
if ($dolog){                                                           #  # only if the $dolog -l parameter is included
  if ($logfile -ne "") { $global:lfilename = $logfile }                #  # if we specified a name for logfile, set it, otherwise:
  else { if ($d) { $global:lfilename = $Config.Package.Logs+"\"+(Get-Date -Format "MM.dd.yyyy-HH.mm")+"-d.log"}  # the special debug name
        else { $global:lfilename = $Config.Package.Logs+"\"+(Get-Date -Format "MM.dd.yyyy-HH.mm")+".log" } } # the name of the logfile
  Write-Host "Trying logfile $global:lfilename"                        #  # Write that we're trying to use that logfile
                                                                       #  #
  try {                                                                #  # try this:
    If (-Not (test-path $global:lfilename)) { New-Item $global:lfilename }# Make a new file if there isn't one
  }   catch {                                                          #  # if it failed:
    $global:lfilename = "C:\Users\$ENV:USERNAME\Push_log_$(Get-Date -Format "MM.dd.yyyy-HH.mm")" # try another name
  }                                                                    #  # 
                                                                       #  #
  $global:lfilename = Convert-Path ($global:lfilename)                 #  # get the file as an object
}                                                                      #  #
########################################################################  #

Set-PushLogfileLocation $global:lfilename
                                                                          #
# Step 3: TODO: Trust engr_dom on this computer                           #
###########################################################################

###########################################################################
# Documentation: Global Variables                                         #
# These are variables that everything should be able to access            #
###########################################################################
$global:GroupsFolderLocation = $Config.Package.Groups                     # the location of the Groups folder
$global:SoftwareFolderLocation = $Config.Package.Software                 # the location of the software folder
$global:SelectedMachines                                                  # the machines we'll be operating on
$global:SelectedSoftware                                                  # the software we want to install
$global:UseCredSSP = $UseCSSPAuth                                         # whether we're using CredSSP or not
$global:Fixes = $false                                                    # if we're looking for Fixes
$global:Softwares = $true                                                 # if we're looking for software
if ($CredSSP) { $global:UseCredSSP = $true }                              #
if (-Not $d) { $ErrorActionPreference = 'SilentlyContinue' }              # Set the erroractionpreference (don't throw a bunch of error messages that a user won't understand)
                                                                          #
###########################################################################

#if ($UseCredSSP) { CSSPSoftwareInstall $global:SelectedMachines $global:SelectedSoftware } else { softwareinstall $global:SelectedMachines $global:SelectedSoftware }   #   # call the softwareinstall function
Invoke-Install -Machines $ComputerName -Installers $SoftwareTitle -UseCredSSP $global:UseCredSSP -Credential $global:Creds -Config $Config

#######################################################################   #
# Documentation: Dump some information about this instance to a log   #   #
# It can be helpful to have information about this current instance in#   #
# a log file, so this gets a bunch of information about this computer #   #
# and throws it to a log file.                                        #   #
#######################################################################   #
log "===========================================" 0                   #   #
log "PUSH_LITE!!!!" 0                                                 #   #
log "Version: $($Config.About.Version)" 0                             #   # log the version
log "Beta: $b" 0                                                      #   # log if we're running in beta mode
log "DEBUG: $d" 0                                                     #   # log if we're running in debug mode
log "Running on: $env:COMPUTERNAME" 0                                 #   # log the computer we're running on
log "by user: $env:USERNAME"                                          #   # log the username
log "with authentication as $($Creds.Username)"                       #   # log the user we're using to connect to other computers
log "-------------------------------------------" 0                   #   #
log "Package: $($Config.Package.Location)"                            #   #
log "===========================================" 0                   #   #
#######################################################################   #

###########################################################################
# Exit behavior                                                           #
###########################################################################
#Remove-PSDrive (Get-PSDrive -Name P)                                     #
###########################################################################