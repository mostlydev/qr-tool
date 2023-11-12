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
########################################################################################################################


########################################################################################################################
$packagesDirPath        = Join-Path -Path $scriptHome      -ChildPath "packages"
$foDicomName            = "fo-dicom.Desktop"
$foDicomVersion         = "4.0.8"
$foDicomDirPath         = Join-Path -Path $packagesDirPath -ChildPath "$foDicomName.$foDicomVersion"
$foDicomExpectedDllPath = Join-Path -Path $foDicomDirPath  -ChildPath "lib\net45\Dicom.Core.dll"
#=======================================================================================================================
Require-NuGetPackage `
    -PackageName $foDicomName `
    -PackageVersion $foDicomVersion `
    -ExpectedDllPath $foDicomExpectedDllPath `
    -DestinationDir $packagesDirPath
$null = [Reflection.Assembly]::LoadFile($foDicomExpectedDllPath)
########################################################################################################################


########################################################################################################################
$inboundDirPath         = Join-Path -Path $scriptHome      -ChildPath "inbound"
$queuedDirPath          = Join-Path -Path $scriptHome      -ChildPath "queued"
$requestsDirPath        = Join-Path -Path $scriptHome      -ChildPath "requests"
#=======================================================================================================================
Require-DirectoryExists -DirectoryPath $inboundDirPath # if this doesn't already exist, assume something is seriously wrong.
Require-DirectoryExists -DirectoryPath $queuedDirPath   -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $requestsDirPath -CreateIfNotExists $true
########################################################################################################################


$filesInInbound = Get-ChildItem -Path $inboundDirPath -Filter *.dcm

if ($filesInInbound.Count -eq 0) {
  Write-Host "No DCM files found in the folder."
}
else {
    foreach ($file in $filesInInbound) {
        Write-Host "Processing $file..."
    # if ($file.Length -gt 50000) {
    #   & dcmodify -nb -ie -ea "(7fe0,0010)" $file.FullName
    # }
    # $dcmData = & dcmdump $file.FullName
    # $patientName = ($dcmData | Select-String "0010,0010" | Out-String).Trim()
    # $dob = ($dcmData | Select-String "0010,0030" | Out-String).Trim()
    # $scanDate = ($dcmData | Select-String "0008,0020" | Out-String).Trim()
    # $hashInput = $patientName + $dob + $scanDate

    # $hash = [System.BitConverter]::ToString([System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))).Replace("-", "")
    # $newPath = "$baseDirPath\queue\$hash.dcm"

    # if (-not $processedHashes.ContainsKey($hash) -and -not (Test-Path $newPath)) {
    #   Move-Item -Path $file.FullName -Destination $newPath
    # }
    # else {
    #   Remove-Item -Path $file.FullName
    # }
    # $processedHashes[$hash] = $true
  }
}

