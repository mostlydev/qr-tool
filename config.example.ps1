######################################################################################################################################################
# EXAMPLE CONFIGURATION FILE FOR QR-TOOL
# Copy this file to config.ps1 and modify the values according to your environment
######################################################################################################################################################
# Globals meant to be used for configuration purposes, user may change as required:
######################################################################################################################################################

#=====================================================================================================================================================
# DICOM Application Entity Configuration
#=====================================================================================================================================================
$global:myAE                       = "QR-TOOL"                    # Your Application Entity Title

#=====================================================================================================================================================
# DICOM Query/Retrieve Server Configuration
#=====================================================================================================================================================
$global:qrServerAE                 = "HOROS"                      # Target PACS AE Title
$global:qrServerHost               = "localhost"                  # Target PACS hostname/IP
$global:qrServerPort               = 2763                         # Target PACS port
$global:qrDestinationAE            = "FLUXTEST1AB"               # Destination AE for C-MOVE operations

#=====================================================================================================================================================
# Study Query Configuration
#=====================================================================================================================================================
$global:studyFindMonthsBack        = 60                          # How many months back to search for studies
$global:findAndMoveFixedModality   = $null                       # Fixed modality for C-FIND (null = use stored item's modality)
# ^ if $null, studies whose modality matches the stored item's are c-found (and subsequently c-moved), 
#   otherwise studies with this modality are found and moved.

#=====================================================================================================================================================
# Processing Behavior Configuration
#=====================================================================================================================================================
$global:sleepSeconds               = 0                           # Loop interval (0 = run once, >0 = continuous with sleep)
$global:mtimeThreshholdSeconds     = 3                          # Minimum file age before processing (seconds)
$global:largeFileThreshholdBytes   = 50000                      # Threshold for large files (pixel data stripping)
$global:rejectByDeleting           = $true                      # Delete rejected files vs moving them

#=====================================================================================================================================================
# Directory Configuration
#=====================================================================================================================================================
$global:cacheDirBasePath           = Join-Path -Path $PSScriptRoot -ChildPath "cache"
# ^ This directory must be writable as the script will create subdirectories in it and files within them.
$global:incomingStoredItemsDirPath = Join-Path -Path $global:cacheDirBasePath -ChildPath "incoming-stored-items"
# ^ The user could place this folder elsewhere. It must be writable and must exist: it will not be created automatically by the script.

#=====================================================================================================================================================
# Worklist Query Configuration
#=====================================================================================================================================================
$global:WorklistEndpointAETitle     = "FLUX_WORKLIST"              # AE Title of the worklist SCP
$global:WorklistEndpointHost        = "worklist.example.com"       # Hostname/IP of the worklist SCP
$global:WorklistEndpointPort        = 1070                         # Port of the worklist SCP
$global:WorklistQueryIntervalSeconds = 300                         # Query interval in seconds (5 minutes)
$global:EnableImagePrefetch         = $true                        # Enable automatic image prefetching for new worklist items
$global:WorklistCacheCleanupDays    = 30                          # Days to keep worklist cache entries
$global:WorklistQueryTimeout        = 30                          # Timeout for worklist queries in seconds
$global:WorklistModalityFilter      = $null                        # Modality filter for worklist queries (null = all modalities, e.g., "MR", "CT")
$global:WorklistScheduledDateFilter = $null                        # Date filter for worklist queries (YYYYMMDD format, null = all dates)

#=====================================================================================================================================================
# QIDO/WADO Configuration for Image Prefetching
#=====================================================================================================================================================
$global:QidoServiceUrl              = "http://pacs.example.com/dicom-web"    # QIDO-RS service URL for study queries
$global:WadoServiceUrl              = "http://pacs.example.com/dicom-web"    # WADO-RS service URL for image retrieval
$global:PrefetchCachePath           = Join-Path -Path $global:cacheDirBasePath -ChildPath "prefetch-cache"
$global:PrefetchFilterCriteria      = @{
    "daysPrior" = 365                                              # Maximum age of studies to prefetch (days)
    "modalities" = @("CT", "MR", "XR", "US", "CR", "DX")          # Modalities to prefetch (empty array = all)
    "maxStudiesPerPatient" = 10                                    # Maximum number of studies to prefetch per patient
    "maxInstancesPerSeries" = 100                                  # Maximum instances per series to download
}
$global:PrefetchHttpTimeout         = 120                         # HTTP timeout for DICOM web requests (seconds)
$global:PrefetchConcurrentDownloads = 3                          # Number of concurrent downloads for prefetching
$global:PrefetchCacheCleanupDays    = 90                         # Days to keep prefetched images

