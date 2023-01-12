$script:DoWriteLogFile = $false
$script:DoWriteConsoleOutput = $true
$script:PushLogfileLocation = ""

###########################################################################
# Documentation: log and output functions                                 #
# Since PUSH can be run in silent mode, and creates log files, it would be#
# nice to have a really easy way to output what's going on without writing#
# 15 extra lines everywhere.                                              #
# Log messages come in 3 levels, 0 (log) writes to the log file, nothing  #
# else. 1 (debug) writes to the log file, and to the output box if the -d #
# flag is included. 2 (output) writes to the log file and to the output   #
# box always, no matter what.                                             #
# if no log level is specified, it is 0 by default.                       #
###########################################################################
function log {                                                            #
  param([String]$Message,[int16]$Tlevel=0)                                # pass a message and log level and filename

  #Write-Host "Attempting to log '$Message' with level '$Tleve' to file '$lfname'"

  if ($script:DoWriteLogFile) {                                    # only if they include the $dolog -l parameter
    $time = Get-Date -Format "HH:mm:ss"                                   # get a time stamp
    Add-Content $script:PushLogfileLocation "[$time] : " -NoNewLine                           # prepend it to every line
    switch ($Tlevel) {                                                     # depending on which level we passed:
      (0) { Add-Content $script:PushLogfileLocation "Log:$Message" }                          # write to log file
      (1) { Add-Content $script:PushLogfileLocation "Debug:$Message"                          # write to file and console
            if ($script:DoWriteConsoleOutput) { Write-Host $Message }     # output to console
          }                                                               #
      (2) { Add-Content $script:PushLogfileLocation "$Message"                                # write to file and console
            if ($script:DoWriteConsoleOutput) { Write-Host $Message }     # write to console
            try { $Outputbox.AppendText("$Message`r`n") } catch {}        # 2: append to output box (if it exists)
          }                                                               #
    }                                                                     #
  } else {                                                                # if no $dolog was provided, still say things
    if ($script:DoWriteConsoleOutput) {
      switch ($Tlevel) {                                                     # depending on the level:
        (0) { Write-Host "Not logged: $Message" }                           # 0: write to console, & say it wasn't logged
        (1) { Write-Host $Message }                                         # 1: write to console
        (2) { Write-Host $Message                                           # 2: write to console &
          try { $Outputbox.AppendText("$Message`r`n") }                     # 2: append to output box
          catch {}                                                          # - if no $outputbox exist, do nothing
        }                                                                   #
      }                                                                     #
    }
    else {
      if ($Tlevel -eq 2) { try { $Outputbox.AppendText("$Message`r`n") } catch {} }
    }
  }                                                                       #
}                                                                         #
###########################################################################


function Enable-PushLogging {
  $script:DoWriteLogFile = $true
}

function Disable-PushLogging {
  $script:DoWriteLogFile = $false
}

function Enable-PushConsoleOutput {
  $script:DoWriteConsoleOutput = $true
}

function Disable-PushConsoleOutput {
  $script:DoWriteConsoleOutput = $false
}

function Set-PushLogfileLocation ([String]$LogfileLocation) {
  $script:PushLogfileLocation = $LogfileLocation
}

function Get-PushLogfileLocation {
  return $script:PushLogfileLocation
}

<#
function logRemote {
  <#lol imagine if this ever got called.
  param([String]$Message, [int16]$level = 0, [String]$Hostname)

  If (-Not (test-path "$global:lfilename-$Hostname.log")) { New-Item "$global:lfilename-$Hostname.log" }

  if ($dolog) {                                                           # only if they include the $dolog -l parameter
    $time = Get-Date -Format "HH:mm:ss"                                   # get a time stamp
    Add-Content "$global:lfilename-$Hostname.log" "[$time] : " -NoNewLine # prepend it to every line
    switch ($level) {                                                     # depending on which level we passed:
      (0) { Add-Content "$global:lfilename-$Hostname.log" "Log:$Message" }                # write to log file
      (1) { Add-Content "$global:lfilename-$Hostname.log" "Debug:$Message"                # write to file and console
            Write-Host $Message                                           # output to console
          }                                                               #
      (2) { Add-Content "$global:lfilename-$Hostname.log" "$Message"                      # write to file and console
            Write-Host $Message                                           # write to console
            $Outputbox.AppendText("$Message`r`n")                         #
          }                                                               #
    }                                                                     #
  } else {                                                                # if no $dolog was provided, still say things
    switch ($level) {                                                     # depending on the level:
      (0) { Write-Host "Not logged: $Message" }                           # 0: write to console, & say it wasn't logged
      (1) { Write-Host $Message }                                         # 1: write to console
      (2) { Write-Host $Message                                           # 2: write to console &
        try { $Outputbox.AppendText("$Message`r`n") }                     # 2: append to output box
        catch {}                                                          # - if no $outputbox exist, do nothing
      }                                                                   #
    }                                                                     #
  }                                                                       #
}                                                                         #>