######################################################################################################################################################
# Include FoDicomCmdlets:
######################################################################################################################################################
$global:foDicomCmdletsDLLPath = Join-Path -Path $PSScriptRoot -ChildPath "FoDicomCmdlets\bin\Release\FoDicomCmdlets.dll"
#=====================================================================================================================================================
Import-Module $global:foDicomCmdletsDLLPath
######################################################################################################################################################


######################################################################################################################################################
# Set up packages (well, just fo-dicom presently, shared with FoDicomCmdlets):
######################################################################################################################################################
$global:foDicomExpectedDllPath = Join-Path -Path $PSScriptRoot -ChildPath "FoDicomCmdlets/bin/Release/Dicom.Core.dll"
$null = [Reflection.Assembly]::LoadFile($global:foDicomExpectedDllPath)
######################################################################################################################################################


######################################################################################################################################################
# Include required function libs:
######################################################################################################################################################
# These included files depend on each other and on globals defined here, so removing any of them is likely to cause problems: they are just being
# used to keep the functions organized instead of having one huge file, not to make dependency management resilient.
#=====================================================================================================================================================
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\utility-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\dicom-funs.ps1")
######################################################################################################################################################


######################################################################################################################################################
# Globals meant to be used for configuration purposes, user may change as required:
######################################################################################################################################################
$global:sleepSeconds             = 0 # if greater than 0 script will loop, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds   = 3
$global:largeFileThreshholdBytes = 50000
$global:rejectByDeleting         = $true
$global:myAE                     = "QR-TOOL"
#=====================================================================================================================================================
$global:qrServerAE               = "HOROS"
$global:qrServerHost             = "localhost"
$global:qrServerPort             = 2763
$global:qrDestinationAE          = "FLUXTEST1AB"
#=====================================================================================================================================================
$global:studyFindMonthsBack      = 60
######################################################################################################################################################


######################################################################################################################################################
# Generate some directory paths. The user could put $global:incomingStoredItemsDirPath outside of $global:cacheDirBasePath without breaking things if 
# they felt like it.
######################################################################################################################################################
$global:cacheDirBasePath            = Join-Path -Path $PSScriptRoot            -ChildPath "cache"
#=====================================================================================================================================================
# Stored items and their sentinels:
$global:incomingStoredItemsDirName  = "incoming-stored-items"
$global:queuedStoredItemsDirName    = "queued-stored-items"
$global:processedStoredItemsDirName = "processed-stored-items"
$global:rejectedStoredItemsDirName  = "rejected-stored-items"
# Move request tickets:
$global:queuedStudyMovesDirName     = "queued-study-moves"
$global:processedStudyMovesDirName  = "processed-study-moves"
#=====================================================================================================================================================
# Stored items and their sentinels:
$global:incomingStoredItemsDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:incomingStoredItemsDirName
$global:queuedStoredItemsDirPath    = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:queuedStoredItemsDirName
$global:processedStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:processedStoredItemsDirName
$global:rejectedStoredItemsDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:rejectedStoredItemsDirName
# Move request tickets:
$global:queuedStudyMovesDirPath     = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:queuedStudyMovesDirName
$global:processedStudyMovesDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:processedStudyMovesDirName
######################################################################################################################################################


######################################################################################################################################################
# Require some directories:
######################################################################################################################################################
Require-DirectoryExists -DirectoryPath $global:cacheDirBasePath            # if this doesn't already exist, assume something is seriously wrong, bail.
# Stored items and their sentinels:
Require-DirectoryExists -DirectoryPath $global:incomingStoredItemsDirPath  # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $global:queuedStoredItemsDirPath    -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:processedStoredItemsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:rejectedStoredItemsDirPath  -CreateIfNotExists $true
# Move request tickets:
Require-DirectoryExists -DirectoryPath $global:queuedStudyMovesDirPath     -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:processedStudyMovesDirPath  -CreateIfNotExists $true
######################################################################################################################################################


