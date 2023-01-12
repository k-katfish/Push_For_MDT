function ConvertTo-QuserObject {
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param(
        [Parameter(
            ValueFromPipeline = $true,
            Mandatory = $true
        )]
        [hashtable]
        $QuserOutput
    )

    begin {
        Write-Debug "[QuserObject ConvertTo-QuserObject] Begin Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject ConvertTo-QuserObject] Begin Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"
    }

    process {
        Write-Debug "[QuserObject ConvertTo-QuserObject] Process Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject ConvertTo-QuserObject] Process Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"

        Write-Debug "[QuserObject ConvertTo-QuserObject] Culture ($(Get-Culture)) DateTime Format: $((Get-Culture).DateTimeFormat.ShortDatePattern)"
        if ((Get-Culture).Parent.Name -eq 'es') {
            Write-Debug "[QuserObject ConvertTo-QuserObject] Culture Adjustments: ${script:Culture}"
            $QuserOutput.Result[0] = $QuserOutput.Result[0].Replace('.', ' ')
        }

        Write-Debug "[QuserObject ConvertTo-QuserObject] QuserOutput.Result:`n$($QuserOutput.Result | Out-String)"
        
        $quserRows = $QuserOutput.Result
        $headerRow = $quserRows[0]
        Write-Debug "[QuserObject ConvertTo-QuserObject] Header:`n$($headerRow | Out-String)"
        
        $match = [regex]::Match($headerRow, '(\s{2,})')
        $usernameSize = @(
            0,
            ($match.Index + $match.Length)
        )
        Write-Debug "[QuserObject ConvertTo-QuserObject] UserName Size: ${usernameSize}"
        
        foreach ($row in $quserRows[1..$quserRows.GetUpperBound(0)]) {
            Write-Debug "[QuserObject ConvertTo-QuserObject] Process Row [$($row.GetType())]: ${row}"
            
            $rowUserName = $row.Substring($usernameSize[0], $usernameSize[1])
            Write-Debug "[QuserObject ConvertTo-QuserObject] Row UserName: $rowUserName"
            
            $restOfRow = $row.Substring($usernameSize[1]).Trim()
            Write-Debug "[QuserObject ConvertTo-QuserObject] Rest of Row [$($row.GetType())]: ${restOfRow}"

            [Collections.ArrayList] $rowSplit = $restOfRow -split '\s{2,}'
            Write-Debug "[QuserObject ConvertTo-QuserObject] Process RowSplit [$($rowSplit.GetType())]:`n$($rowSplit | Out-String)"


            if ($rowSplit.Count -eq 4) {
                # SessionName appears to be blank
                $rowSplit.Insert(0, '')
                Write-Debug "[QuserObject ConvertTo-QuserObject] Process RowSplit FIXED [$($rowSplit.GetType())]:`n$($rowSplit | Out-String)"
            }
            
            $getQuserIdleTime = @{
                QuserIdleTime = $rowSplit[3]
                AsDateTime    = $script:IdleStartTime
            }
            Write-Debug "[QuserObject ConvertTo-QuserObject] QuserIdleTime Splat:`n$($getQuserIdleTime | Out-String)"
            
            $quser = @{
                IsCurrentSession = $rowUserName.StartsWith('>')
                UserName = $rowUserName.TrimStart('>').Trim()
                SessionName = $rowSplit[0]
                Id = $rowSplit[1] -as [int]
                State = $rowSplit[2]
                IdleTime = (Get-QuserIdleTime @getQuserIdleTime)
                LogonTime = (Get-Date $rowSplit[4])
                Server = $QuserOutput.Server
            }
            Write-Debug "[QuserObject ConvertTo-QuserObject] Row Parsed:`n$($quser | Out-String)"
            
            $quserObject = New-Object PSObject -Property $quser
            Write-Debug "[QuserObject ConvertTo-QuserObject] QuserObject:`n$($quserObject | Out-String)"
            
            $quserObject.PSTypeNames.Insert(0, 'QuserObject')
            Write-Debug "[QuserObject ConvertTo-QuserObject] QuserObject Types:`n$($quserObject.PSTypeNames | Out-String)"

            Write-Output $quserObject
        }
    }
}

