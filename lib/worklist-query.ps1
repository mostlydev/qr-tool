#################################################################################################################################################
# DICOM Modality Worklist Query Module
# This module implements periodic querying of DICOM Modality Worklist (MWL) endpoints,
# caches seen items, creates incoming stored items, and prefetches patient images.
#################################################################################################################################################

# Import required modules - these should already be loaded by the main script
# but we include safety checks in case this module is loaded independently

#################################################################################################################################################
# Function to query the DICOM Modality Worklist
#################################################################################################################################################
function Get-DicomWorklist {
    param()

    Write-LogInfo "Querying DICOM Modality Worklist at $($global:WorklistEndpointHost):$($global:WorklistEndpointPort)"

    try {
        # Execute DICOM C-FIND request for Modality Worklist with retry mechanism
        $worklistResponses = Invoke-WithRetry -ScriptBlock {
            Write-LogDebug "Creating C-FIND request for Modality Worklist (MWL)"
            
            # Prepare parameters for the Get-ModalityWorklist cmdlet
            $worklistParams = @{
                MyAE = $global:myAE
                WorklistServerAE = $global:WorklistEndpointAETitle
                WorklistServerHost = $global:WorklistEndpointHost
                WorklistServerPort = $global:WorklistEndpointPort
            }
            
            # Add optional filters if configured
            if ($null -ne $global:WorklistModalityFilter -and $global:WorklistModalityFilter -ne "") {
                $worklistParams.Modality = $global:WorklistModalityFilter
                Write-LogDebug "Applying modality filter: $($global:WorklistModalityFilter)"
            }
            
            if ($null -ne $global:WorklistScheduledDateFilter -and $global:WorklistScheduledDateFilter -ne "") {
                $worklistParams.ScheduledDate = $global:WorklistScheduledDateFilter
                Write-LogDebug "Applying scheduled date filter: $($global:WorklistScheduledDateFilter)"
            }
            
            Write-LogDebug "Executing C-FIND request to $($global:WorklistEndpointAETitle)"
            
            # Execute the worklist query using the new FoDicomCmdlet
            $responses = Get-ModalityWorklist @worklistParams
            
            # Validate that we got a valid response
            if ($null -eq $responses) {
                throw "Worklist query returned null result"
            }
            
            Write-LogDebug "Worklist query completed. Received $($responses.Count) responses"
            return $responses
        } -MaxRetries $global:RetryDicomQueryMaxRetries -RetryDelayMs $global:RetryDicomQueryDelayMs -OperationName "DICOM Worklist Query"

        # Process the DICOM responses to extract worklist items
        $worklistItems = @()
        
        foreach ($response in $worklistResponses) {
            if ($response -and $response.Dataset -and ($response.Status.State -eq "Success" -or $response.Status.State -eq "Pending")) {
                try {
                    # Extract basic patient and procedure information
                    $patientName = Get-DicomTagString -Dataset $response.Dataset -Tag ([Dicom.DicomTag]::PatientName) -DefaultValue "UNKNOWN_NAME"
                    $patientId = Get-DicomTagString -Dataset $response.Dataset -Tag ([Dicom.DicomTag]::PatientID) -DefaultValue "UNKNOWN_PATIENT"
                    $patientBirthDate = Get-DicomTagString -Dataset $response.Dataset -Tag ([Dicom.DicomTag]::PatientBirthDate) -DefaultValue ""
                    $accessionNumber = Get-DicomTagString -Dataset $response.Dataset -Tag ([Dicom.DicomTag]::AccessionNumber) -DefaultValue "UNKNOWN_ACCESSION"
                    $studyInstanceUID = Get-DicomTagString -Dataset $response.Dataset -Tag ([Dicom.DicomTag]::StudyInstanceUID) -DefaultValue ""
                    
                    # Extract information from Scheduled Procedure Step Sequence
                    $modality = ""
                    $scheduledProcedureStepId = ""
                    $scheduledDateTime = ""
                    $scheduledStationAE = ""
                    
                    if ($response.Dataset.Contains([Dicom.DicomTag]::ScheduledProcedureStepSequence)) {
                        $scheduledSequence = $response.Dataset.GetSequence([Dicom.DicomTag]::ScheduledProcedureStepSequence)
                        if ($scheduledSequence.Items.Count -gt 0) {
                            $firstItem = $scheduledSequence.Items[0]
                            $modality = Get-DicomTagString -Dataset $firstItem -Tag ([Dicom.DicomTag]::Modality) -DefaultValue ""
                            $scheduledProcedureStepId = Get-DicomTagString -Dataset $firstItem -Tag ([Dicom.DicomTag]::ScheduledProcedureStepID) -DefaultValue ""
                            $scheduledDate = Get-DicomTagString -Dataset $firstItem -Tag ([Dicom.DicomTag]::ScheduledProcedureStepStartDate) -DefaultValue ""
                            $scheduledTime = Get-DicomTagString -Dataset $firstItem -Tag ([Dicom.DicomTag]::ScheduledProcedureStepStartTime) -DefaultValue ""
                            $scheduledDateTime = "$scheduledDate $scheduledTime".Trim()
                            $scheduledStationAE = Get-DicomTagString -Dataset $firstItem -Tag ([Dicom.DicomTag]::ScheduledStationAETitle) -DefaultValue ""
                        }
                    }
                    
                    # Create worklist item object
                    $worklistItem = New-Object PSObject -Property @{
                        PatientName = $patientName
                        PatientId = $patientId
                        PatientBirthDate = $patientBirthDate
                        AccessionNumber = $accessionNumber
                        StudyInstanceUID = $studyInstanceUID
                        Modality = $modality
                        ScheduledProcedureStepId = $scheduledProcedureStepId
                        ScheduledDateTime = $scheduledDateTime
                        ScheduledStationAE = $scheduledStationAE
                        OriginalDataset = $response.Dataset
                    }
                    
                    $worklistItems += $worklistItem
                    Write-LogDebug "Processed worklist item: Patient=$patientName, Modality=$modality, Accession=$accessionNumber"
                }
                catch {
                    Write-LogError "Error processing worklist response: $_"
                }
            }
            elseif ($response -and $response.Status.State -ne "Success" -and $response.Status.State -ne "Pending") {
                Write-LogWarn "Worklist response with unexpected status: $($response.Status.State)"
            }
        }

        Write-LogInfo "Successfully queried worklist. Retrieved $($worklistItems.Count) items"
        return $worklistItems
    }
    catch {
        Write-LogError "Error querying DICOM Modality Worklist: $_"
        return $null
    }
}

