#################################################################################################################################################
# Globals meant not for configuration use, these probably shouldn't be changed by the user.
#################################################################################################################################################
$global:indent                   = 0
#################################################################################################################################################


#################################################################################################################################################
# Write-Indented
#################################################################################################################################################
function Write-Indented {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [switch]$NoNewLine
    )

    $indentString = " " * (2 * $global:indent)
    
    if ($NoNewLine) {
        Write-Host "$indentString$Message" -NoNewline
    } else {
        Write-Host "$indentString$Message"
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Indent
#################################################################################################################################################
function Indent {
    $global:indent += 1
}
#################################################################################################################################################


#################################################################################################################################################
# Outdent
#################################################################################################################################################
function Outdent {
    if ($global:indent -gt 0) {
        $global:indent -= 1
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Require-DirectoryExists
#################################################################################################################################################
function Require-DirectoryExists {
    param(
        [string]$DirectoryPath,
        [bool]$CreateIfNotExists = $false
    )
    
    try {
        if (-Not (Test-Path -Path $DirectoryPath)) {
            if (-Not $CreateIfNotExists) {
                Throw "$DirectoryPath does not exist."
            }
            
            Write-Indented "Didn't find $DirectoryPath, creating it..." -NoNewline
            $null = New-Item -ItemType Directory -Path $DirectoryPath
            
            if (-Not (Test-Path -Path $DirectoryPath)) {
                Throw "Failed to create directory at $DirectoryPath."
            } else {
                Write-Host " done."
            }
        } else {
            Write-Indented "Found $DirectoryPath."
        }
    }
    catch {
        Write-Indented "Error: $_"
        
        Exit 1
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Require-NuGetPackage
#################################################################################################################################################
function Require-NuGetPackage {
    param (
        [string]$PackageName,
        [string]$PackageVersion,
        [string]$ExpectedDllPath,
        [string]$DestinationDir
    )
    try {        
        if (-Not (Test-Path -Path $ExpectedDllPath)) {
            Write-Indented "Didn't find $ExpectedDllPath, installing $PackageName..." -NoNewline

            $null = Install-Package `
            -Name            $PackageName `
            -ProviderName    NuGet `
            -RequiredVersion $PackageVersion `
            -Scope           CurrentUser `
            -Destination     $DestinationDir `
            -Force
            
            if (-Not (Test-Path -Path $ExpectedDllPath)) {
                Throw "Failed to install $PackageName."
            } else {
                Write-Host " done."
            }
        } else {
            Write-Indented "Found $ExpectedDllPath."
        }
    }
    catch {
        Write-Indented "Error: $_"
        
        Exit 1
    }
}
#################################################################################################################################################


#################################################################################################################################################
# File-IsTooFresh
#################################################################################################################################################
function File-IsTooFresh {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $lastWriteTime = $file.LastWriteTime
    $timeDiff      = (Get-Date) - $lastWriteTime
    $result        = ($timeDiff.TotalSeconds -lt $global:mtimeThresholdSeconds)

    if ($result) {
        Write-Indented "$($file.Name) is too fresh."
    }
    
    return $result
}
#################################################################################################################################################


#################################################################################################################################################
# Reject-File
#################################################################################################################################################
function Reject-File {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [string]$RejectedDirPath 
    )
    if ($global:rejectByDeleting) {
        Write-Indented "Rejecting $($file.FullName) by deleting it."        
        Remove-Item -Path $file.FullName
    }
    else {
        $rejectedPath = Join-Path -Path $rejectedDirPath -ChildPath $file.Name

        Write-Indented "Rejecting $($file.FullName) by moving it to $rejectedPath"
        MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $RejectedDirPath
    }
}
#################################################################################################################################################
