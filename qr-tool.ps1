# PS D:\qr-tool> Install-Package -Name fo-dicom.Desktop -ProviderName NuGet -Scope CurrentUser -Destination "packages" -Force
# Install-Package -Name fo-dicom.Desktop -ProviderName NuGet -RequiredVersion 4.0.8 -Scope CurrentUser -Destination . -Force

########################################################################################################################
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
            
            Write-Host "Didn't find $DirectoryPath, creating it..." -NoNewline
            $null = New-Item -ItemType Directory -Path $DirectoryPath

            if (-Not (Test-Path -Path $DirectoryPath)) {
                Throw "Failed to create directory at $DirectoryPath."
            } else {
                Write-Host " done."
            }
        } else {
            Write-Host "Found $DirectoryPath."
        }
    }
    catch {
        Write-Host "Error: $_"
        
        Exit 1
    }
}
########################################################################################################################


########################################################################################################################
function Require-NuGetPackage {
    param (
        [string]$PackageName,
        [string]$PackageVersion,
        [string]$ExpectedDllPath,
        [string]$DestinationDir
    )
    try {        
        if (-Not (Test-Path -Path $ExpectedDllPath)) {
            Write-Host "Didn't find $ExpectedDllPath, installing $PackageName..." -NoNewline
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
            Write-Host "Found $ExpectedDllPath."
        }
    }
    catch {
        Write-Host "Error: $_"
        
        Exit 1
    }
}
########################################################################################################################


########################################################################################################################
$scriptHome             = $PSScriptRoot
$packagesDirPath        = Join-Path -Path $scriptHome      -ChildPath "packages"
$requestsDirPath        = Join-Path -Path $scriptHome      -ChildPath "requests"
########################################################################################################################
$queueDirPath           = Join-Path -Path $scriptHome      -ChildPath "queue"
########################################################################################################################
$foDicomName            = "fo-dicom.Desktop"
$foDicomVersion         = "4.0.8"
$foDicomDirPath         = Join-Path -Path $packagesDirPath -ChildPath "$foDicomName.$foDicomVersion"
$foDicomExpectedDllPath = Join-Path -Path $foDicomDirPath  -ChildPath "lib\net45\Dicom.Core.dll"
########################################################################################################################


########################################################################################################################
Require-DirectoryExists -DirectoryPath $packagesDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $requestsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $queueDirPath

Require-NuGetPackage `
    -PackageName $foDicomName `
    -PackageVersion $foDicomVersion `
    -ExpectedDllPath $foDicomExpectedDllPath `
    -DestinationDir $packagesDirPath

$null = [Reflection.Assembly]::LoadFile($foDicomExpectedDllPath)


