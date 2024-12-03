######################################################################################################################################################
# Do-Stage2: Examine files in $global:queuedStoredItemsDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and then
#            move them to queued stored item to $processedStoredItemsPath.
######################################################################################################################################################
function Do-Stage2 {
    $filesInQueuedStoredItemsDir = Get-ChildItem -Path $global:queuedStoredItemsDirPath -Filter *.dcm
  
    if ($filesInQueuedStoredItemsDir.Count -eq 0) {
      Write-Indented "Stage #2: No files found in queuedStoredItems."
    }
    else {
      $counter = 0
  
      Write-Indented " " # Just print a newline for output readability.
      Write-Indented "Stage #2: Found $($filesInQueuedStoredItemsDir.Count) files in queuedStoredItems."
  
      Indent
  
      foreach ($file in $filesInQueuedStoredItemsDir) {
        $counter++
  
        Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$(Trim-BasePath -Path $file.FullName)':"
  
        Indent
  
        $tags = Extract-StudyTags -File $file
  
        if ($null -ne $global:findAndMoveFixedModality) {
          $modality = $global:findAndMoveFixedModality
        }
        else {
          $modality = $tags.Modality
        }
  
        WriteStudyTags-Indented -StudyTags $tags
        Write-Indented " " # Just print a newline for output readability.
        Write-Indented "Looking up studies for $($tags.PatientName)/$($tags.PatientBirthdate)/$modality..."
  
        $queryDetails = "PatientName=$($tags.PatientName)|PatientBirthDate=$($tags.PatientBirthDate)|Modality=$modality"
  
        $cFindResponses = Get-StudiesByPatientNameAndBirthDate `
          -MyAE             $global:myAE `
          -QrServerAE       $global:qrServerAE `
          -QrServerHost     $global:qrServerHost `
          -QrServerPort     $global:qrServerPort `
          -PatientName      $tags.PatientName `
          -PatientBirthDate $tags.PatientBirthDate `
          -Modality         $modality `
          -MonthsBack       $global:studyFindMonthsBack
  
        if ($cFindResponses -eq $null -or $cFindResponses.Count -eq 0) {
          Log-Query -QueryType "C-FIND" -QueryDetails "$queryDetails|Result=NoResponse"
        }
        else {
          $cFindStatus = $cFindResponses[-1]
          if ($cFindStatus.Status -ne [Dicom.Network.DicomStatus]::Success) {
            Log-Query -QueryType "C-FIND" -QueryDetails "$queryDetails|Error=$($cFindStatus.Status)"
          }
          else {
            $studies = $cFindResponses[0..($cFindResponses.Count - 2)]
            $studyDates = $studies | ForEach-Object { $_.Dataset.GetString([Dicom.DicomTag]::StudyDate) }
            Log-Query -QueryType "C-FIND" -QueryDetails "$queryDetails|StudyCount=$($studies.Count)|StudyDates=$($studyDates -join ',')"
          }
        }
  
        if ($cFindResponses -eq $null -or $cFindResponses.Count -eq 0) {
          $noResultsPath = Join-Path -Path $global:noResultsStoredItemsDirPath -ChildPath $file.Name
          Write-Indented "No responses received. Moving file to no-results directory."
          Move-Item -Path $file.FullName -Destination $noResultsPath
          Continue
        }
  
  
        if ($cFindResponses.Count -eq 1) {
          $cFindStatus = $cFindResponses[0]
          if ($cFindStatus.Status -eq [Dicom.Network.DicomStatus]::Success) {
            Write-Indented "... received one response with status Success but no datasets."
          }
          else {
            Write-Indented "... received one response with status $($cFindStatus.Status)"
          }
        }
        else {
          $cFindStatus = $cFindResponses[-1]
          $cFindResponses = $cFindResponses[0..($cFindResponses.Count - 2)]
  
          if ($cFindStatus.Status -ne [Dicom.Network.DicomStatus]::Success) {
            Write-Indented "... C-Find's final response status was $($cFindStatus.Status). Removing queued file $($file.FullName), user may re-store it to trigger a new attempt."
            Remove-Item -Path $file.FullName
  
            Outdent
  
            Continue
          }
  
          Write-Indented "... C-Find was successful, move request tickets may be created."
  
          Indent
  
          $responseCounter = 0;
  
          foreach ($response in $cFindResponses) {
            $responseCounter++
  
            $dataset = $response.Dataset
            $studyInstanceUID = Get-DicomTagString -Dataset $dataset -Tag ([Dicom.DicomTag]::StudyInstanceUID)
  
            Write-Indented "Examine response #$responseCounter/$($cFindResponses.Count) with SUID $studyInstanceUID..."
  
            Indent
  
            $studyMoveTicketFileName = "$studyInstanceUID.move-request"
            $foundFile = Find-FileInDirectories `
              -Filename $studyMoveTicketFileName `
              -Directories @($global:queuedStudyMovesDirPath, $global:processedStudyMovesDirPath)
  
            if ($foundFile -eq $null) {
              $studyMoveTicketFilePath = Join-Path -Path $global:queuedStudyMovesDirPath -ChildPath "$studyInstanceUID.move-request"
  
              Write-Indented "Creating move request ticket at $(Trim-BasePath -Path $studyMoveTicketFilePath)..." -NoNewLine
  
              $null = Touch-File $studyMoveTicketFilePath
  
              Write-Host " done."
            }
            else {
              Write-Indented "Item for SUID $studyInstanceUID already exists as $(Trim-BasePath -Path $foundFile)."
              # don't delete or move anything yet, we'll do it further down after iterating over all the responses.
            }
  
            Outdent
          }
  
          Outdent
        }
  
        $processedStoredItemPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath $file.Name
  
        Write-Indented " " # Just print a newline for output readability.
        Write-Indented "Moving $(Trim-BasePath -Path $file.FullName) to $(Trim-BasePath -Path $processedStoredItemPath)... " -NoNewLine
        Move-Item -Path $file.FullName -Destination $processedStoredItemPath
        Write-Host " done."
  
        Outdent
      } # foreach $file
      ##############################################################################################################################################
  
      Outdent
    }
  }
  ######################################################################################################################################################
  