#################################################################################################################################################
# Function to ensure directory exists (using existing utility pattern)
#################################################################################################################################################
function Test-AndCreateDirectory {
    param([string]$DirectoryPath)
    
    if (-not (Test-Path -Path $DirectoryPath)) {
        Write-LogDebug "Creating directory: $DirectoryPath"
        $null = New-Item -ItemType Directory -Path $DirectoryPath -Force
    }
}

#################################################################################################################################################
# Function to compare worklist items with local cache and identify new orders
#################################################################################################################################################
function Get-NewWorklistItems {
    param(
        [Parameter(Mandatory=$true)]
        [array]$WorklistItems
    )

    # Ensure the worklist cache directory exists
    $worklistCachePath = Join-Path $global:cacheDirPath "worklist-cache"
    Test-AndCreateDirectory $worklistCachePath

    $newItems = @()

    foreach ($item in $WorklistItems) {
        # Extract DICOM tag values from processed worklist item
        $patientId = if ($item -and $item.PatientId) { $item.PatientId } else { "UNKNOWN_PATIENT" }
        $accessionNumber = if ($item -and $item.AccessionNumber) { $item.AccessionNumber } else { "UNKNOWN_ACCESSION" }
        $scheduledProcedureStepId = if ($item -and $item.ScheduledProcedureStepId) { $item.ScheduledProcedureStepId } else { "" }

        # Create a unique identifier for the worklist item
        $itemId = "$patientId-$accessionNumber-$scheduledProcedureStepId"
        $itemCachePath = Join-Path $worklistCachePath "$itemId.json"

        # Check if this item is already in our cache
        if (-not (Test-Path $itemCachePath)) {
            # This is a new worklist item
            $newItems += $item
            Write-LogInfo "Found new worklist item: $itemId"

            # Save the item to cache
            $itemData = @{
                "PatientId" = $patientId
                "PatientName" = if ($item -and $item.PatientName) { $item.PatientName } else { "UNKNOWN_NAME" }
                "AccessionNumber" = $accessionNumber
                "ScheduledProcedureStepId" = $scheduledProcedureStepId
                "DiscoveryTime" = (Get-Date).ToString("o")
            }

            $itemData | ConvertTo-Json | Set-Content -Path $itemCachePath
            Write-LogDebug "Cached worklist item: $itemId"
        }
    }

    Write-LogInfo "Identified $($newItems.Count) new worklist items out of $($WorklistItems.Count) total items"
    return $newItems
}

