# Function to execute an operation with retries
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory=$false)]
        [int]$RetryDelayMs = 1000,

        [Parameter(Mandatory=$false)]
        [scriptblock]$RetryCondition = { $false },

        [Parameter(Mandatory=$false)]
        [string]$OperationName = "Operation"
    )

    $retryCount = 0
    $success = $false
    $result = $null

    do {
        try {
            if ($retryCount -gt 0) {
                Write-LogInfo "Retry $retryCount/$MaxRetries for $OperationName"
                Start-Sleep -Milliseconds $RetryDelayMs
            }

            $result = & $ScriptBlock
            $success = $true
        } catch {
            $retryCount++
            $shouldRetry = ($retryCount -le $MaxRetries) -or (& $RetryCondition)

            if ($shouldRetry) {
                Write-LogWarn "$OperationName failed, will retry ($retryCount/$MaxRetries): $($_.Exception.Message)"
            } else {
                Write-Exception -Exception $_ -Message "$OperationName failed after $retryCount retries"
                throw
            }
        }
    } while (-not $success -and $retryCount -le $MaxRetries)

    if ($success) {
        if ($retryCount -gt 0) {
            Write-LogInfo "$OperationName succeeded after $retryCount retries"
        }
    }

    return $result
}

# Function to execute with exponential backoff retry
function Invoke-WithExponentialBackoff {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory=$false)]
        [int]$InitialDelayMs = 1000,

        [Parameter(Mandatory=$false)]
        [double]$BackoffMultiplier = 2.0,

        [Parameter(Mandatory=$false)]
        [int]$MaxDelayMs = 30000,

        [Parameter(Mandatory=$false)]
        [string]$OperationName = "Operation"
    )

    $retryCount = 0
    $success = $false
    $result = $null
    $currentDelay = $InitialDelayMs

    do {
        try {
            if ($retryCount -gt 0) {
                Write-LogInfo "Retry $retryCount/$MaxRetries for $OperationName (delay: $($currentDelay)ms)"
                Start-Sleep -Milliseconds $currentDelay
                
                # Calculate next delay with exponential backoff
                $currentDelay = [Math]::Min($currentDelay * $BackoffMultiplier, $MaxDelayMs)
            }

            $result = & $ScriptBlock
            $success = $true
        } catch {
            $retryCount++

            if ($retryCount -le $MaxRetries) {
                Write-LogWarn "$OperationName failed, will retry ($retryCount/$MaxRetries) with exponential backoff: $($_.Exception.Message)"
            } else {
                Write-Exception -Exception $_ -Message "$OperationName failed after $retryCount retries with exponential backoff"
                throw
            }
        }
    } while (-not $success -and $retryCount -le $MaxRetries)

    if ($success -and $retryCount -gt 0) {
        Write-LogInfo "$OperationName succeeded after $retryCount retries with exponential backoff"
    }

    return $result
}

# Function to retry with custom condition
function Invoke-WithConditionalRetry {
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory=$true)]
        [scriptblock]$ShouldRetryCondition,

        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory=$false)]
        [int]$RetryDelayMs = 1000,

        [Parameter(Mandatory=$false)]
        [string]$OperationName = "Operation"
    )

    $retryCount = 0
    $success = $false
    $result = $null

    do {
        try {
            if ($retryCount -gt 0) {
                Write-LogInfo "Conditional retry $retryCount/$MaxRetries for $OperationName"
                Start-Sleep -Milliseconds $RetryDelayMs
            }

            $result = & $ScriptBlock
            $success = $true
        } catch {
            $retryCount++
            $shouldRetry = ($retryCount -le $MaxRetries) -and (& $ShouldRetryCondition $_)

            if ($shouldRetry) {
                Write-LogWarn "$OperationName failed, will retry ($retryCount/$MaxRetries): $($_.Exception.Message)"
            } else {
                if ($retryCount -gt $MaxRetries) {
                    Write-Exception -Exception $_ -Message "$OperationName failed after $retryCount retries (max retries exceeded)"
                } else {
                    Write-Exception -Exception $_ -Message "$OperationName failed and retry condition not met"
                }
                throw
            }
        }
    } while (-not $success -and $retryCount -le $MaxRetries)

    if ($success -and $retryCount -gt 0) {
        Write-LogInfo "$OperationName succeeded after $retryCount conditional retries"
    }

    return $result
}