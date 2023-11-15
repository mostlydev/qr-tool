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
# These included files depend on each other and on globals defined here, so removing any of them or changing their order is likely to cause problems:
# they are just being used to keep the functions organized instead of having one huge file, not to make dependency management resilient.
#=====================================================================================================================================================
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\utility-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\dicom-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\stage-1.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\stage-2.ps1")
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
    Do-Stage1
    Do-Stage2
    
    ##################################################################################################################################################
    # Stage #3/3: Examine files in $global:queuedStudyMovesDirPath, create move request tickets in $global:queuedStudyMovesDirPath in for them and
    #             then move them to queued stored item to $processedStoredItemsPath.
    ##################################################################################################################################################
    Write-Indented " " # Just print a newline for output readability.    

    $filesInQueuedStudyMovesDir = Get-ChildItem -Path $global:queuedStudyMovesDirPath -Filter *.move-request

    if ($filesInQueuedStudyMovesDir.Count -eq 0) {
        Write-Indented "Stage #3: No DCM files found in queuedStoredItems."
    } else {
        $counter = 0
        
        Write-Indented "Stage #3: Found $($filesInQueuedStudyMovesDir.Count) files in queuedStoredItems."

        Indent
        
        foreach ($file in $filesInQueuedStudyMovesDir) {
            $counter++
            
            Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$(Trim-BasePath -Path $file.FullName)':"
            
            Indent

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
    } # Stage #3/3
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