######################################################################################################################################################
# Main:
######################################################################################################################################################
do {
    ##################################################################################################################################################
    # Stage #1/2: Examine files in $global:incomingStoredItemsDirPath and either accept them by moving them to $global:queuedStoredItemsDirPath or
    #            reject them.
    ##################################################################################################################################################
    Write-Indented " " # Just print a newline for output readability.
    
    $filesInIncomingStoredItemsDir = Get-ChildItem -Path $global:incomingStoredItemsDirPath -Filter *.dcm
    
    if ($filesInIncomingStoredItemsDir.Count -eq 0) {
        Write-Indented "Stage #1: No DCM files found in incomingStoredItemsDir."
    } else {
        $counter = 0
        
        Write-Indented "Stage #1: Found $($filesInIncomingStoredItemsDir.Count) files in incomingStoredItems."

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

            WriteStudyTags-Indented -StudyTags $tags
            
            # The stage 1 hash is just name + DoB + study date, presumably the last is so that if the same patient comes in for
            # another appointment in the future a new hash will be generated.
            $studyHash                        = Hash-String -HashInput "$($tags.PatientName)-$($tags.PatientBirthdate)-$($tags.StudyDate)"

            Write-Indented " " # Just print a newline for output readability.

            $hashedFilename                   = "$studyHash.dcm"
            $possibleQueuedStoredItemsPath    = Join-Path   -Path $global:queuedStoredItemsDirPath    -ChildPath $hashedFilename
            $possibleProcessedStoredItemsPath = Join-Path   -Path $global:processedStoredItemsDirPath -ChildPath $hashedFilename

            $foundFile = $null

            if (Test-Path -Path $possibleQueuedStoredItemsPath) {
                $foundFile = $possibleQueuedStoredItemsPath
            } elseif (Test-Path -Path $possibleProcessedStoredItemsPath) {
                $foundFile = $possibleProcessedStoredItemsPath
            }

            if ($foundFile -eq $null) {                
                Write-Indented "Enqueuing $($file.Name) as $hashedFilename."
                MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $possibleQueuedStoredItemsPath
            } else {
                Write-Indented "Item for hash $studyHash already exists as $foundFile, rejecting."
                Reject-File -File $file -RejectedDirPath $global:rejectedStoredItemsDirPath
            }
            
            Outdent
        } # foreach $file
        ##############################################################################################################################################

        Outdent
    } # Stage #1/2
    ##################################################################################################################################################

    ##################################################################################################################################################
    # Stage #2/2: Examine files in $global:queuedStoredItemsDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and
    #             then move them to queued stored item to $processedStoredItemsPath.
    ##################################################################################################################################################
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

            Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$($file.FullName)'..."
            
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
                Write-Indented "No responses (or null responses) received. This is unusual. Removing queued file $($file.FullName), user may re-store it to trigger a new attempt."
                Remove-Item -Path $file.FullName

                Continue
            }

            $status = $cFindResponses[-1]
            $cFindResponses = $cFindResponses[0..($cFindResponses.Count - 2)]

            if ($status.Status -ne [Dicom.Network.DicomStatus]::Success) {
                Write-Indented "Final response status was $($status.Statua). Removing queued file $($file.FullName), user may re-store it to trigger a new attempt."
                Remove-Item -Path $file.FullName

                Continue
            }

            Write-Indented "The C-Find query was successful, move request tickets will be created."

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
                    Write-Indented "Creating move request ticket at $studyMoveTicketFilePath..." -NoNewLine
                    $null = Touch-File $studyMoveTicketFilePath
                    Write-Host " created." 

                } else {
                    Write-Indented "Ticket already exists at $studyMoveTicketFilePath."
                }

                Outdent
                
            }

            Outdent

            $processedStoredItemPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath $file.Name

            Write-Indented " " # Just print a newline for output readability.
            Write-Indented "Moving $($file.FullName) to processedStoredItemPath... " -NoNewLine
            Move-Item -Path $file.FullName -Destination $processedStoredItemPath
            Write-Host " done."
            
            # $moveResponses      = Move-StudyByStudyInstanceUID $tags.StudyInstanceUID
            # $lastResponseStatus = $null

            # if ($moveResponses -and $moveResponses.Count -gt 0) {
            #     $lastResponseStatus = $moveResponses[-1].Status
            # } else {
            #     Write-Indented "No responses received"
            # }
            
            # if ($lastResponseStatus -eq [Dicom.Network.DicomStatus]::Success) {
            #     Write-Indented "The last response appears to have been successful."
            # } elseif ($lastResponseStatus -eq $null) {
            #     Write-Indented "The last response remains null. This is unusual."
            # } else {
            #     Write-Indented "The last response appears not to have been successful. Status: $($lastResponseStatus)"
            # }

            # if ($lastResponseStatus -ne [Dicom.Network.DicomStatus]::Success) {
            #     Write-Indented "Since move does not appear to have succeeded, $($file.FullName) will be deleted so as to allow future move attempts of the same hash."

            #     Remove-Item -Path $file.FullName
            # }
            # else {
            #     $processedStoredItemPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath $file.Name

            #     Write-Indented "Moving $($file.FullName) to $processedStoredItemPath"
            #     Move-Item -Path $file.FullName -Destination $processedStoredItemPath
            # }
        
        Outdent
    } # foreach $file
    ##############################################################################################################################################
    
    Outdent
} # Stage #2/2
##################################################################################################################################################

##################################################################################################################################################
# All stagees complete, maybe sleep and loop, otherwise fall through and exit.
##################################################################################################################################################
if ($global:sleepSeconds -gt 0) {
    Write-Indented "Sleeping $($global:sleepSeconds) seconds..." -NoNewLine
    Start-Sleep -Seconds $global:sleepSeconds
    Write-Host " done."
}
##################################################################################################################################################
} while ($global:sleepSeconds -gt 0)#
######################################################################################################################################################
Write-Indented " " # Just print a newline for output readability.
Write-Indented "Done."
