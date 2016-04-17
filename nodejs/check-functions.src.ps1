<#
.SYNOPSIS
Determine whether an object is null.
.DESCRIPTION
Given an object, determine whether it is null. If a string, an empty
string is considered null. If a database query result DBNull is considered
null.
.PARAMETER ObjectToCheck
An object ot be tested whether it is null.
.INPUTS
System.Object. An object to be tested whether it is null.
.OUTPUTS
System.Boolean. True if the object is considered null; otherwise, False.
#>
Function Is-Null {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            Position=0)]
        # See http://stackoverflow.com/a/6409122 for AllowEmptyString() tip
        [AllowEmptyString()]
        $ObjectToCheck
    )
    # Logic from this web page:
    # https://www.codykonior.com/2013/10/17/checking-for-null-in-powershell/
    #
    If (!$ObjectToCheck) {
        return $true
    }

    If ($ObjectToCheck -is [String] -and $ObjectToCheck -eq [String]::Empty) {
        return $true
    }

    $t = [System.Management.Automation.Language.NullString]
    if ($ObjectToCheck -is [DBNull] -or $ObjectToCheck -is $t) {
        return $true
    }

    return $false
}

<#
.SYNOPSIS
Extract the version from a string.
.DESCRIPTION
Given a string, this function identifies the first version substring
in the string and returns an object containing the major, minor, patch,
and qualifier tokens.
.PARAMETER Version
A string containing a version number.
.INPUTS
System.String. A string containing a version number.
.OUTPUTS
System.Management.Automation.PSCustomObject. Properties are Major (int),
Minor (int), Patch (int), and Qualifier (string).
#>
Function Extract-Version {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0)]
        # See http://stackoverflow.com/a/6409122 for AllowEmptyString() tip
        [AllowEmptyString()]
        [string]$Version
    )
    # Initialize the result
    #
    $props = @{
        Major = 0
        Minor = 0
        Patch = 0
        Qualifier = ""
    }
    $vsn = New-Object -TypeName PSObject -Property $props

    # If $Version is empty or null, just get out
    #
    If (Is-Null $Version) {
        return $vsn
    }

    # Strip any leading substring from the version string (e.g., for
    # "wat 0.4.0" strip the leading "wat "). Also strip any trailing
    # substring (e.g., for "wat 0.4.0 (C:\Program Files\Wat040\bin\wat.exe)"
    # strip the trailing " (C:...)".
    #
    $vsnString = $Version
    $leadTokenRegex = [regex] "^(?:[^0-9(v]|\([^0-9])\S*\s+(.+)$"
    $vsnMatch = $leadTokenRegex.Match($vsnString)
    If ($vsnMatch.Success) {
        $vsnString = $vsnMatch.Groups[1].Value;
    }
    $trailingTokenRegex = [regex] "^((?:\d|\(\d|v\d)\S*)\s?.*$"
    $vsnMatch = $trailingTokenRegex.Match($vsnString)
    If ($vsnMatch.Success) {
        $vsnString = $vsnMatch.Groups[1].Value;
    }
    $stripParensRegex = [regex] "^\(?([^()]+)\)?$"
    $vsnMatch = $stripParensRegex.Match($vsnString)
    If ($vsnMatch.Success) {
        $vsnString = $vsnMatch.Groups[1].Value;
    }
    $stripLeadingVRegex = [regex] "^v([^v]+)$"
    $vsnMatch = $stripLeadingVRegex.Match($vsnString)
    If ($vsnMatch.Success) {
        $vsnString = $vsnMatch.Groups[1].Value;
    }

    # If stripped version string is null or empty, just get out
    #
    If (Is-Null $vsnString) {
        return $vsn
    }

    # Split the version string into tokens
    #
    $parts = $vsnString -split "\."
    $partsLen = $parts.Length

    # Map the tokens to version object Properties
    #
    $numRegex = [regex] "^\d+$"
    $mixedRegex = [regex] "^(\d+)[.-]?(\D.*)$"
    $qualRegex = [regex] "^[.-]?(\D.*)$"
    If (4 -le $partsLen) {
        # assuming 9.9.9.9
        If ($numRegex.Match($parts[0]).Success) {
            $vsn.Major = [int] $parts[0]
            If ($numRegex.Match($parts[1]).Success) {
                $vsn.Minor = [int] $parts[1]
                If ($numRegex.Match($parts[2]).Success) {
                    $vsn.Patch = [int] $parts[2]
                    If ($numRegex.Match($parts[3]).Success) {
                        $vsn.Qualifier = $parts[3]
                    } Else {
                        $m = $qualRegex.Match($parts[3])
                        if ($m.Success) {
                            $vsn.Qualifier = $m.Groups[1].Value
                        }
                    }
                }
            }
        }
    } ElseIf (3 -eq $partsLen) {
        # either 9.9.9 or 9.9.9ab
        If ($numRegex.Match($parts[0]).Success) {
            $vsn.Major = [int] $parts[0]
            If ($numRegex.Match($parts[1]).Success) {
                $vsn.Minor = [int] $parts[1]
                If ($numRegex.Match($parts[2]).Success) {
                    $vsn.Patch = [int] $parts[2]
                } Else {
                    $m = $mixedRegex.Match($parts[2])
                    If ($m.Success) {
                        $vsn.Patch = [int] $m.Groups[1].Value
                        $vsn.Qualifier = $m.Groups[2].Value
                    } else {
                        $m = $qualRegex.Match($parts[2])
                        If ($m.Success) {
                            $vsn.Qualifier = $m.Groups[1].Value
                        }
                    }
                }
            }
        }
    } ElseIf (2 -eq $partsLen) {
        # either 9.9 or 9.9ab
        If ($numRegex.Match($parts[0]).Success) {
            $vsn.Major = [int] $parts[0]
            If ($numRegex.Match($parts[1]).Success) {
                $vsn.Minor = [int] $parts[1]
            } Else {
                $m = $mixedRegex.Match($parts[1])
                If ($m.Success) {
                    $vsn.Minor = [int] $m.Groups[1].Value
                    $vsn.Qualifier = $m.Groups[2].Value
                } else {
                    $m = $qualRegex.Match($parts[1])
                    If ($m.Success) {
                        $vsn.Qualifier = $m.Groups[1].Value
                    }
                }
            }
        }
    } ElseIf (1 -eq $partsLen) {
        # either 9 or 9ab
        If ($numRegex.Match($parts[0]).Success) {
            $vsn.Major = [int] $parts[0]
        } Else {
            $m = $mixedRegex.Match($parts[0])
            If ($m.Success) {
                $vsn.Major = [int] $m.Groups[1].Value
                $vsn.Qualifier = $m.Groups[2].Value
            }
        }
    }
  return $vsn
}

