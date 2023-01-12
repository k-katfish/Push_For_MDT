<#
  PUSH Apps Tool Strip
  It's so they can all have the same toolstrip!

  Author: Kyle Ketchell
  Version: 1.0.1 (We're for sure more than 1.0, but I'm not sure what constitutes a new version, so let's say 1.0.1 for now)
  Creation date: 9/4/2022
#>

function Invoke-ConfigureTSItem {
  param($TSItem, $Text)
  $TSItem.Text = "&$Text"
  $TSItem.Font = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize)
  $TSItem.BackColor = $script:PushConfiguration.ColorScheme.ToolStripBackground
  $TSItem.ForeColor = $script:PushConfiguration.ColorScheme.Foreground
  $TSItem.Add_MouseEnter({ $this.ForeColor = $script:PushConfiguration.ColorScheme.ToolStripHover })
  $TSItem.Add_MouseLeave({ $this.ForeColor = $script:PushConfiguration.ColorScheme.Foreground })
}

function Get-NewTSItem {
  param($Text)
  $NewTSItem = New-Object System.Windows.Forms.ToolStripMenuItem
  Invoke-ConfigureTSItem $NewTSItem -Text $Text
  return $NewTSItem
}

function Invoke-TSManageComputer ($ManageComponent) {
  $InputForm               = New-Object System.Windows.Forms.Form #   #   # create an input form
  $InputForm.ClientSize    = New-Object System.Drawing.Size(250,125)  #   # Set the size of the form
  $InputForm.text          = "$ManageComponent"                   #   #   # The title is "Remote Computer"
  $InputForm.TopMost       = $true                                #   #   # appear on top of everything else
  $InputForm.StartPosition = 'CenterScreen'                       #   #   # appear in the center of the screen
  $InputForm.BackColor     = $script:PushConfiguration.ColorScheme.Background # Set the background color
  $InputForm.Icon          = Convert-Path($script:PushConfiguration.Design.Icon) # set the icon path
  $HostnameLabel            = New-Object System.Windows.Forms.Label   #   # make a label
  $HostnameLabel.Text       = "Enter Computer Name:"              #   #   # says that
  $HostnameLabel.height     = 23                                  #   #   # that tall
  $HostnameLabel.Width      = 150                                 #   #   # that wide
  $HostnameLabel.Location   = New-Object System.Drawing.Point(10,20)  #   # there
  $HostnameLabel.Font       = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize) # that font
  $HostnameLabel.Forecolor  = $script:PushConfiguration.ColorScheme.Foreground # that text color
  $HostnameLabel.BackColor  = $script:PushConfiguration.ColorScheme.Background # that background color
  $InputBox          = New-Object System.Windows.Forms.TextBox    #   #   # Make an input text box
  $InputBox.Height   = 23                                         #   #   # that tall
  $InputBox.Width    = 200                                        #   #   # that wide
  $InputBox.Location = New-Object System.Drawing.Point(10,50)     #   #   # there
  $InputBox.Font     = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize)# that font
  $InputBox.Text     = $ManualNameTextBox.Text                    #   #   # and auto fill the text
  $OKButton              = New-Object System.Windows.Forms.Button #   #   # Make an OK button
  $OKButton.Height       = 23                                     #   #   # that tall
  $OKButton.Width        = 50                                     #   #   # that wide 
  $OKButton.Location     = New-Object System.Drawing.Point(10,80) #   #   # there
  $OKButton.Font         = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize)# that font
  $OKButton.Text         = "GO"                                   #   #   # it says that
  $OKButton.ForeColor = $script:PushConfiguration.ColorScheme.Foreground  #
  $OKButton.Add_Click({                                           #   #   # if we click it:
    $TSManageComputerName = $InputBox.Text                        #   #   # Get the computer we should be managing
    $InputForm.Close()                                            #   #   # close the input form
    switch ($ManageComponent) {                                   #   #   # which managecomponent are we using?:
      "scan" { Start-Process powershell -ArgumentList "Powershell .\Build\Scan_Host.exe -Hostname $TSManageComputerName" -NoNewWindow }
      "explorer.exe" { Start-Process \\$TSManageComputerName\c$ } #   #   # explorer (C $hare)
      "lusrmgr.msc" { Start-Process Powershell -ArgumentList "Powershell lusrmgr.msc /computer:$TSManageComputerName" -NoNewWindow }   #   # lusrmgr
      "gpedit.msc" { Start-Process Powershell -ArgumentList "Powershell gpedit.msc /gpcomputer: $TSManageComputerName" -NoNewWindow }  #   # gpedit
      "gpupdate" { Start-Process Powershell -ArgumentList "Powershell Invoke-Command -ScriptBlock { gpupdate /force } -ComputerName $TSManageComputerName" -NoNewWindow } # update group policy
      "compmgmt.msc" { Start-Process Powershell -ArgumentList "Powershell compmgmt.msc /computer:$TSManageComputerName" -NoNewWindow } #   # compmgmt.msc
      "restart" { Restart-Computer -ComputerName $TSManageComputerName -Credential $(Get-Credential -Message "Please provide credentials to Restart this Computer." -Username "$env:USERDOMAIN\$env:USERNAME") -Force } # restart remote computer
      "shutdown" { Stop-Computer -ComputerName $TSManageComputerName -Credential $(Get-Credential -Message "Please provide credentials to Shut Down this Computer." -Username "$env:USERDOMAIN\$env:USERNAME") -Force } # shutdown remote computer
    }                                                             #   #   #
  })                                                              #   #   # end of click behavior
  $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Enter") { $OKButton.PerformClick() }}) # If we press 'enter'
  $InputBox.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})      # If we press 'escape'
  $InputForm.Add_KeyDown({ if ($PSItem.KeyCode -eq "Escape") { $InputForm.Close() }})     # if we press 'escape'
  $InputForm.Controls.AddRange(@($HostnameLabel,$InputBox,$OKButton)) #   # add the controls
  $InputForm.ShowDialog()                                         #   #   # Show the input form
}

