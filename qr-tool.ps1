#################################################################################################################################################
# Configurable globals
#################################################################################################################################################
$global:sleepSeconds             = 0 # if greater than 0 script will loop, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds   = 3
$global:largeFileThreshholdBytes = 50000
$global:rejectByDeleting         = $true
#================================================================================================================================================
$global:qrServerAE               = "HOROS"
$global:qrServerHost             = "localhost"
$global:qrServerPort             = 2763
$global:qrDestAE                 = "FLUXTEST1AB"
$global:myAE                     = "QR-TOOL"
#################################################################################################################################################


#################################################################################################################################################
# Globals not for configuration use
#################################################################################################################################################
$global:scriptHomeDirPath        = $PSScriptRoot
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
        [System.IO.FileInfo]$File
    )
    if ($global:rejectByDeleting) {
        Write-Indented "Rejecting $($file.FullName) by deleting it."
        
        Remove-Item -Path $file.FullName
    }
    else {
        $rejectedPath = Join-Path -Path $rejectedDirPath -ChildPath $file.Name

        Write-Indented "Rejecting $($file.FullName) by moving it to $rejectedPath"

        StripPixelDataFromLargeFileAndMoveTo-Path -File $file -Destination $rejectedPath
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Extract-StudyTags
#################################################################################################################################################
function Extract-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $dicomFile   = [Dicom.DicomFile]::Open($File.FullName)
    $dataset     = $dicomFile.Dataset
    $method      = [Dicom.DicomDataset].GetMethod("GetSingleValueOrDefault").MakeGenericMethod([string])

    $patientName = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientName,      [string]""))
    $patientDob  = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientBirthDate, [string]""))
    $studyDate   = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyDate,        [string]""))
    $modality    = $method.Invoke($dataset, @([Dicom.DicomTag]::Modality,         [string]""))
    $studyUID    = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyInstanceUID, [string]""))

    $result = New-Object PSObject -Property @{
        PatientName = $patientName
        PatientDob  = $patientDob
        StudyDate   = $studyDate
        Modality    = $modality
        StudyInstanceUID    = $studyUID
    }

    return $result
}
#################################################################################################################################################


#################################################################################################################################################
# GetHashFrom-StudyTags
#################################################################################################################################################
function GetHashFrom-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$StudyTags
    )

    $hashInput = "$($StudyTags.PatientName)-$($StudyTags.PatientDob)-$($StudyTags.StudyDate)-$($StudyTags.Modality)-$($StudyTags.StudyInstanceUID)"

    Write-Indented "Hash Input: $hashInput"

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
    $hashBytes = $hashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
    $hashOutput = [System.BitConverter]::ToString($hashBytes).Replace("-", "")
    
    Write-Indented "Hash Output: $hashOutput"

    return $hashOutput
}
#################################################################################################################################################


#################################################################################################################################################
# WriteIndented-StudyTags
#################################################################################################################################################
function WriteIndented-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$StudyTags)
   
    Write-Indented "Patient Name:     $($StudyTags.PatientName)"
    Write-Indented "Patient DOB:      $($StudyTags.PatientDob)"
    Write-Indented "Study Date:       $($StudyTags.StudyDate)"
    Write-Indented "Modality:         $($StudyTags.Modality)"
    Write-Indented "StudyInstanceUID: $($StudyTags.StudyInstanceUID)"
}
#################################################################################################################################################


#################################################################################################################################################
# MoveStudyBy-StudyInstanceUID: THIS NEEDS TO BECOME A Cmdlet THAT HAS A SENSIBLE RETURN VALUE!
#################################################################################################################################################
function MoveStudyBy-StudyInstanceUID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$StudyInstanceUID
    )

    Write-Indented "Issuing move request for StudyInstanceUID '$StudyInstanceUID'..." -NoNewLine
    
    $request = New-Object Dicom.Network.DicomCMoveRequest($global:qrDestAE, $StudyInstanceUID)
    $client  = New-Object Dicom.Network.Client.DicomClient(
        $global:qrServerHost, $global:qrServerPort, $false, $global:myAE, $global:qrServerAE)
    
    $null = $client.AddRequestAsync($request).GetAwaiter().GetResult()
    
    $task = $client.SendAsync()
    $task.Wait()

    Write-Host " done."
}
#################################################################################################################################################


#################################################################################################################################################
# MaybeStripPixelDataAndThenMoveTo-Path 
#################################################################################################################################################
function MaybeStripPixelDataAndThenMoveTo-Path {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if ($File.Length -gt $global:largeFileThreshholdBytes) {
        $dicomFile = [Dicom.DicomFile]::Open($File.FullName)
        $dataset = $dicomFile.Dataset

        if ($dataset.Contains([Dicom.DicomTag]::PixelData)) {
            $null = $dataset.Remove([Dicom.DicomTag]::PixelData)
            $dicomFile.Save($File.FullName)
            Write-Indented "Pixel Data stripped from large file $($File.Name)."
        }
    }
    
    Move-Item -Path $File.FullName -Destination $Destination
}
#################################################################################################################################################


#################################################################################################################################################
# Set up packages
#################################################################################################################################################
$packagesDirPath        = Join-Path -Path $global:scriptHomeDirPath   -ChildPath "packages"
$foDicomName            = "fo-dicom.Desktop"
$foDicomVersion         = "4.0.8"
$foDicomDirPath         = Join-Path -Path $packagesDirPath            -ChildPath "$foDicomName.$foDicomVersion"
$foDicomExpectedDllPath = Join-Path -Path $foDicomDirPath             -ChildPath "lib\net45\Dicom.Core.dll"
#================================================================================================================================================
Require-NuGetPackage `
-PackageName $foDicomName `
-PackageVersion $foDicomVersion `
-ExpectedDllPath $foDicomExpectedDllPath `
-DestinationDir $packagesDirPath
$null = [Reflection.Assembly]::LoadFile($foDicomExpectedDllPath)
#################################################################################################################################################