<#
.SYNOPSIS
Compare version numbers
.DESCRIPTION
Checks whether a version string or object is at least some version
or less than some other version.
.PARAMETER Version
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function).
.PARAMETER IsAtLeast
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function). Used to test whether
Version parameter is equal to or greater than the IsAtLeast parameter.
.PARAMETER IsLessThan
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function). Used to test whether
Version parameter is less than the IsLessThan parameter.
.INPUTS
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function).
.OUTPUTS
System.Boolean. $true if the conditions are met; otherwise $false.
#>
Function Test-Version {
    [CmdletBinding()]
    param(
        [Parameter(
            ParameterSetName="atleast",
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0)]
        [Parameter(
            ParameterSetName="lessthan",
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0)]
        [PSObject]$Version,

        [Parameter(ParameterSetName="atleast")]
        [PSObject]$IsAtLeast,

        [Parameter(ParameterSetName="lessthan")]
        [PSObject]$IsLessThan
    )
    If ($PSCmdlet.ParameterSetName -eq "atleast") {
        If ($Version.Major -gt $IsAtLeast.Major) {
            return $true
        }
        If ($Version.Major -eq $IsAtLeast.Major) {
            If ($Version.Minor -gt $IsAtLeast.Minor) {
                return $true
            }
            If ($Version.Minor -eq $IsAtLeast.Minor) {
                If ($Version.Patch -gt $IsAtLeast.Patch) {
                    return $true
                }
                If ($Version.Patch -eq $IsAtLeast.Patch) {
                    If ($Version.Qualifier -gt $IsAtLeast.Qualifier) {
                        return $true
                    }
                    If ($Version.Qualifier -eq $IsAtLeast.Qualifier) {
                        return $true
                    }
                }
            }
        }
        return $false
    }
    If ($PSCmdlet.ParameterSetName -eq "lessthan") {
        If ($version.Major -lt $IsLessThan.Major) {
            return $true
        }
        If ($Version.Major -eq $IsLessThan.Major) {
            If ($Version.Minor -lt $IsLessThan.Minor) {
                return $true
            }
            If ($Version.Minor -eq $IsLessThan.Minor) {
                If ($Version.Patch -lt $IsLessThan.Patch) {
                    return $true
                }
                If ($Version.Patch -eq $IsLessThan.Patch) {
                    If ($Version.Qualifier -lt $IsLessThan.Qualifier) {
                        return $true
                    }
                }
            }
        }
        return $false
    }
    return $false
}