function Invoke-TSHelpReader ($HelpOption) {                             #   #   # Create the helpreader function
  $HelpForm               = New-Object System.Windows.Forms.Form  #   #   # create the form
  $HelpForm.text          = "PUSH Help"                           #   #   # set the title of the form
  $HelpForm.AutoSize      = $true                                 #   #   # autosize it
  $HelpForm.TopMost       = $true                                 #   #   # appear on top
  $HelpForm.StartPosition = 'CenterScreen'                        #   #   # in the center of the screen
  $HelpForm.BackColor     = $script:PushConfiguration.ColorScheme.Background # with the background color
  $HelpForm.Icon          = Convert-Path($Config.Design.Icon)     #   #   # and icon
  $HelpText            = New-Object System.Windows.Forms.TextBox  #   #   # create a textbox
  $HelpText.Location   = New-Object System.Drawing.Point(0,0)     #   #   # that appears there
  $HelpText.Size       = New-Object System.Drawing.Size(700,300)  #   #   # and is that big (fills the whole window)
  $HelpText.Font       = New-Object System.Drawing.Font($script:PushConfiguration.Design.FontName, $script:PushConfiguration.Design.FontSize) # with that font
  $HelpText.ForeColor  = $script:PushConfiguration.ColorScheme.Foreground                  #   #   # that text color
  $HelpText.BackColor  = $script:PushConfiguration.ColorScheme.Background                  #   #   # and that background color
  $HelpText.ReadOnly   = $true                                    #   #   # it is read only (you cant edit it, duh)
  $HelpText.MultiLine  = $true                                    #   #   # and is multiple lines long
  $HelpText.ScrollBars = 'Vertical'                               #   #   # and has a vertical scoll bar
  Get-Content "$($script:PushConfiguration.Location.Documentation)\$HelpOption" | ForEach-Object {   #   #   # read the help file and iterate through each line
    $HelpText.AppendText("$_`r`n")                                #   #   # put the line in the text box
  }                                                               #   #   #
  $HelpForm.Controls.Add($HelpText)                               #   #   # add the textbox to the form
  $HelpForm.ShowDialog()                                          #   #   # show the form
}                                                                 #   #   #