#################################################################################################################################################
# Require some directories
#################################################################################################################################################
$incomingStoredItemsDirPath  = Join-Path -Path $global:scriptHomeDirPath -ChildPath "incoming-stored-items"
$queuedStoredItemsDirPath    = Join-Path -Path $global:scriptHomeDirPath -ChildPath "queued-stored-items"
$processedStoredItemsDirPath = Join-Path -Path $global:scriptHomeDirPath -ChildPath "processed-stored-items"
$rejectedStoredItemsDirPath  = Join-Path -Path $global:scriptHomeDirPath -ChildPath "rejected-stored-items"
#================================================================================================================================================
Require-DirectoryExists -DirectoryPath $incomingStoredItemsDirPath # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $queuedStoredItemsDirPath    -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $processedStoredItemsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $rejectedStoredItemsDirPath  -CreateIfNotExists $true
#################################################################################################################################################


#################################################################################################################################################
# Main
#################################################################################################################################################
do {
    #############################################################################################################################################
    # Pass #1/2: Examine files in $incomingStoredItemsDirPath and either accept them by moving them to $queuedStoredItemsDirPath or reject them.
    #############################################################################################################################################
    
    $filesInIncomingStoredItemsDir = Get-ChildItem -Path $incomingStoredItemsDirPath -Filter *.dcm

    if ($filesInIncomingStoredItemsDir.Count -eq 0) {
        Write-Indented "Pass #1: No DCM files found in incomingStoredItemsDir."
    } else {
        $counter = 0
        
        Write-Indented "Pass #1: Found $($filesInIncomingStoredItemsDir.Count) files in incomingStoredItems."

        Indent
        
        foreach ($file in $filesInIncomingStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInIncomingStoredItemsDir.Count) '$($file.FullName)'..."
            
            Indent
            
            $lastWriteTime = $file.LastWriteTime
            $timeDiff      = (Get-Date) - $lastWriteTime

            if (File-IsTooFresh -File $file) {
                continue
            }

            $tags = Extract-StudyTags -File $file

            WriteIndented-StudyTags -StudyTags $tags
            
            $hashOutput                    = GetHashFrom-StudyTags -StudyTags $tags 
            $possibleQueuedStoredItemsPath = Join-Path -Path $queuedStoredItemsDirPath    -ChildPath "$hashOutput.dcm"
            $possibleSentRequestPath       = Join-Path -Path $processedStoredItemsDirPath -ChildPath "$hashOutput.dcm"

            $foundFile = $null

            if (Test-Path -Path $possibleQueuedStoredItemsPath) {
                $foundFile = $possibleQueuedStoredItemsPath
            } elseif (Test-Path -Path $possibleSentRequestPath) {
                $foundFile = $possibleSentRequestPath
            }

            if ($foundFile -eq $null) {                
                Write-Indented "Enqueuing $($file.FullName) as $possibleQueuedStoredItemspath."

                MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $possibleQueuedStoredItemsPath
            } else {
                Write-Indented "Item for hash $hashOutput already exists in one of our directories as $foundFile, rejecting."
                
                Reject-File -File $file
            }
            
            Outdent
        } # foreach $file
        #########################################################################################################################################

        Outdent
    } # Pass #1/2
    #############################################################################################################################################

    #############################################################################################################################################
    # Pass #2/2: Examine files in $queuedStoredItemsDirPath, issue move requests for them and then move them to $processedStoredItemsPath.
    #############################################################################################################################################

    $filesInQueuedStoredItemsDir = Get-ChildItem -Path $queuedStoredItemsDirPath -Filter *.dcm

    if ($filesInQueuedStoredItemsDir.Count -eq 0) {
        Write-Indented "Pass #2: No DCM files found in queuedStoredItems."
    } else {
        $counter = 0
        
        Write-Indented "Pass #2: Found $($filesInQueuedStoredItemsDir.Count) files in queuedStoredItems."

        Indent
        
        foreach ($file in $filesInQueuedStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$($file.FullName)'..."
            
            Indent
            
            $tags = Extract-StudyTags -File $file

            WriteIndented-StudyTags -StudyTags $tags
            
            MoveStudyBy-StudyInstanceUID $tags.StudyInstanceUID
            
            $sentRequestPath = Join-Path -Path $processedStoredItemsDirPath -ChildPath $file.Name

            Write-Indented "Moving $($file.FullName) to $sentRequestPath"

            Move-Item -Path $File.FullName -Destination $sentRequestPath
            
            Outdent
        } # foreach $file
        #####################################################################################################################################
        
        Outdent
    } # Pass #2/2
    #############################################################################################################################################
    
    #############################################################################################################################################
    # All passes complete, maybe sleep and loop, otherwise fall through and exit.
    #############################################################################################################################################
    if ($global:sleepSeconds -gt 0) {
        Write-Indented "Sleeping $($global:sleepSeconds) seconds..." -NoNewLine
        Start-Sleep -Seconds $global:sleepSeconds
        Write-Host " done."
    }
    #############################################################################################################################################
} while ($global:sleepSeconds -gt 0)#
#################################################################################################################################################
Write-Indented "Done."