#=====================================================================================================================================================
# Retry Mechanism Configuration
#=====================================================================================================================================================
$global:RetryDefaultMaxRetries      = 3                          # Default maximum number of retries
$global:RetryDefaultDelayMs         = 2000                       # Default retry delay in milliseconds
$global:RetryDicomMoveMaxRetries     = 5                         # Max retries for DICOM C-MOVE operations
$global:RetryDicomMoveDelayMs        = 5000                      # Retry delay for DICOM C-MOVE operations (5 seconds)
$global:RetryDicomQueryMaxRetries    = 3                         # Max retries for DICOM C-FIND operations
$global:RetryDicomQueryDelayMs       = 2000                      # Retry delay for DICOM C-FIND operations (2 seconds)
$global:RetryHttpMaxRetries          = 3                         # Max retries for HTTP requests
$global:RetryHttpDelayMs             = 1000                      # Retry delay for HTTP requests (1 second)

#=====================================================================================================================================================
# Logging Configuration
#=====================================================================================================================================================
$global:logLevel                    = "INFO"                     # Log level: DEBUG, INFO, WARN, ERROR, FATAL
$global:logToFile                   = $true                      # Enable logging to file
$global:logToConsole                = $true                      # Enable logging to console
$global:logFileRotationDays         = 7                         # Days to keep log files
$global:logMaxFileSizeMB             = 10                        # Maximum log file size in MB before rotation
$global:logDateFormat               = "yyyy-MM-dd HH:mm:ss"      # Log timestamp format

# Derived paths (usually don't need to change these)
$global:cacheDirPath                = $global:cacheDirBasePath

######################################################################################################################################################
# CONFIGURATION EXAMPLES AND NOTES
######################################################################################################################################################

<#
EXAMPLE CONFIGURATIONS FOR DIFFERENT SCENARIOS:

1. DEVELOPMENT/TESTING ENVIRONMENT:
   $global:logLevel = "DEBUG"
   $global:WorklistQueryIntervalSeconds = 60    # Check every minute
   $global:EnableImagePrefetch = $false         # Disable for faster testing
   $global:sleepSeconds = 10                    # Quick processing loop

2. PRODUCTION ENVIRONMENT:
   $global:logLevel = "INFO" 
   $global:WorklistQueryIntervalSeconds = 300   # Check every 5 minutes
   $global:EnableImagePrefetch = $true          # Enable prefetching
   $global:sleepSeconds = 0                     # Run once or use scheduled tasks
   $global:logFileRotationDays = 30             # Keep logs longer

3. HIGH VOLUME ENVIRONMENT:
   $global:PrefetchConcurrentDownloads = 5     # More concurrent downloads
   $global:PrefetchFilterCriteria = @{
       "daysPrior" = 30                         # Only recent studies
       "modalities" = @("CT", "MR")             # Limit to important modalities
       "maxStudiesPerPatient" = 5               # Limit studies per patient
   }
   $global:RetryDicomMoveMaxRetries = 3         # Fewer retries for faster processing

4. NETWORK-CONSTRAINED ENVIRONMENT:
   $global:RetryDicomMoveDelayMs = 10000        # Longer delays between retries
   $global:PrefetchHttpTimeout = 300            # Longer HTTP timeouts
   $global:PrefetchConcurrentDownloads = 1     # Sequential downloads only

DICOM NETWORK CONFIGURATION NOTES:
- Ensure your PACS accepts connections from $global:myAE
- Verify $global:qrServerAE, $global:qrServerHost, and $global:qrServerPort are correct
- Test DICOM connectivity with tools like dcm4che's findscu/movescu before running QR-Tool
- Check firewall settings for DICOM ports

WORKLIST CONFIGURATION NOTES:
- $global:WorklistEndpointAETitle must match the worklist SCP's AE Title
- Ensure the worklist SCP accepts C-FIND requests from $global:myAE
- Test worklist connectivity independently before enabling

PREFETCH CONFIGURATION NOTES:
- QIDO/WADO URLs should point to DICOMweb endpoints
- Ensure proper authentication if required by your PACS
- Monitor disk space usage with prefetching enabled
- Adjust $global:PrefetchFilterCriteria to control what gets prefetched

LOGGING NOTES:
- DEBUG level can generate large log files in busy environments
- Set $global:logToConsole = $false for service/background operation
- Adjust $global:logFileRotationDays based on your disk space and compliance requirements
#>

######################################################################################################################################################