<#
.SYNOPSIS
Check whether a npm package is installed and within a given version range
.DESCRIPTION
Checks whether the npm package is installed and, optionally, if its version
meets or exceeds IsAtLeast and/or is less than IsLessThan.
.PARAMETER Name
The gem name.
.PARAMETER NpmList
The list of packages obtained from the 'npm list' command. Supply this to
avoid multiple calls to 'npm list' (which can be slow) via multiple
invocations of this function.
.PARAMETER IsAtLeast
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function). Used to test whether
Version parameter is equal to or greater than the IsAtLeast parameter.
.PARAMETER IsLessThan
System.String or an object containing Major, Minor, Patch, and Qualifier
members (as produced by the Extract-Version function). Used to test whether
Version parameter is less than the IsLessThan parameter.
.INPUTS
The npm package name.
.OUTPUTS
System.Boolean. $true if the package is installed and meets the version
constraints (if any); otherwise $false.
#>
Function Is-NodePkgInstalled {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0)]
        [string]$Name,

        [System.Collections.ArrayList]$NpmList,

        [PSObject]$IsAtLeast,

        [PSObject]$IsLessThan
    )
    $pkgs = $NpmList
    $pkgLine = ""
    If (Is-Null $NpmList) {
        $rcmd = "npm"
        $rargs = "list" -split " "
        [System.Collections.ArrayList]$gems = Invoke-Expression "$rcmd $rargs"
    }
    # Check whether gem installed
    #
    # $installed = $pkgs -match "^$Name \(" -as [boolean]
    $installed = $false
    foreach ($pkg in $pkgs) {
        $installed = $pkg -match " $Name@" -as [boolean]
        If ($installed) {
            $pkgLine = $pkg
            break
        }
    }
    If (-not $installed) {
        Write-Verbose ""
        Write-Verbose "WARNING: the npm package '$Name' is not installed"
        Write-Verbose ""
        return $false
    }
    # Check version range
    #
    $vsnRegex = [regex] "^.*@(\d.*)$"
    $m = $vsnRegex.Match($pkgLine)
    If (-not $m.Success) {
        Write-Verbose ""
        Write-Verbose "WARNING: the npm package '$Name' version was not determined."
        Write-Verbose ""
        return $false
    }
    $vsn = $m.Groups[1].Value | Extract-Version
    If (-not (Is-Null $IsAtLeast)) {
        $isatleast = $IsAtLeast
        if ($IsAtLeast -is [string]) {
            $isatleast = $IsAtLeast | Extract-Version
        }
        If (-not (Test-Version $vsn -IsAtLeast $isatleast)) {
            Write-Verbose ""
            Write-Verbose ("WARNING: Expecting $Name " +
                "$($isatleast.Major).$($isatleast.Minor).$($isatleast.Patch)" +
                " $($isatleast.Qualifier) or later.")
            Write-Verbose ("Found " +
                "$($vsn.Major).$($vsn.Minor).$($vsn.Patch) $($vsn.Qualifier).")
            Write-Verbose ""
            return $false
        }
    }
    If (-not (Is-Null $IsLessThan)) {
        $islessthan = $IsLessThan
        if ($IsLessThan -is [string]) {
            $islessthan = $IsLessThan | Extract-Version
        }
        If (-not (Test-Version $vsn -IsLessThan $islessthan)) {
            Write-Verbose ""
            Write-Verbose ("WARNING: Expecting $Name " +
                "$($islessthan.Major).$($islessthan.Minor)." +
                "$($islessthan.Patch) $($islessthan.Qualifier) or later.")
            Write-Verbose ("Found " +
                "$($vsn.Major).$($vsn.Minor).$($vsn.Patch) $($vsn.Qualifier).")
            Write-Verbose ""
            return $false
        }
    }

    # OK, get out.
    #
    return $true
}
