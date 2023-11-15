##################################################################################################################################################
# Do-Stage3: Examine files in $global:queuedStudyMovesDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and then
#            move them to queued stored item to $processedStoredItemsPath.
##################################################################################################################################################
function Do-Stage3 {
    Write-Indented " " # Just print a newline for output readability.    

    $filesInQueuedStudyMovesDir = Get-ChildItem -Path $global:queuedStudyMovesDirPath -Filter *.move-request

    if ($filesInQueuedStudyMovesDir.Count -eq 0) {
        Write-Indented "Stage #3: No DCM files found in queuedStudyMoves."
    } else {
        $counter = 0
        
        Write-Indented "Stage #3: Found $($filesInQueuedStudyMovesDir.Count) files in queuedStudyMoves."

        Indent
        
        foreach ($file in $filesInQueuedStudyMovesDir) {
            $counter++
            
            Write-Indented "Processing file #$counter/$($filesInQueuedStudyMovesDir.Count) '$(Trim-BasePath -Path $file.FullName)':"
            
            Indent

            $studyInstanceUID = $file.BaseName

            Write-Indented " " # Just print a newline for output readability.
            Write-Indented "Moving study with StudyInstanceUID '$studyInstanceUID'..."
            
            $cMoveResponses = Move-StudyByStudyInstanceUID $studyInstanceUID

            if ($cMoveResponses -eq $null -or $cMoveResponses.Count -eq 0) {
                Write-Indented "... no responses (or null responses) received. This is unusual. Removing queued study move $($file.FullName)."
                Remove-Item -Path $file.FullName

                Continue
            }

            $lastResponseStatus = $null

            if ($cMoveResponses -and $cMoveResponses.Count -gt 0) {
                $lastResponseStatus = $cMoveResponses[-1].Status
            } else {
                Write-Indented "No responses received"
            }
            
            if ($lastResponseStatus -eq [Dicom.Network.DicomStatus]::Success) {
                Write-Indented "The last response appears to have been successful."
            } elseif ($lastResponseStatus -eq $null) {
                Write-Indented "The last response remains null. This is unusual."
            } else {
                Write-Indented "The last response appears not to have been successful. Status: $($lastResponseStatus)"
            }

            if ($lastResponseStatus -ne [Dicom.Network.DicomStatus]::Success) {
                Write-Indented "Since move does not appear to have succeeded, $($file.FullName) will be deleted so as to allow future move attempts of the same hash."

                Remove-Item -Path $file.FullName
            }
            else {
                $processedStoredItemPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath $file.Name

                Write-Indented "Moving $($file.FullName) to $processedStoredItemPath"
                Move-Item -Path $file.FullName -Destination $processedStoredItemPath
            }
            
            Outdent
        } # foreach $file
        ##############################################################################################################################################
        
        Outdent
    }
}
######################################################################################################################################################