#################################################################################################################################################
# Function to create incoming-stored-item records for new worklist items
#################################################################################################################################################
function New-IncomingStoredItems {
    param(
        [Parameter(Mandatory=$true)]
        [array]$NewWorklistItems
    )

    foreach ($item in $NewWorklistItems) {
        # Extract values from worklist item
        $patientId = if ($item -and $item.PatientId) { $item.PatientId } else { "UNKNOWN_PATIENT" }
        $patientName = if ($item -and $item.PatientName) { $item.PatientName } else { "UNKNOWN_NAME" }
        $accessionNumber = if ($item -and $item.AccessionNumber) { $item.AccessionNumber } else { "UNKNOWN_ACCESSION" }
        $scheduledProcedureStepId = if ($item -and $item.ScheduledProcedureStepId) { $item.ScheduledProcedureStepId } else { "" }

        # Create a unique filename for the incoming stored item
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $filename = "worklist-$patientId-$accessionNumber-$timestamp.dcm"
        $filePath = Join-Path $global:incomingStoredItemsDirPath $filename

        # Use the original DICOM dataset from the worklist response
        if ($item.OriginalDataset) {
            try {
                # Add required SOPClassUID for Modality Worklist Information Model directly to original dataset
                if (-not $item.OriginalDataset.Contains([Dicom.DicomTag]::SOPClassUID)) {
                    $item.OriginalDataset.AddOrUpdate([Dicom.DicomTag]::SOPClassUID, "1.2.840.10008.5.1.4.31")
                }
                
                # Add SOPInstanceUID if missing
                if (-not $item.OriginalDataset.Contains([Dicom.DicomTag]::SOPInstanceUID)) {
                    $sopInstanceUid = [Dicom.DicomUID]::Generate().UID
                    $item.OriginalDataset.AddOrUpdate([Dicom.DicomTag]::SOPInstanceUID, $sopInstanceUid)
                }
                
                # Create a new DICOM file with the dataset
                $dicomFile = New-Object Dicom.DicomFile($item.OriginalDataset)
                $dicomFile.Save($filePath)
                Write-LogInfo "Created DICOM file for worklist entry: $filename"
            }
            catch {
                Write-LogError "Error saving DICOM file for worklist entry: $_"
            }
        }
        else {
            Write-LogWarn "No original dataset available for worklist item: $patientId-$accessionNumber"
        }
    }
}

