function LoadConfiguration {
  if (-Not (Test-Path "$env:APPDATA\Push\")) {
    New-Item -Path "$env:APPDATA\Push\" -ItemType Directory
    New-Item -Path "$env:APPDATA\Push\Media" -ItemType Directory
  }

  if (-Not (Test-Path "$env:APPDATA\Push\config.xml")) {
    Copy-Item $PSScriptRoot\config.xml "$env:APPDATA\Push\config.xml"
  }

  $script:Config = [XML](Get-Content "$env:APPDATA\Push\config.xml")
  $script:SelectedColorScheme = $script:Config.Configuration.SelectedColorScheme.Name
  $script:SelectedDesignScheme = $script:Config.Configuration.SelectedDesignScheme.Name

  #try {
    if (-Not ($script:Config.Configuration.UseADIntegration.Preference -eq "Yes" -or $script:Config.Configuration.UseADIntegration.Preference -eq "No")) {
      $ConfigFile = Get-Content "$env:APPDATA\Push\config.xml"
      $ConfigFile[$ConfigFile.Length-2] += "`r`n" + '<UseADIntegration Preference="No" ExcludedOUs=""/>' + "`r`n"
      $ConfigFile | Set-Content -Path "$env:APPDATA\Push\config.xml"
      $script:Config = [XML](Get-Content "$env:APPDATA\Push\config.xml")
    }
  #} catch {
  #  $ConfigFile = Get-Content "$env:APPDATA\Push\config.xml"
  #  $ConfigFile[$ConfigFile.Length-2] += "`r`n" + '<UseADIntegration Preference="No" ExcludedOUs=""/>' + "`r`n"
  #  $ConfigFile | Set-Content -Path "$env:APPDATA\Push\config.xml"
  #}
}
LoadConfiguration

function Get-GroupsFolderLocation {
  return $script:Config.Configuration.GroupsFolder.Location
}

function Invoke-ChangeGroupsFolderLocation {
  if (-Not (Get-Module GUIManager)) { Import-Mode $PSScriptRoot\GUIManager.psm1 }
  #Add-Type -AssemblyName Microsoft.VisualBasic
  $GroupsFolderLocation = Get-GUIInput -Text "Where is your groups folder located?" -Title "Push"
  if (-Not (Test-Path $GroupsFolderLocation)) { New-Item $GroupsFolderLocation -ItemType Directory }
  $script:Config.Configuration.GroupsFolder.Location = $GroupsFolderLocation
  $script:Config.Save("$env:APPDATA\Push\config.xml")
}

function Get-CachedMDTShareLocation {
  return $script:Config.Configuration.DefaultMDTShare.Location
}

function Set-CachedMDTShareLocation ($ShareLocation) {
  Write-Verbose "Caching MDT Share Location of $ShareLocation to $env:APPDATA\Push\config.xml"

  $script:Config.Configuration.DefaultMDTShare.Location = $ShareLocation
  $script:Config.Save("$env:APPDATA\Push\config.xml")

  Write-Verbose "Cached MDT Share Location: $(Get-CachedMDTShareLocation)"
}

function Get-BackgroundColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.BackColor
}

function Get-ForegroundColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.ForeColor
}

function Get-ToolStripBackgroundColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.ToolStripB
}

function Get-ToolStripHoverColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.ToolStripH
}

function Get-SuccessColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.Success
}

function Get-WarningColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.Warning
}

function Get-ErrorColor {
  return $script:Config.Configuration.$script:SelectedColorScheme.Error
}

function Get-FlatStyle {
  return $script:Config.Configuration.$script:SelectedDesignScheme.FlatStyle
}

function Get-BorderStyle {
  return $script:Config.Configuration.$script:SelectedDesignScheme.BorderStyle
}

function Get-FontSettings {
  return New-Object System.Drawing.Font($script:Config.Configuration.$script:SelectedDesignScheme.FontName, $script:Config.Configuration.$script:SelectedDesignScheme.FontSize)
}

