#################################################################################################################################################
# Get-DicomTagString
#################################################################################################################################################
function Get-DicomTagString {
    param (
        [Parameter(Mandatory = $true)]
        [Dicom.DicomDataset]$Dataset,

        [Parameter(Mandatory = $true)]
        [Dicom.DicomTag]$Tag,

        [string]$DefaultValue = ""
    )

    try {
        $method = [Dicom.DicomDataset].GetMethod("GetSingleValueOrDefault").MakeGenericMethod([string])
        
        return $method.Invoke($Dataset, @($Tag, $DefaultValue))
    }
    catch {
        Write-LogError "Error extracting DICOM tag value: $_"

        return $DefaultValue
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

    try {
        Write-LogDebug "Extracting DICOM tags from file: $($File.FullName)"
        
        $dicomFile        = [Dicom.DicomFile]::Open($File.FullName)
        $dataset          = $dicomFile.Dataset
        $method           = [Dicom.DicomDataset].GetMethod("GetSingleValueOrDefault").MakeGenericMethod([string])

        $patientName      = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientName,      [string]""))
        $patientBirthDate = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientBirthDate, [string]""))
        $studyDate        = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyDate,        [string]""))
        $modality         = $method.Invoke($dataset, @([Dicom.DicomTag]::Modality,         [string]""))
        $studyUID         = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyInstanceUID, [string]""))

        $result      = New-Object PSObject -Property @{
            PatientName      = $patientName
            PatientBirthDate = $patientBirthDate
            StudyDate        = $studyDate
            Modality         = $modality
            StudyInstanceUID = $studyUID
        }

        Write-LogDebug "Successfully extracted DICOM tags for patient: $patientName"
        return $result
    }
    catch {
        Write-LogError "Error extracting DICOM tags from file $($File.FullName): $_"
        throw
    }
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

    Hash-String -HashInput "$($StudyTags.PatientName)-$($StudyTags.PatientBirthDate)-$($StudyTags.StudyDate)"
}
#################################################################################################################################################


#################################################################################################################################################
# WriteStudyTags-Indented
#################################################################################################################################################
function WriteStudyTags-Indented {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$StudyTags)

    if ($global:maskPatientNames) {
        Write-Indented "Patient Name:     $(Mask-PatientName -Name $StudyTags.PatientName)"
    } else {
        Write-Indented "Patient Name:     $($StudyTags.PatientName)"
    }
    
    Write-Indented "Patient DOB:      $($StudyTags.PatientBirthDate)"
    Write-Indented "Study Date:       $($StudyTags.StudyDate)"
    Write-Indented "Modality:         $($StudyTags.Modality)"
    Write-Indented "StudyInstanceUID: $($StudyTags.StudyInstanceUID)"
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

    try {
        if ($File.Length -gt $global:largeFileThreshholdBytes) {
            Write-LogDebug "File $($File.Name) exceeds size threshold, checking for pixel data"
            
            $dicomFile = [Dicom.DicomFile]::Open($File.FullName)
            $dataset = $dicomFile.Dataset

            if ($dataset.Contains([Dicom.DicomTag]::PixelData)) {
                $null = $dataset.Remove([Dicom.DicomTag]::PixelData)
                
                $dicomFile.Save($File.FullName)
                Write-Indented "Pixel Data stripped from $($File.Name) before moving it to $(Trim-BasePath -Path $Destination)."
                Write-LogInfo "Pixel data stripped from file: $($File.Name)"
            }
        }
        
        Move-Item -Path $File.FullName -Destination $Destination
        Write-LogDebug "File moved from $($File.FullName) to $Destination"
    }
    catch {
        Write-LogError "Error processing file $($File.FullName): $_"
        throw
    }
}
#################################################################################################################################################


#################################################################################################################################################
# Move-StudyByStudyInstanceUID: 
#################################################################################################################################################
function Move-StudyByStudyInstanceUID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$StudyInstanceUID
    )

    Write-Indented "Issuing move request for StudyInstanceUID '$StudyInstanceUID'..." -NoNewLine
    
    $operationName = "Move study $StudyInstanceUID"
    
    $responses = Invoke-WithRetry -ScriptBlock {
        $result = Move-StudyByStudyInstanceUIDSync `
          -StudyInstanceUID $StudyInstanceUID `
          -DestinationAE    $global:qrDestinationAE `
          -ServerHost       $global:qrServerHost `
          -ServerPort       $global:qrServerPort `
          -ServerAE         $global:qrServerAE `
          -MyAE             $global:myAE
        
        # Validate the result
        if (-not $result) {
            throw "C-MOVE operation returned null or false result"
        }
        
        return $result
    } -MaxRetries 3 -RetryDelayMs 5000 -OperationName $operationName

    Write-Host " done."

    return $responses
}
#################################################################################################################################################


#################################################################################################################################################
# Get-PatientStudiesWithRetry: Query studies for a patient with retry mechanism
#################################################################################################################################################
function Get-PatientStudiesWithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PatientName,
        [Parameter(Mandatory=$true)]
        [string]$PatientBirthDate,
        [string]$Modality = $null,
        [int]$MonthsBack = $global:studyFindMonthsBack
    )

    $operationName = "Query studies for patient $PatientName"

    return Invoke-WithRetry -ScriptBlock {
        $cutoffDate = (Get-Date).AddMonths(-$MonthsBack).ToString("yyyyMMdd")

        $studies = Get-StudiesByPatientNameAndBirthDate `
            -MyAE $global:myAE `
            -QrServerAE $global:qrServerAE `
            -QrServerHost $global:qrServerHost `
            -QrServerPort $global:qrServerPort `
            -PatientName $PatientName `
            -PatientBirthDate $PatientBirthDate `
            -Modality $Modality `
            -MonthsBack $MonthsBack

        # Validate that we got a valid response
        if ($null -eq $studies) {
            throw "Query returned null result"
        }

        Write-LogDebug "Query returned $($studies.Count) studies for patient $PatientName"
        return $studies
    } -MaxRetries 3 -RetryDelayMs 2000 -OperationName $operationName

#################################################################################################################################################
# Mask-PatientName
#################################################################################################################################################
function Mask-PatientName {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $maskedNameParts = @()
    $nameParts = $Name.Split('^')

    foreach ($part in $nameParts) {
        if ($part.Length -gt 1) {
            $maskedPart = $part[0] + '?' * ($part.Length - 1)
            $maskedNameParts += $maskedPart
        } else {
            $maskedNameParts += $part
        }
    }

    return ($maskedNameParts -join '^')
}
#################################################################################################################################################
