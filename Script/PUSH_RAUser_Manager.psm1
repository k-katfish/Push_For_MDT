function Get-RemoteDesktopUsers {
  param(
    [String]
    [Alias("Domain")]
    $UserDomain,

    [String]
    [Alias("User")]
    $UserName,

    [String]
    $Computer
  )

  if (-Not (Test-WSMan $Computer)) {
    return (-1, "Unable to establish WinRM Session")
  }

  $RemoteUsers = (Invoke-Command -ComputerName $Computer -ScriptBlock {
    Get-LocalGroupMember 'Remote Desktop Users'
  })

  return $RemoteUsers
}

function Add-RemoteDesktopUser {
  param(
    [String]
    [Alias("Domain")]
    $UserDomain,

    [String]
    [Alias("User")]
    $UserName,

    [String]
    $Computer
  )

  if (-Not (Test-WSMan $Computer)) {
    return (-1, "Unable to establish WinRM Session")
  }

  Invoke-Command -ComputerName $Computer -ScriptBlock {
    Add-LocalGroupMember 'Remote Desktop Users' "$UserDomain\$UserName"
  }

  
}

function Get-PUSHLocalGroupInfo {
  param(
    [String]
    $ComputerName
  )

  $GroupInfo = Invoke-Command -ComputerName $Computer -ScriptBlock {
    Get-LocalGroupMember 'Remote Desktop Users'
    Get-LocalGroupMember 'Administrators'
    Get-LocalGroupMember 'Power Users'
  }
}