function Set-ColorScheme ($SchemeName) {
  Write-Verbose "New ColorScheme Requested: $SchemeName"
  $script:SelectedColorScheme = $SchemeName
  Write-Verbose "Caching desired color schme: $script:SelectedColorScheme to $env:APPDATA\Push\config.xml"

  $script:Config.Configuration.SelectedColorScheme.Name = $SchemeName
  $script:Config.Save("$env:APPDATA\Push\config.xml")

  Write-Verbose "Cached Color Scheme: $($script:Config.Configuration.SelectedColorScheme.Name)"
}

function Invoke-NextColorScheme {
  Write-Verbose "Next Color Scheme requested."
  $AvailableSchemes = $script:Config.Configuration.AvailableColorSchemes.Schemes.Split(",")
  $CurrentCS = $AvailableSchemes.IndexOf($script:SelectedColorScheme)
  if ($CurrentCS -eq -1) { $CurrentCS = 0}
  $NextScheme = ""
  if ($CurrentCS -eq $AvailableSchemes.Length - 1) {
    $NextScheme = $AvailableSchemes[0]
  } else {
    $NextScheme = $AvailableSchemes[$CurrentCS + 1]
  }
  
  Write-Verbose "Current Scheme: $script:SelectedColorScheme. Incrementing to $NextScheme."
  Set-ColorScheme $NextScheme
}

function Set-DesignScheme ($SchemeName) {
  Write-Verbose "New Design Scheme Requested: $SchemeName"
  $script:SelectedDesignScheme = $SchemeName
  Write-Verbose "Caching desired color schme: $script:SelectedDesignScheme to $env:APPDATA\Push\config.xml"

  $script:Config.Configuration.SelectedDesignScheme.Name = $SchemeName
  $script:Config.Save("$env:APPDATA\Push\config.xml")

  Write-Verbose "Cached Design Scheme: $($script:Config.Configuration.SelectedDesignScheme.Name)"
}

function Invoke-NextDesignScheme {
  Write-Verbose "Next Design Scheme requested."
  $AvailableSchemes = $script:Config.Configuration.AvailableDesignSchemes.Schemes.Split(",")
  $CurrentDS = $AvailableSchemes.IndexOf($script:SelectedDesignScheme)
  if ($CurrentDS -eq -1) { $CurrentDS = 0}
  $NextScheme = ""
  if ($CurrentDS -eq $AvailableSchemes.Length - 1) {
    $NextScheme = $AvailableSchemes[0]
  } else {
    $NextScheme = $AvailableSchemes[$CurrentDS + 1]
  }
  
  Write-Verbose "Current Scheme: $script:SelectedDesignScheme. Incrementing to $NextScheme."
  Set-DesignScheme $NextScheme
}

function Set-ConfigurationFile ($Configuration_File) {
  Write-Verbose "Configuration File Change Requested"
  $script:Config = [XML](Get-Content $Configuration_File)

  Write-Verbose "Caching Configuration data to $env:APPDATA\Push\config.xml"
  $script:Config.Save("$env:APPDATA\Push\config.xml")
}

function Get-ADIntegrationPreference {
  $UseADIntegrationPreference = $false

  if ($script:Config.Configuration.UseADIntegration.Preference -eq "Yes") {
    $UseADIntegrationPreference = $true
  }

  $ExcludedOUs = $script:Config.Configuration.UseADIntegration.ExcludedOUs.Split(',')

  return ([PSCustomObject]@{
    UseIntegration = $UseADIntegrationPreference
    ExcludedOUs = $ExcludedOUs
  })
}

function Set-ADIntegrationPreference {
  param(
    $UseADIntegration,
    $ExcludedOUs
  )

  if ($UseADIntegration -eq $true) {
    $script:Config.Configuration.UseADIntegration.Preference = "Yes"
  } else {
    $script:Config.Configuration.UseADIntegration.Preference = "No"
  }

  $ExcludedOUsString = ""

  $ExcludedOUs | ForEach-Object {
    $ExcludedOUsString += "$_,"
  }

  $script:Config.Configuration.UseADIntegration.ExcludedOUs = $ExcludedOUsString
  $script:Config.Save("$env:APPDATA\Push\config.xml")
}