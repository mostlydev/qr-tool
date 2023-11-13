######################################################################################################################################################
# Include FoDicomCmdlets:
######################################################################################################################################################
$global:foDicomCmdletsDLLPath = Join-Path -Path $PSScriptRoot -ChildPath "FoDicomCmdlets\bin\Release\FoDicomCmdlets.dll"
#=====================================================================================================================================================
Import-Module $global:foDicomCmdletsDLLPath
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
######################################################################################################################################################


######################################################################################################################################################
# Require some directories. The user could put $global:incomingStoredItemsDirPath outside of $global:cacheDirBasePath without breaking things if they
# felt like it.
######################################################################################################################################################
$global:cacheDirBasePath            = Join-Path -Path $PSScriptRoot            -ChildPath "cache"
$global:incomingStoredItemsDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath "incoming-stored-items"
$global:queuedStoredItemsDirPath    = Join-Path -Path $global:cacheDirBasePath -ChildPath "queued-stored-items"
$global:processedStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath "processed-stored-items"
$global:rejectedStoredItemsDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath "rejected-stored-items"
#=====================================================================================================================================================
Require-DirectoryExists -DirectoryPath $global:cacheDirBasePath            # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $global:incomingStoredItemsDirPath  # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $global:queuedStoredItemsDirPath    -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:processedStoredItemsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:rejectedStoredItemsDirPath  -CreateIfNotExists $true
######################################################################################################################################################


######################################################################################################################################################
# Set up packages (well, just fo-dicom presently):
######################################################################################################################################################
$global:packagesDirPath        = Join-Path -Path $PSScriptRoot           -ChildPath "packages"
$global:foDicomName            = "fo-dicom.Desktop"
$global:foDicomVersion         = "4.0.8"
$global:foDicomDirPath         = Join-Path -Path $global:packagesDirPath -ChildPath "$global:foDicomName.$global:foDicomVersion"
$global:foDicomExpectedDllPath = Join-Path -Path $global:foDicomDirPath  -ChildPath "lib\net45\Dicom.Core.dll"
#=====================================================================================================================================================
Require-NuGetPackage `
-PackageName $global:foDicomName `
-PackageVersion $global:foDicomVersion `
-ExpectedDllPath $global:foDicomExpectedDllPath `
-DestinationDir $global:packagesDirPath
#=====================================================================================================================================================
$null = [Reflection.Assembly]::LoadFile($global:foDicomExpectedDllPath)
######################################################################################################################################################


######################################################################################################################################################
# Main:
######################################################################################################################################################
do {
    ##################################################################################################################################################
    # Stage #1/2: Examine files in $global:incomingStoredItemsDirPath and either accept them by moving them to $global:queuedStoredItemsDirPath or
    #            reject them.
    ##################################################################################################################################################
    
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
            
            $studyHash                        = GetHashFrom-StudyTags -StudyTags $tags 
            $possibleQueuedStoredItemsPath    = Join-Path -Path $global:queuedStoredItemsDirPath    -ChildPath "$studyHash.dcm"
            $possibleProcessedStoredItemsPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath "$studyHash.dcm"

            $foundFile = $null

            if (Test-Path -Path $possibleQueuedStoredItemsPath) {
                $foundFile = $possibleQueuedStoredItemsPath
            } elseif (Test-Path -Path $possibleProcessedStoredItemsPath) {
                $foundFile = $possibleProcessedStoredItemsPath
            }

            if ($foundFile -eq $null) {                
                Write-Indented "Enqueuing $($file.FullName) as $possibleQueuedStoredItemspath."
                MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $possibleQueuedStoredItemsPath
            } else {
                Write-Indented "Item for hash $studyHash already exists in one of our directories as $foundFile, rejecting."
                Reject-File -File $file -RejectedDirPath $global:rejectedStoredItemsDirPath
            }
            
            Outdent
        } # foreach $file
        ##############################################################################################################################################

        Outdent
    } # Stage #1/2
    ##################################################################################################################################################

    ##################################################################################################################################################
    # Stage #2/2: Examine files in $global:queuedStoredItemsDirPath, issue move requests for them and then move them to $processedStoredItemsPath.
    ##################################################################################################################################################

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
            # Move-StudyByStudyInstanceUID $tags.StudyInstanceUID
            Move-StudyByStudyInstanceUIDSync `
              -StudyInstanceUID $tags.StudyInstanceUID `
              -DestinationAE    $global:qrDestinationAE `
              -ServerHost       $global:qrServerHost `
              -ServerPort       $global:qrServerPort `
              -ServerAE         $global:qrServerAE
              -MyAE             $global:myAE `
            

            
            $processedStoredItemPath = Join-Path -Path $global:processedStoredItemsDirPath -ChildPath $file.Name

            Write-Indented "Moving $($file.FullName) to $processedStoredItemPath"
            Move-Item -Path $File.FullName -Destination $processedStoredItemPath
            
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
Write-Indented "Done."