function Get-QuserIdleTime {
    [CmdletBinding()]
    [OutputType([timespan])]
    [OutputType([datetime])]
    [OutputType([void])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $QuserIdleTime,

        [Parameter()]
        [switch]
        $AsDateTime
    )

    $QuserIdleTime = $QuserIdleTime.Replace('+', '.')

    if ($QuserIdleTime -as [int]) {
        $QuserIdleTime = "0:${QuserIdleTime}"
    }

    if ($QuserIdleTime -as [timespan]) {
        [timespan] $idleTime = $QuserIdleTime

        if ($AsDateTime.IsPresent) {
            $now = Get-Date
            return $now.Subtract($idleTime)
        } else {
            return $idleTime
        }
    } else {
        return $null
    }
}

function Invoke-Quser {
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(ValueFromPipeline)]
        [string]
        $Server,

        [string]
        $UserOrSession = ''
    )

    begin {
        Write-Debug "[QuserObject Invoke-Quser] Begin Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject Invoke-Quser] Begin Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"
    }

    process {
        Write-Debug "[QuserObject Invoke-Quser] Process Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject Invoke-Quser] Process Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"

        if ($Server -eq 'localhost') {
            $cmd = '{0}{1}'
        } else {
            $cmd = '{0} {1} /SERVER:{2}'
        }

        try {
            $quserPath = (Get-Command 'quser.exe' -ErrorAction 'Stop').Path
        } catch {
            $quserPath = (Get-Command "$env:SystemRoot\SysNative\quser.exe" -ErrorAction 'Stop').Path
        }

        $quser = $cmd -f $quserPath, $UserOrSession, $Server
        Write-Debug "[QuserObject Invoke-Quser] QUSER Command: ${quser}"

        try {
            $result = (Invoke-Expression $quser) 2>&1
        } catch {
            $result = $Error[0].Exception.Message
        }
        Write-Verbose "[QuserObject Invoke-Quser] QUSER Result (ExitCode: ${LASTEXITCODE}):`n$($result | Out-String)"

        if ($LASTEXITCODE -eq 0) {
            Write-Output @{
                Server = $Server
                Result = $result
            }
        #} else {
        #    #$message = if ($result.Exception) { $result.Exception.Message } else { $result }
        #    #Write-Warning " ${Server}: $($message -join ', ')"
        }
    }
}

function Get-Quser {
    [CmdletBinding(DefaultParameterSetName = 'Server')]
    [OutputType([PSObject])]
    [Alias('Get-LoggedOnUsers')]
    Param(
        [Parameter(
            ParameterSetName = 'Server',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('__ServerName', 'ServerName', 'Computer', 'Name')]
        [string[]]
        $Server = 'localhost',

        [Parameter(ParameterSetName = 'Server')]
        [Parameter(ParameterSetName = 'AdComputer')]
        [switch]
        $IdleStartTime,

        [Alias('UserName', 'SessionName', 'SessionId')]
        [string]
        $UserOrSession = '',

        [Parameter(
            ParameterSetName = 'AdComputer',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [PSObject]
        $AdComputer,

        [Parameter(ParameterSetName = 'AdComputer')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Property = 'Name'
    )

    begin {
        Write-Debug "[QuserObject Get-Quser] Begin Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject Get-Quser] Begin Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"

        [boolean] $script:IdleStartTime = $IdleStartTime.IsPresent
    }

    process {
        Write-Debug "[QuserObject Get-Quser] Process Bound Parameters: $($MyInvocation.BoundParameters | ConvertTo-Json)"
        Write-Debug "[QuserObject Get-Quser] Process Unbound Parameters: $($MyInvocation.UnboundParameters | ConvertTo-Json)"

        if ($AdComputer) {
            Write-Output ($AdComputer.$Property | Invoke-Quser -UserOrSession $UserOrSession | ConvertTo-QuserObject)
        } else {
            Write-Output ($Server | Invoke-Quser -UserOrSession $UserOrSession | ConvertTo-QuserObject)
        }
    }
}