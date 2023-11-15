##################################################################################################################################################
# Do-Stage3: Examine files in $global:queuedStudyMovesDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and then
#            move them to queued stored item to $processedStoredItemsPath.
##################################################################################################################################################
function Do-Stage3 {
    $filesInQueuedStudyMovesDir = Get-ChildItem -Path $global:queuedStudyMovesDirPath -Filter *.move-request

    if ($filesInQueuedStudyMovesDir.Count -eq 0) {
        Write-Indented "Stage #3: No DCM files found in queuedStudyMoves."
    } else {
        $counter = 0
        
        Write-Indented " " # Just print a newline for output readability.    
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
                Write-Indented "... no responses (or null responses) received. This is unusual. Removing queued study move $($file.FullName): move could be re-attempting if re-triggered."
                Remove-Item -Path $file.FullName

                Outdent
                
                Continue
            }

            $cMoveStatus    = $cMoveResponses[-1]
            $cMoveResponses = $cMoveResponses[0..($cMoveResponses.Count - 2)]

            if ($cMoveStatus.Status -ne [Dicom.Network.DicomStatus]::Success) {
                Write-Indented "... C-Move's final response status was $($cMoveStatus.Statua). Removing queued study move $($file.FullName): move could be re-attempting if re-triggered."
                Remove-Item -Path $file.FullName

                Outdent
                
                Continue
            }

            Write-Indented "... C-Move was successful."

            # If the final response indicates sucess, we don't need need to examine the individual responses.
            
            $processedStudyMovePath = Join-Path -Path $global:processedStudyMovesDirPath -ChildPath $file.Name

            Write-Indented " " # Just print a newline for output readability.
            Write-Indented "Moving $(Trim-BasePath -Path $file.FullName) to $(Trim-BasePath -Path $processedStudyMovePath)... " -NoNewLine
            Move-Item -Path $file.FullName -Destination $processedStudyMovePath
            Write-Host " done."
            
            
            Outdent
        } # foreach $file
        ##############################################################################################################################################
        
        Outdent
    }
}
######################################################################################################################################################
