######################################################################################################################################################
# Globals meant to be used for configuration purposes, user may change as required:
######################################################################################################################################################
$global:myAE                     = "QR-TOOL"
#=====================================================================================================================================================
$global:qrServerAE               = "HOROS"
$global:qrServerHost             = "localhost"
$global:qrServerPort             = 2763
$global:qrDestinationAE          = "FLUXTEST1AB"
#=====================================================================================================================================================
$global:studyFindMonthsBack      = 60
$global:studyMoveFixedModality   = $null # "ZX"
# ^ if $null, studies whose modality matches the stored item's are c-found (and subsequently c-moved), otherwise studies with this modality are found
#   and moved.
#=====================================================================================================================================================
$global:sleepSeconds             = 3 # if greater than 0 script will loop, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds   = 3
$global:largeFileThreshholdBytes = 50000
$global:rejectByDeleting         = $true
######################################################################################################################################################
