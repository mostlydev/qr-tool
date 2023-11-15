######################################################################################################################################################
# Do-Stage1: Examine files in $global:incomingStoredItemsDirPath and either accept them by moving them to $global:queuedStoredItemsDirPath or reject
#            them.
######################################################################################################################################################
function Do-Stage1 {
    $filesInIncomingStoredItemsDir = Get-ChildItem -Path $global:incomingStoredItemsDirPath -Filter *.dcm
    
    if ($filesInIncomingStoredItemsDir.Count -eq 0) {
        Write-Indented "Stage #1: No files found in incomingStoredItemsDir."
    } else {
        $counter = 0
        
        Write-Indented " " # Just print a newline for output readability.
        Write-Indented "Stage #1: Found $($filesInIncomingStoredItemsDir.Count) files in incomingStoredItems."

        Indent
        
        foreach ($file in $filesInIncomingStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInIncomingStoredItemsDir.Count) '$(Trim-BasePath -Path $file.FullName)':"
            
            Indent
            
            $lastWriteTime = $file.LastWriteTime
            $timeDiff      = (Get-Date) - $lastWriteTime

            if (File-IsTooFresh -File $file) {
                continue
            }

            $tags = Extract-StudyTags -File $file

            WriteStudyTags-Indented -StudyTags $tags
            
            # The stage 1 hash is just name + DoB + study date, presumably the last is so that if the same patient comes in for
            # another appointment in the future a new hash will be generated.
            $studyHash      = Hash-String -HashInput "$($tags.PatientName)-$($tags.PatientBirthdate)-$($tags.StudyDate)"

            Write-Indented " " # Just print a newline for output readability.

            $hashedFileName = "$studyHash.dcm"
            $foundFile      = Find-FileInDirectories `
              -Filename $hashedFilename `
              -Directories @($global:queuedStoredItemsDirPath, $global:processedStoredItemsDirPath)
            
            if ($foundFile -eq $null) {
                $queuedStoredItemPath = Join-Path -Path $global:queuedStoredItemsDirPath -ChildPath $hashedFileName

                Write-Indented "Enqueuing $($file.Name) as $hashedFilename..." -NoNewLine

                $null = MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $queuedStoredItemPath
                
                Write-Indented " done."
            } else {
                Write-Indented "Item for hash $studyHash already exists as $(Trim-BasePath -Path $foundFile), rejecting."
                Reject-File -File $file -RejectedDirPath $global:rejectedStoredItemsDirPath
            }
            
            Outdent
        } # foreach $file
        ##############################################################################################################################################
        
        Outdent
    }
}
######################################################################################################################################################
