######################################################################################################################################################
# Include required function libs:
######################################################################################################################################################
# These included files depend on each other and on globals defined here, so removing any of them or changing their order is likely to cause problems:
# they are just being used to keep the functions organized instead of having one huge file, not to make dependency management resilient.
#=====================================================================================================================================================
$libPaths = @(
    "config.ps1",
    "lib\utility-funs.ps1",
    "lib\dicom-funs.ps1",
    "lib\stage-1.ps1",
    "lib\stage-2.ps1",
    "lib\stage-3.ps1"
)
#=====================================================================================================================================================
foreach ($scriptPath in $libPaths) {
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $scriptPath

    if (Test-Path -Path $fullPath) {
        . $fullPath
    } else {
        Write-Error "lib file not found: $fullPath"
        
        Exit
    }
}
######################################################################################################################################################



######################################################################################################################################################
# Generate some directory paths. The user could put $global:incomingStoredItemsDirPath outside of $global:cacheDirBasePath without breaking things if
# they felt like it.
######################################################################################################################################################
# Stored items and their sentinels:
$global:queuedStoredItemsDirName    = "queued-stored-items"
$global:processedStoredItemsDirName = "processed-stored-items"
$global:rejectedStoredItemsDirName  = "rejected-stored-items"
# Move request tickets:
$global:queuedStudyMovesDirName     = "queued-study-moves"
$global:processedStudyMovesDirName  = "processed-study-moves"
$global:noResultsStoredItemsDirName = "no-results-stored-items"

#=====================================================================================================================================================
# Stored items and their sentinels:
$global:queuedStoredItemsDirPath    = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:queuedStoredItemsDirName
$global:processedStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:processedStoredItemsDirName
$global:rejectedStoredItemsDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:rejectedStoredItemsDirName
$global:noResultsStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:noResultsStoredItemsDirName

# Move request tickets:
$global:queuedStudyMovesDirPath     = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:queuedStudyMovesDirName
$global:processedStudyMovesDirPath  = Join-Path -Path $global:cacheDirBasePath -ChildPath $global:processedStudyMovesDirName
######################################################################################################################################################


######################################################################################################################################################
# Include FoDicomCmdlets DLL:
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
. (Join-Path -Path $PSScriptRoot -ChildPath "config.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\utility-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\dicom-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\stage-1.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\stage-2.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\stage-3.ps1")
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
Require-DirectoryExists -DirectoryPath $global:noResultsStoredItemsDirPath -CreateIfNotExists $true

# Move request tickets:
Require-DirectoryExists -DirectoryPath $global:queuedStudyMovesDirPath     -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $global:processedStudyMovesDirPath  -CreateIfNotExists $true
######################################################################################################################################################


######################################################################################################################################################
# Main:
######################################################################################################################################################
do {
    Do-Stage1 # examine incoming stored files and enqueue them if not already processed.
    Do-Stage2 # examine queued stored files, find studies for the patient create move requests for them if not already moved.
    Do-Stage3 # examine queued move requests and move those studies.

    ##################################################################################################################################################
    # All stagees complete, maybe sleep and loop, otherwise fall through and exit.
    ##################################################################################################################################################
    if ($global:sleepSeconds -gt 0) {
        Write-Indented " " # Just print a newline for output readability.
        Write-Indented "Sleeping $($global:sleepSeconds) seconds..." -NoNewLine
        Start-Sleep -Seconds $global:sleepSeconds
        Write-Host " done."
    }
    ##################################################################################################################################################
} while ($global:sleepSeconds -gt 0)#
######################################################################################################################################################
Write-Indented " " # Just print a newline for output readability.
Write-Indented "Done."