function Get-PUSHToolStrip {
  <#
  .SYNOPSIS
    Returns a PUSH toolstrip with all the tools & bells & whistles that one could possibly want from a PUSH toolstrip
  .DESCRIPTION
    Generates a Push toolstrip with the desired configuration (and possibly application specific items) for the GUI form
  .PARAMETER Config
    A PUSH configuration object, this is necessary to get the right configuration for the toolstrip
  .PARAMETER Application
    [String] The name of the application you want the toolstrip for. In case there are extra specific things you want to have on the toolstrip for your application
  .EXAMPLE
    $ToolStrip = Get-Toolstrip -Config $Config
    $GUIForm.Controls.Add($ToolStrip)
    
    This will generate the ToolStrip object and be returned into $TS, which is then added to the GUI form and works as intended from there!
  .NOTES
    This is mostly just to clean up some of the PUSH_2.0 script, and to ensure more uniformity between the sub apps of PUSH.
  #>
  param($ConfigurationFile, $Config, [String]$Application, [Alias("dir")]$Execution_Directory)

  $script:ConfigurationFile = $ConfigurationFile
  $script:PushConfiguration = $Config

  # Generate the Tool Strip
  $ToolStrip = New-Object System.Windows.Forms.MenuStrip
  $ToolStrip.BackColor = $script:PushConfiguration.ColorScheme.ToolStripBackground
  $ToolStrip.ForeColor = $script:PushConfiguration.ColorScheme.Foreground
  log "PUSHApps Tool Strip: Generated Tool Strip." 0

  log "PUSHApps Tool Strip: Creating File Menu Item..." 0
  # Generate the File Menu
  $TSFile = Get-NewTSItem "File"
  $TSFUser = Get-NewTSItem "Launch Session Manager"
  $TSFLogoff = Get-NewTSItem "VCL Logoff Tool"
  #$NewTSFShortcut = Get-NewTSItem -Config $Config -Text "Add PUSH shortcut to desktop"

  $TSFUser.Add_Click({
    Start-Process Powershell -ArgumentList "powershell .\Build\Session_Manager.ps1 -Configure $script:ConfigurationFile -ColorScheme $($script:PushConfiguration.ColorScheme.Name) -DesignScheme $($script:PushConfiguration.Design.Name) -dir $Execution_Directory" -NoNewWindow
  })

  $TSFLogoff.Add_Click({
    & "$($PushConfiguration.Package.Build)\VCL_Logoff_Tool_application.exe"
  })

  <#  $TSFShortcut.Add_Click({                                          #   #   # add a click behavior:
      $Push_exe_path = $Conf.P.Location.P_Drive + "\PUSH_2.0.exe"     #   #   # set the path to PUSH_2.0
      if ($b) { $Push_exe_path = $Conf.P.Location.P_Drive + "\Push_2.0_BETA.exe" } # If we're in beta mode, use the Beta.exe
      $Desktop_Short = "C:\Users\$env:username\Desktop\PUSH_2.0.lnk"  #   #   # The path where the shortcut lives
      if ($b) { $Desktop_Short = "C:\Users\$env:username\Desktop\Push_2.0_BETA.lnk"} # the Beta name, if we're in beta mode
      $WScript = New-Object -ComObject ("WScript.Shell")              #   #   # make a new wscript.shell object
      $shortcut = $WScript.CreateShortcut($Desktop_Short)             #   #   # use it to create a shortcut
      $shortcut.TargetPath = $Push_exe_path                           #   #   # set the shortcut's path
      if ($b) { $shortcut.Arguments = '-b' }                          #   #   # if we're in beta mode, use the -b option
      $shortcut.Save()                                                #   #   # save the shortcut
    })                                                                #   #   #>
    
  $TSFile.DropDownItems.AddRange(@($TSFUser, $TSFLogoff))
  log "PUSHApps Tool Strip: Generated File menu item." 0
  <##############################################################################>
  log "PUSHApps Tool Strip: Creating Remote Computer menu item." 0
  $TSComputer  = Get-NewTSItem "Remote Computer"
  
  $TSCScanHost  = Get-NewTSItem "Scan Host"
  $TSCScanHost.Add_Click({ Invoke-TSManageComputer "scan" })
  
  $TSCFiles    = Get-NewTSItem "Files on C:\ Drive"
  $TSCFiles.Add_Click({ Invoke-TSManageComputer "explorer.exe" })
  
  $TSCLusr     = Get-NewTSItem "Local Users and Groups" 
  $TSCLusr.Add_Click({ Invoke-TSManageComputer "lusrmgr.msc" })
  
  $TSCGPEdit   = Get-NewTSItem "Edit Group Policy"
  $TSCGPEdit.Add_Click({ Invoke-TSManageComputer "gpedit.msc" })
  
  $TSCGPUpdate = Get-NewTSItem "Force Group Policy Update"
  $TSCGPUpdate.Add_Click({ Invoke-TSManageComputer "gpupdate" })

  $TSCGPolicy  = Get-NewTSItem "Manage Group Policy"
  $TSCGPolicy.DropDownItems.AddRange(@($TSCGPEdit,$TSCGPUpdate))

  #$TSCSessions = Get-NewTSItem "Manage User Sessions"              #   #   #  |
  #$TSCSessions.Add_Click({ Invoke-TSManageComputer "sessions" })   #   #   # do this if we click it

  $TSCManage   = Get-NewTSItem "Computer Manager"
  $TSCManage.Add_Click({ Invoke-TSManageComputer "compmgmt.msc" })

  $TSCRestart  = Get-NewTSItem "Restart Computer"
  $TSCRestart.Add_Click({ Invoke-TSManageComputer "restart" })

  $TSCShutdown = Get-NewTSItem "Shutdown Computer"
  $TSCShutdown.Add_Click({ Invoke-TSManageComputer "shutdown" }) 

  $TSComputer.DropDownItems.AddRange(@($TSCScanHost, $TSCFiles, $TSCLusr, $TSCGPolicy, <#$TSCSessions,#> $TSCManage, $TSCRestart, $TSCShutdown))
  log "PUSHapps ToolStrip: Generated Remote Computer menuitem & dropdownitems" 0
  <##############################################################################>
  log "PUSHapps ToolStrip: Creating Help menuitems..." 0
  $TSHAbout    = Get-NewTSItem "About"
  $TSHAbout.Add_Click({ Invoke-TSHelpReader "About.txt" })

  $TSHWho      = Get-NewTSItem "Who maintains PUSH?"
  $TSHWho.Add_Click({[System.Windows.Forms.MessageBox]::Show("You do! The source code is in S:\ENS\Push_2.0\Build. Suggested editor: VS Code. Use Git to checkout a copy of the code to your local computer (hint- S:\ENS\Push_2.0 is the repository) and then edit the code locally. If you like what you've done, do a git push to put the changes into the S:\ENS\Push_2.0 folder and if you really like it a lot, use git merge to merge the changes from your development branch into the master branch on the S:\ drive. Please check with the current Push people before you make any major changes though.")})

  $TSHGroups   = Get-NewTSItem "Managing PUSH Groups"
  $TSHGroups.Add_Click({ Invoke-TSHelpReader "Groups.txt" })

  $TSHSoftware = Get-NewTSItem "Adding Software to PUSH"
  $TSHSoftware.Add_Click({ Invoke-TSHelpReader "Software.txt" })

  $TSHPatches  = Get-NewTSItem "Adding Fixes to Push"
  $TSHPatches.Add_Click({ Invoke-TSHelpReader "Scripts-Patches-Fixes.txt" })

  $TSHMessages = Get-NewTSItem "Creating a PopUp message for a software"
  $TSHMessages.Add_Click({ Invoke-TSHelpReader "Messages_Install.txt" })

  $TSHRemote   = Get-NewTSItem "About Remote Computer Tools"
  $TSHRemote.Add_Click({ Invoke-TSHelpReader "Remote_Computer.txt" })

  $TSHUseCSSP  = Get-NewTSItem "What is CredSSP?"
  $TSHUseCSSP.Add_Click({ Invoke-TSHelpReader "UseCSSP.txt" })

  $TSHVersion  = Get-NewTSItem "Version"
  $TSHVersion.Add_Click({
    $Message = "Version: $($Config.About.Version)"
    if ($b) { $Message += " Beta`r`n" } else { $Message += "`r`n" }
    $Message += "Author: $($Config.About.Author)`n" +
      "Compiled on: $($Config.About.Compile_Date) "+
      "by $($Config.About.Compile_User)`n"
##    if ($PSCommandPath -ne "") { $Message += "Running script $PSCommandPath`r`n" }
    [System.Windows.Forms.MessageBox]::Show($Message)
  })

  $TSHelp = Get-NewTSItem "Help"
  $TSHelp.DropDownItems.AddRange(@($TSHAbout,$TSHWho, $TSHGroups, $TSHSoftware, $TSHPatches, $TSHMessages, $TSHRemote, $TSHUseCSSP, $TSHVersion))
  log "PUSHapps ToolStrip: Generated Help Menu and dropdown items." 0

  $ToolStrip.Items.AddRange(@($TSFile,$TSComputer, $TSHelp))
  return $ToolStrip
}

function RefreshPushToolStrip {
  param($ToolStrip, $Config, [String]$Application)

  $script:PushConfiguration = $Config

  log "PUSHApps Tool Strip: Refreshing Tool Strip..." 0
  $ToolStrip.BackColor = $script:PushConfiguration.ColorScheme.ToolStripBackground
  $ToolStrip.ForeColor = $script:PushConfiguration.ColorScheme.Foreground
  log "PUSHApps Tool Strip: Refreshed Tool Strip." 0

  <##############################################################################>


  log "PUSHApps Tool Strip: Refreshing File Items..." 0
  $ToolStripFileItem = $ToolStrip.Items.Item($ToolStrip.GetItemAt(5, 2))
  Invoke-ConfigureTSItem $ToolStripFileItem $ToolStripFileItem.Text.Substring(1)
  
  $ToolStripFileItem.DropDownItems | ForEach-Object {
    Invoke-ConfigureTSItem $_ $_.Text.Substring(1)
  }
  log "PUSHApps Tool Strip: Refreshed File Menu Item." 0

  <##############################################################################>


  log "PUSHApps Tool Strip: Refreshing Remote Computer menu item." 0
  $ToolStripRemoteItem = $ToolStrip.GetNextItem($ToolStripFileItem, 16)
  Invoke-ConfigureTSItem $ToolStripRemoteItem $ToolStripRemoteItem.Text.Substring(1)

  $ToolStripRemoteItem.DropDownItems | ForEach-Object {
    Invoke-ConfigureTSItem $_ $_.Text.Substring(1)
  }
  log "PUSHapps ToolStrip: Refreshed Remote Computer menuitem & dropdownitems" 0

  <##############################################################################>

  log "PUSHapps ToolStrip: Refreshing Help menuitems..." 0
  $ToolStripHelpItem = $ToolStrip.GetNextItem($ToolStripRemoteItem, 16)
  Invoke-ConfigureTSItem $ToolStripHelpItem $ToolStripHelpItem.Text.Substring(1)

  $ToolStripHelpItem.DropDownItems | ForEach-Object {
    Invoke-ConfigureTSItem $_ $_.Text.Substring(1)
  }
  log "PUSHapps ToolStrip: Refreshed Help Menu and dropdown items." 0
}