#################################################################################################################################################
# Function to prefetch patient images
#################################################################################################################################################
function Get-PatientImages {
    param(
        [Parameter(Mandatory=$true)]
        [array]$NewWorklistItems
    )

    foreach ($item in $NewWorklistItems) {
        $patientId = if ($item -and $item.PatientId) { $item.PatientId } else { "UNKNOWN_PATIENT" }
        $patientName = if ($item -and $item.PatientName) { $item.PatientName } else { "UNKNOWN_NAME" }

        Write-LogInfo "Prefetching images for patient: $patientName (ID: $patientId)"

        try {
            # Query for patient's prior studies using QIDO-RS
            $qidoUrl = "$($global:QidoServiceUrl)/studies?PatientID=$patientId"
            
            $studies = Invoke-WithRetry -ScriptBlock {
                Invoke-RestMethod -Uri $qidoUrl -Method Get -Headers @{ "Accept" = "application/json" }
            } -MaxRetries 3 -RetryDelayMs 2000

            if ($studies -and $studies.Count -gt 0) {
                Write-LogInfo "Found $($studies.Count) prior studies for patient $patientId"

                # Apply filtering criteria
                $filteredStudies = @()
                foreach ($study in $studies) {
                    $includeStudy = $true

                    # Filter by date if configured
                    if ($global:PrefetchFilterCriteria.daysPrior) {
                        try {
                            $studyDateValue = $study."00080020".Value
                            if ($studyDateValue) {
                                $studyDate = [DateTime]::ParseExact($studyDateValue, "yyyyMMdd", $null)
                                $cutoffDate = (Get-Date).AddDays(-$global:PrefetchFilterCriteria.daysPrior)

                                if ($studyDate -lt $cutoffDate) {
                                    $includeStudy = $false
                                    Write-LogDebug "Excluding study from $studyDateValue (older than $($global:PrefetchFilterCriteria.daysPrior) days)"
                                }
                            }
                        }
                        catch {
                            Write-LogError "Error parsing study date for filtering: $_"
                        }
                    }

                    # Filter by modality if configured
                    if ($includeStudy -and $global:PrefetchFilterCriteria.modalities) {
                        $studyModality = $study."00080060".Value
                        if ($studyModality -and -not ($global:PrefetchFilterCriteria.modalities -contains $studyModality)) {
                            $includeStudy = $false
                            Write-LogDebug "Excluding study with modality $studyModality (not in allowed list)"
                        }
                    }

                    if ($includeStudy) {
                        $filteredStudies += $study
                    }
                }

                Write-LogInfo "$($filteredStudies.Count) studies match prefetch criteria for patient $patientId"

                if ($filteredStudies.Count -gt 0) {
                    # Create prefetch cache directory for this patient
                    $patientPrefetchPath = Join-Path $global:PrefetchCachePath $patientId
                    Test-AndCreateDirectory $patientPrefetchPath

                    # Retrieve each filtered study
                    foreach ($study in $filteredStudies) {
                        $studyInstanceUid = $study."0020000D".Value
                        Write-LogDebug "Processing study: $studyInstanceUid"
                        
                        $studyPrefetchPath = Join-Path $patientPrefetchPath $studyInstanceUid
                        Test-AndCreateDirectory $studyPrefetchPath

                        try {
                            # Get series for this study
                            $seriesUrl = "$($global:QidoServiceUrl)/studies/$studyInstanceUid/series"
                            $seriesList = Invoke-WithRetry -ScriptBlock {
                                Invoke-RestMethod -Uri $seriesUrl -Method Get -Headers @{ "Accept" = "application/json" }
                            } -MaxRetries 3 -RetryDelayMs 2000

                            foreach ($series in $seriesList) {
                                $seriesInstanceUid = $series."0020000E".Value
                                $seriesPrefetchPath = Join-Path $studyPrefetchPath $seriesInstanceUid
                                Test-AndCreateDirectory $seriesPrefetchPath

                                # Get instances for this series
                                $instancesUrl = "$($global:QidoServiceUrl)/studies/$studyInstanceUid/series/$seriesInstanceUid/instances"
                                $instances = Invoke-WithRetry -ScriptBlock {
                                    Invoke-RestMethod -Uri $instancesUrl -Method Get -Headers @{ "Accept" = "application/json" }
                                } -MaxRetries 3 -RetryDelayMs 2000

                                foreach ($instance in $instances) {
                                    $sopInstanceUid = $instance."00080018".Value
                                    $instanceFilePath = Join-Path $seriesPrefetchPath "$sopInstanceUid.dcm"

                                    # Skip if already downloaded
                                    if (-not (Test-Path $instanceFilePath)) {
                                        # Retrieve the DICOM instance using WADO-RS
                                        $wadoUrl = "$($global:WadoServiceUrl)/studies/$studyInstanceUid/series/$seriesInstanceUid/instances/$sopInstanceUid"

                                        Invoke-WithRetry -ScriptBlock {
                                            Invoke-WebRequest -Uri $wadoUrl -Method Get -Headers @{ "Accept" = "application/dicom" } -OutFile $instanceFilePath
                                        } -MaxRetries 3 -RetryDelayMs 2000

                                        Write-LogDebug "Downloaded instance $sopInstanceUid"
                                    }
                                }
                            }
                        }
                        catch {
                            Write-LogError "Error processing study ${studyInstanceUid}: ${_}"
                        }
                    }
                }
            }
            else {
                Write-LogInfo "No prior studies found for patient $patientId"
            }
        }
        catch {
            Write-LogError "Error prefetching images for patient ${patientId}: ${_}"
        }
    }
}

#################################################################################################################################################
# Main function to run the worklist query process
#################################################################################################################################################
function Start-WorklistQueryProcess {
    Write-LogInfo "Starting Worklist Query Process"

    # Query the worklist
    $worklistItems = Get-DicomWorklist

    if ($worklistItems -and $worklistItems.Count -gt 0) {
        Write-LogInfo "Retrieved $($worklistItems.Count) worklist items"

        # Identify new worklist items
        $newItems = Get-NewWorklistItems -WorklistItems $worklistItems

        if ($newItems -and $newItems.Count -gt 0) {
            Write-LogInfo "Found $($newItems.Count) new worklist items"

            # Create incoming stored items for tracking
            New-IncomingStoredItems -NewWorklistItems $newItems

            # Prefetch patient images if enabled
            if ($global:EnableImagePrefetch) {
                Get-PatientImages -NewWorklistItems $newItems
            }
            else {
                Write-LogInfo "Image prefetching is disabled"
            }
        }
        else {
            Write-LogInfo "No new worklist items found"
        }
    }
    else {
        Write-LogWarn "No worklist items retrieved or error occurred"
    }
}

#################################################################################################################################################
# Function to start the periodic worklist query
#################################################################################################################################################
function Start-PeriodicWorklistQuery {
    Write-LogInfo "Starting periodic worklist query service"
    Write-LogInfo "Query interval: $($global:WorklistQueryIntervalSeconds) seconds"

    while ($true) {
        try {
            Start-WorklistQueryProcess
        }
        catch {
            Write-LogError "Error in worklist query process: $_"
        }

        # Wait for the configured interval
        Write-LogInfo "Waiting $($global:WorklistQueryIntervalSeconds) seconds until next worklist query"
        Start-Sleep -Seconds $global:WorklistQueryIntervalSeconds
    }
}

#################################################################################################################################################