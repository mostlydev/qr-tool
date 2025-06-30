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
        [Parameter(Mandatory = $true)]
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
# Test-AndCreateDirectory: PowerShell approved verb version of directory creation function
#################################################################################################################################################
function Test-AndCreateDirectory {
    param([string]$DirectoryPath)
    
    if (-not (Test-Path -Path $DirectoryPath)) {
        $null = New-Item -ItemType Directory -Path $DirectoryPath -Force
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Require-NuGetPackage: this is not currently used since we now share a fo-dicom DLL with FoDicomCmdlet, but could be useful in the future?
#################################################################################################################################################
function Require-NuGetPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,
        [Parameter(Mandatory = $true)]
        [string]$PackageVersion,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedDllPath,
        [Parameter(Mandatory = $true)]
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
        Write-Indented "Rejecting $(Trim-BasePath -Path $file.FullName) by deleting it."        
        Remove-Item -Path $file.FullName
    }
    else {
        $rejectedFileName = $File.Name
        $rejectedPath = Join-Path -Path $rejectedDirPath -ChildPath $rejectedFileName

        if (Test-Path -Path $rejectedPath) {
            # name is already taken, make it unique by adding a timestamp.
            $timestamp        = Get-Date -Format "yyyyMMddHHmmss"
            $fileBaseName     = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            $fileExtension    = [System.IO.Path]::GetExtension($File.Name)
            $rejectedFileName = "$fileBaseName-$timestamp$fileExtension"
            $rejectedPath     = Join-Path -Path $rejectedDirPath -ChildPath $rejectedFileName
        }

        Write-Indented "Rejecting $(Trim-BasePath -Path $file.FullName) by moving it to $rejectedPath"
        MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $rejectedPath
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Hash-String
#################################################################################################################################################
function Hash-String {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$HashInput
    )

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
    $hashBytes     = $hashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($HashInput))
    $hashOutput    = [System.BitConverter]::ToString($hashBytes).Replace("-", "")
    
    Write-Indented "Hash Output:      $hashOutput"

    return $hashOutput
}
#################################################################################################################################################


# Touch-File
#################################################################################################################################################
function Touch-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-Not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType "file"
    } else {
        (Get-Item -Path $Path).LastWriteTime = Get-Date
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Find-FileInDirectories
#################################################################################################################################################
function Find-FileInDirectories {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Directories
    )

    foreach ($dir in $Directories) {
        $fullPath = Join-Path -Path $dir -ChildPath $FileName

        if (Test-Path -Path $fullPath) {
            return $fullPath
        }
    }

    return $null
}
#################################################################################################################################################


#################################################################################################################################################
# Trim-BasePath
#################################################################################################################################################
function Trim-BasePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$BasePath = $global:cacheDirBasePath
    )

    if (-not $BasePath.EndsWith('\')) {
        $BasePath += '\'
    }

    return $Path.Replace($BasePath, '')
}
#################################################################################################################################################

