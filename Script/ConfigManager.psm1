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
}
LoadConfiguration

function Get-GroupsFolderLocation {
  return $script:Config.Configuration.GroupsFolder.Location
}

function Get-CachedMDTShareLocation {
  return $script:Config.Configuration.DefaultMDTShare.Location
}

function Set-CachedMDTShareLocation ($ShareLocation) {
  Write-Verbose "Caching MDT Share Location of $ShareLocation to $env:APPDATA\Push\config.xml"
  #$EditConfig = New-Object xml
  #$EditConfig.Load("$env:APPDATA\Push\config.xml")
  #$EditConfig.Configuration.DefaultMDTShare.Location = $ShareLocation
  #$EditConfig.Save("$env:APPDATA\Push\config.xml")

  $script:Config.Configuration.DefaultMDTShare.Location = $ShareLocation
  $script:Config.Save("$env:APPDATA\Push\config.xml")

  #LoadConfiguration
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
  $script:SelectedColorScheme = $SchemeName
}

function Set-DesignSecheme ($SchemeName) {
  $script:SelectedDesignScheme = $SchemeName
}

function Set-ConfigurationFile ($Configuration_File) {
  $script:Config = [XML](Get-Content $Configuration_File)
}