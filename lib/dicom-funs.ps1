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
        Write-Error "Error extracting DICOM tag value: $_"

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

    if ($File.Length -gt $global:largeFileThreshholdBytes) {
        $dicomFile = [Dicom.DicomFile]::Open($File.FullName)
        $dataset = $dicomFile.Dataset

        if ($dataset.Contains([Dicom.DicomTag]::PixelData)) {
            $null = $dataset.Remove([Dicom.DicomTag]::PixelData)
            
            $dicomFile.Save($File.FullName)
            Write-Indented "Pixel Data stripped from $($File.Name) before moving it to $(Trim-BasePath -Path $Destination)."
        }
    }
    
    Move-Item -Path $File.FullName -Destination $Destination
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
    
    $responses = Move-StudyByStudyInstanceUIDSync `
      -StudyInstanceUID $StudyInstanceUID `
      -DestinationAE    $global:qrDestinationAE `
      -ServerHost       $global:qrServerHost `
      -ServerPort       $global:qrServerPort `
      -ServerAE         $global:qrServerAE `
      -MyAE             $global:myAE
            

    Write-Host " done."

    return $responses
}
#################################################################################################################################################


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
