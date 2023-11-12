# PS D:\qr-tool> Install-Package -Name fo-dicom.Desktop -ProviderName NuGet -Scope CurrentUser -Destination "packages" -Force
# Install-Package -Name fo-dicom.Desktop -ProviderName NuGet -RequiredVersion 4.0.8 -Scope CurrentUser -Destination . -Force


##################################################################################################################################
# Configurable globals
##################################################################################################################################
$global:sleepSeconds             = 0 # 3 # if greater than 0, script loops, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds   = 3
$global:largeFileThreshholdBytes = 50000
##################################################################################################################################


##################################################################################################################################
# Other globals
##################################################################################################################################
$global:scriptHomeDirPath        = $PSScriptRoot
$global:indent                   = 0
##################################################################################################################################


##################################################################################################################################
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
##################################################################################################################################


##################################################################################################################################
function Indent {
    $global:indent += 1
}
##################################################################################################################################


##################################################################################################################################
function Outdent {
    if ($global:indent -gt 0) {
        $global:indent -= 1
    }
}
##################################################################################################################################


##################################################################################################################################
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
                Write-Indented " done."
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
##################################################################################################################################


##################################################################################################################################
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
                Write-Indented " done."
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
##################################################################################################################################


##################################################################################################################################
# Set up packages
##################################################################################################################################
$packagesDirPath        = Join-Path -Path $global:scriptHomeDirPath  -ChildPath "packages"
$foDicomName            = "fo-dicom.Desktop"
$foDicomVersion         = "4.0.8"
$foDicomDirPath         = Join-Path -Path $packagesDirPath -ChildPath "$foDicomName.$foDicomVersion"
$foDicomExpectedDllPath = Join-Path -Path $foDicomDirPath  -ChildPath "lib\net45\Dicom.Core.dll"
#=================================================================================================================================
Require-NuGetPackage `
-PackageName $foDicomName `
-PackageVersion $foDicomVersion `
-ExpectedDllPath $foDicomExpectedDllPath `
-DestinationDir $packagesDirPath
$null = [Reflection.Assembly]::LoadFile($foDicomExpectedDllPath)
##################################################################################################################################


##################################################################################################################################
# Require some directories
##################################################################################################################################
$inboundDirPath          = Join-Path -Path $global:scriptHomeDirPath  -ChildPath "inbound"
$queuedDirPath           = Join-Path -Path $global:scriptHomeDirPath  -ChildPath "queued"
$outboundRequestsDirPath = Join-Path -Path $global:scriptHomeDirPath  -ChildPath "outbound-requests"
$sentRequestsDirPath     = Join-Path -Path $global:scriptHomeDirPath  -ChildPath "sent-requests"
#=================================================================================================================================
Require-DirectoryExists -DirectoryPath $inboundDirPath # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $queuedDirPath           -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $outboundRequestsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $sentRequestsDirPath     -CreateIfNotExists $true
##################################################################################################################################


##################################################################################################################################
# Main
##################################################################################################################################
do {
    $filesInInbound = Get-ChildItem -Path $inboundDirPath -Filter *.dcm

    if ($filesInInbound.Count -eq 0) {
        Write-Indented "No DCM files found in inbound."
    } else {
        $counter = 0
        
        Write-Indented "Found $($filesInInbound.Count) files in inbound."
        
        ##########################################################################################################################
        foreach ($file in $filesInInbound) {
            $counter++

            Write-Indented "  Processing file #$counter/$($filesInInbound.Count) '$($file.Name)'..."
            
            $lastWriteTime = $file.LastWriteTime
            $timeDiff      = (Get-Date) - $lastWriteTime

            if ($timeDiff.TotalSeconds -lt $global:mtimeThresholdSeconds) {
                Write-Indented "    $($file.Name) is too new, skipping it for now."
                continue
            }

            $dicomFile       = [Dicom.DicomFile]::Open($file.FullName)
            $dataset         = $dicomFile.Dataset
            $method          = [Dicom.DicomDataset].GetMethod("GetSingleValueOrDefault").MakeGenericMethod([string])
            $filePatientName = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientName, [string] ""))
            $filePatientDob  = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientBirthDate, [string] ""))
            $fileStudyDate   = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyDate, [string] ""))
            $hashInput       = "$filePatientName-$filePatientDob-$fileStudyDate"

            Write-Indented "    Patient Name: $filePatientName"
            Write-Indented "    Patient DOB:  $filePatientDob"
            Write-Indented "    Study Date:   $fileStudydate"
            Write-Indented "    Hash Input:   $hashInput"
            
            if ($file.Length -gt $global:largeFileThreshholdBytes) {
                if ($dataset.Contains([Dicom.DicomTag]::PixelData)) {
                    $null = $dataset.Remove([Dicom.DicomTag]::PixelData)
                }

                $dicomFile.Save($file.FullName)

                Write-Indented "    Pixel Data stripped from large file $file."
            }
            
            $hashOutput = [System.BitConverter]::ToString([System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))).Replace("-", "")

            Write-Indented "    Hash Output:  $hashOutput"

            # $newPath = "$baseDirPath\queue\$hashOutput.dcm"
            
            # if (-not $processedHashes.ContainsKey($hash) -and -not (Test-Path $newPath)) {
            #   Move-Item -Path $file.FullName -Destination $newPath
            # }
            # else {
            #   Remove-Item -Path $file.FullName
            # }
            # $processedHashes[$hash] = $true
        }
        ##########################################################################################################################
    }

    if ($global:sleepSeconds -gt 0) {
        Write-Indented "Sleeping $($global:sleepSeconds) seconds..."
        Start-Sleep -Seconds $global:sleepSeconds 
    }
    ##############################################################################################################################
} while ($global:sleepSeconds -gt 0)#
##################################################################################################################################
