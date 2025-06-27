######################################################################################################################################################
# Globals meant to be used for configuration purposes, user may change as required:
######################################################################################################################################################
$global:myAE                       = "QR-TOOL"
#=====================================================================================================================================================
$global:qrServerAE                 = "HOROS"
$global:qrServerHost               = "localhost"
$global:qrServerPort               = 2763
$global:qrDestinationAE            = "FLUXTEST1AB"
#=====================================================================================================================================================
$global:studyFindMonthsBack        = 60
$global:findAndMoveFixedModality   = $null # "ZX"
# ^ if $null, studies whose modality matches the stored item's are c-found (and subsequently c-moved), otherwise studies with this modality are found
#   and moved.
#=====================================================================================================================================================
$global:sleepSeconds               = 0 # if greater than 0 script will loop, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds     = 3
$global:largeFileThreshholdBytes   = 50000
$global:rejectByDeleting           = $true
#=====================================================================================================================================================
$global:cacheDirBasePath           = Join-Path -Path $PSScriptRoot            -ChildPath "cache"
# ^ This directory must be writable as the script will create subdirectories in it and files within them.
$global:incomingStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath "incoming-stored-items"
# ^ The user could place this folder elsewhere. It must be writable and must exist: it will not be created automatically by the script.
######################################################################################################################################################
