$script:Config = [XML](Get-Content $PSScriptRoot\config.xml)
$script:SelectedColorScheme = "Dark"
$script:SelectedDesignScheme = "Classic"

#function Get-GroupsFolderLocation {
#  if ($script:Config.Configuration.GroupsFolderLocation.isUNC -like "*true*") { return $script:Config.Configuration.GroupsFolderLocation.Location }
#  else { return $script:Config.Configuration.GroupsFolderLocation.Location }
#}

#function Get-SoftwareFolderLocation {
#  return $script:Config.Configuration.SoftwareFolderLocation.Location
#}

function Get-ConnectedMDTShareLocation {
  return $script:ConnectedMDTShareLocation
}

function Set-ConnectedMDTShareLocation ($ShareLocation) {
  $script:ConnectedMDTShareLocation = $ShareLocation
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