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

    Hash-String -HashInput "$($StudyTags.PatientName)-$($StudyTags.PatientDob)-$($StudyTags.StudyDate)"
}
#################################################################################################################################################


#################################################################################################################################################
# WriteStudyTags-Indented
#################################################################################################################################################
function WriteStudyTags-Indented {
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
            Write-Indented "Pixel Data stripped from large file $($File.Name) before moving it to $Destination."
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
