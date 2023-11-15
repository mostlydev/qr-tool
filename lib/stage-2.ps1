######################################################################################################################################################
# Do-Stage2: Examine files in $global:queuedStoredItemsDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and then 
#            move them to queued stored item to $processedStoredItemsPath.
######################################################################################################################################################
function Do-Stage2 {
    Write-Indented " " # Just print a newline for output readability.    

    $filesInQueuedStoredItemsDir = Get-ChildItem -Path $global:queuedStoredItemsDirPath -Filter *.dcm

    if ($filesInQueuedStoredItemsDir.Count -eq 0) {
        Write-Indented "Stage #2: No DCM files found in queuedStoredItems."
    } else {
        $counter = 0
        
        Write-Indented "Stage #2: Found $($filesInQueuedStoredItemsDir.Count) files in queuedStoredItems."

        Indent
        
        foreach ($file in $filesInQueuedStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$(Trim-BasePath -Path $file.FullName)':"
            
            Indent
            
            $tags = Extract-StudyTags -File $file

            WriteStudyTags-Indented -StudyTags $tags
            Write-Indented " " # Just print a newline for output readability.
            
            Write-Indented "Looking up studies for $($tags.PatientName)/$($tags.PatientBirthdate)/$($tags.Modality)..."
            
            $cFindResponses = Get-StudiesByPatientNameAndBirthDate `
              -MyAE             $global:myAE `
              -QrServerAE       $global:qrServerAE `
              -QrServerHost     $global:qrServerHost `
              -QrServerPort     $global:qrServerPort `
              -PatientName      $tags.PatientName `
              -PatientBirthDate $tags.PatientBirthDate `
              -Modality         $tags.Modality `
              -MonthsBack       $global:studyFindMonthsBack

            if ($cFindResponses -eq $null -or $cFindResponses.Count -eq 0) {
                Write-Indented "... no responses (or null responses) received. This is unusual. Removing queued file $($file.FullName), user may re-store it to trigger a new attempt."
                Remove-Item -Path $file.FullName

                Continue
            }

            $cFindStatus = $cFindResponses[-1]
            $cFindResponses = $cFindResponses[0..($cFindResponses.Count - 2)]

            if ($cFindStatus.Status -ne [Dicom.Network.DicomStatus]::Success) {
                Write-Indented "... C-Find's final response status was $($cFindStatus.Statua). Removing queued file $($file.FullName), user may re-store it to trigger a new attempt."
                Remove-Item -Path $file.FullName

                Continue
            }

            Write-Indented "... C-Find was successful, move request tickets will be created."

            $responseCounter = 0;

            Indent
            
            foreach ($response in $cFindResponses) {
                $responseCounter++

                $dataset          = $response.Dataset
                $studyInstanceUID = Get-DicomTagString -Dataset $dataset -Tag ([Dicom.DicomTag]::StudyInstanceUID)

                Write-Indented "Examine response #$responseCounter/$($cFindResponses.Count) with SUID $studyInstanceUID..."

                Indent
                
                $studyMoveTicketFilePath = Join-Path -Path $global:queuedStudyMovesDirPath -ChildPath "$studyInstanceUID.move-request"                

                if (-Not (Test-Path -Path $studyMoveTicketFilePath)) {
                    Write-Indented "Creating move request ticket at $(Trim-BasePath -Path $studyMoveTicketFilePath)..." -NoNewLine
                    $null = Touch-File $studyMoveTicketFilePath
                    Write-Host " created." 

                } else {
                    Write-Indented "Ticket already exists at $(Trim-BasePath -Path $studyMoveTicketFilePath)."
                }

                Outdent
                
            }

            Outdent

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
