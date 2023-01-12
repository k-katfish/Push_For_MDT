#Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
#
#Set-PSRepository PSGallery -InstallationPolicy Trusted
#Install-Module QuserObject -Scope CurrentUser
Import-Module $PSScriptRoot\QUser_Helper.psm1

function Find-UserInDomain {
  param ([String]$ADSearchString, [String]$Username)
  
  if ($ADSearchString -eq "") {
    Write-Host "Please provide an AD Search String."
    return -1
  }

  $AllSessions = Get-ADComputer -Filter * -SearchBase $ADSearchString | Get-Quser
  $AllSessions | ForEach-Object {
    if ($_.UserName -eq $Username) {
      return $_
    }
  }
  return "No user found."
}

function Find-UsersOnHost {
  param ([String]$Hostname=$env:COMPUTERNAME)
  return Get-Quser -ServerName $Hostname
}

function Find-UsersInGroup {
  param([String]$GroupFileName, [String]$Username = "")

  $Computers = Get-Content $GroupFileName
  $ComputerList = New-Object System.Collections.ArrayList
  $Computers | ForEach-Object {
    $ComputerList.Add($_) | Out-Null
  }

  if ($Username -eq "") {
    return $ComputerList | Get-Quser
  } else {
    return $ComputerList | Get-Quser | Where-Object { $_.UserName -eq $Username }
  }
}

filter Invoke-EndUserSession {
  try { logoff "$($_.Id)" /server:"$($_.Server)" } catch { if ($_ -like "*is not recognized*") { Set-Alias -Name logoff -Value C:\Windows\Sysnative\logoff.exe }} 
  try { logoff "$($_.Id)" /server:"$($_.Server)" } catch {}
}

#function Invoke-EndUserSession {
#  param($QuserObject = "")
#  if ($QuserObject -eq "") {
#   logoff "$($_.SessionName)" /server:"$($_.Server)"
#  } else {
#    logoff "$($QuserObject.ID)" /server:"$($QuserObject.Server)"
#  }
#}

filter Invoke-ShadowUserSession {
  param([Switch]$control, [Switch]$admin, [Switch]$prompt, [Switch]$noconsentprompt, [Switch]$Force)

  Write-Host "Control: $control"
  Write-Host "Admin:   $admin"
  Write-Host "Prompt:  $prompt"
  Write-Host "ncp:     $noconsentprompt"
  Write-Host "Force:   $Force"

  $Server = $_.Server
  $ID = $_.Id

  if ($Force) {                                                          # If we set the noconsent flag
    Invoke-Command -ScriptBlock {                                                 # Run this scriptblock
      $RPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'   # <-- This is the path
      $RKey = 'Shadow'                                                            # <-- This is the name
      Set-ItemProperty -Path $RPath -Name $Rkey -Value 2 -Force                   # <-- Change $Rkey at $Rpath
    } -ComputerName $Server                                             # run it on $global:Hostname
  }                                                                               #

  switch ($control) {
    $true { switch ($noconsentprompt) {
     $true { switch ($prompt){
      $true { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /control /noconsentprompt /prompt /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /control /noconsentprompt /prompt }}} 
      $false { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /control /noconsentprompt /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /control /noconsentprompt }}}}}
     $false { switch ($prompt) {
      $true { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /control /prompt /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /control /prompt }}}
      $false { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /control /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /control }}}}}}}
    $false { switch ($noconsentprompt) {
     $true { switch ($prompt){
      $true { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /noconsentprompt /prompt /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /noconsentprompt /prompt }}} 
      $false { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /noconsentprompt /restrictedAdmin}
       $false { mstsc.exe /v:$Server /shadow:$ID /noconsentprompt }}}}}
     $false { switch ($prompt) {
      $true { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /prompt /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID /prompt }}}
      $false { switch ($admin) {
       $true  { mstsc.exe /v:$Server /shadow:$ID /restrictedAdmin }
       $false { mstsc.exe /v:$Server /shadow:$ID }}}}}}}}
}

#######################################################################################
# Ref:                                                                                #
# Useful things:                                                                      #
# https://www.ipswitch.com/blog/how-to-log-off-windows-users-remotely-with-powershell #
# https://theitbros.com/powershell-gui-for-scripts/                                   #
# https://www.powershellgallery.com/packages/ps2exe/1.0.11                            #
# https://www.educba.com/powershell-add-to-array/                                     #
# http://microsoftplatform.blogspot.com/2013/07/detailed-walkthrough-on-remote-control.html
#                                                                                     #
# Slightly more obscure but maybe still useful:                                       #
# https://stackoverflow.com/questions/53956926/delete-selected-items-from-list-box-in-powershell
# https://stackoverflow.com/questions/47045277/how-do-i-capture-the-selected-value-from-a-listbox-in-powershell
# https://social.technet.microsoft.com/Forums/en-US/48391387-5801-4c9e-a567-bf57aac61ddf/powershell-scripts-check-which-computers-are-turned-on
# https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-if?view=powershell-7.2
# https://dannyda.com/2021/03/13/how-to-fix-shadow-error-the-group-policy-setting-is-configured-to-require-the-users-consent-verify-the-configuration-of-the-policy-setting-on-microsoft-windows-server-2019-remote-desktop-shadow/
#                                                                                     #
# just so its 600 lines long :)                                                       #
#######################################################################################>