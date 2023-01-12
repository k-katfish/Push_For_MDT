<#
  PUSH Remote/Admin User Management
#>
param(
  [Parameter()][Alias("l")][Switch]$dolog=$false,                         # choose whether the session will output to a log
  [Parameter()][String]$logfile="",                                       # specify name of log file
  [Parameter()][Alias("h")][Switch]$help=$false,                          # print a help message and quit
  [Parameter(ParameterSetName = "Custom or No config")][Alias("dir")][String]$Execution_Directory="\\software.engr.colostate.edu\software\ENS\Push_2.0", # Where is Push executing from?
  [Parameter(ParameterSetName = "Custom or No config")][String]$Fallback_Directory="\\software.engr.colostate.edu\software\ENS\Push_2.0",
  [Parameter(ParameterSetName = "Custom or No config")][String]$Configure="\\software.engr.colostate.edu\software\ENS\Push_2.0\Configuration.xml", # You can specify no parameters!
  [Parameter(ParameterSetName = "Custom or No config")][String]$ColorScheme="Dark",                               #
  [Parameter(ParameterSetName = "Custom or No config")][String]$DesignScheme="Original",                          #
  [Parameter()][Alias("q")][Switch]$Quiet,                                # this is low key my favorite parameter to pass :)

  [Parameter()][PSCredential]$Credential,
  [Parameter(ParameterSetName = "Full Config object")]$Config
)

###########################################################################
# Documentation: Add Types                                                #
# Add the things you need in order to make gui happen.                    #
###########################################################################
Add-Type -AssemblyName System.Windows.Forms                               # Add the Forms type
Add-Type -AssemblyName System.Drawing                                     # add the drawing type
[System.Windows.Forms.Application]::EnableVisualStyles()                  # Enable us to use colors
###########################################################################

if (Get-Module PUSH_GUI_Manager) { Remove-Module PUSH_GUI_Manager }
Import-Module .\Build\PUSH_GUI_Manager.psm1

$RAForm = New-Object System.Windows.Forms.Form