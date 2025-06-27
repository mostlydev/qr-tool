# Logging levels
$global:LogLevels = @{
    "DEBUG" = 0
    "INFO" = 1
    "WARN" = 2
    "ERROR" = 3
    "FATAL" = 4
}

# Current log level (default to INFO)
$global:CurrentLogLevel = $global:LogLevels["INFO"]

# Log file path
$global:LogFilePath = $null

# Function to set the log level
function Set-LogLevel {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level
    )

    $global:CurrentLogLevel = $global:LogLevels[$Level]
    Write-Log "Log level set to $Level" -Level "INFO"
}

# Function to set the log file path
function Set-LogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $global:LogFilePath = $Path

    # Create the log file if it doesn't exist
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    Write-Log "Log file set to $Path" -Level "INFO"
}

# Function to write a log message
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [switch]$NoConsole
    )

    # Check if the message should be logged based on the current log level
    if ($global:LogLevels[$Level] -ge $global:CurrentLogLevel) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"

        # Write to console if not suppressed
        if (-not $NoConsole) {
            $foregroundColor = switch ($Level) {
                "DEBUG" { "Gray" }
                "INFO" { "White" }
                "WARN" { "Yellow" }
                "ERROR" { "Red" }
                "FATAL" { "Red" }
                default { "White" }
            }

            Write-Host $logMessage -ForegroundColor $foregroundColor
        }

        # Write to log file if configured
        if ($null -ne $global:LogFilePath) {
            Add-Content -Path $global:LogFilePath -Value $logMessage
        }
    }
}

# Function to log an exception
function Write-Exception {
    param(
        [Parameter(Mandatory=$true)]
        $Exception,

        [Parameter(Mandatory=$false)]
        [string]$Message = "An exception occurred",

        [Parameter(Mandatory=$false)]
        [ValidateSet("WARN", "ERROR", "FATAL")]
        [string]$Level = "ERROR"
    )

    $exceptionMessage = "$Message`: $($Exception.Message)"
    Write-Log $exceptionMessage -Level $Level

    # Log stack trace at DEBUG level
    Write-Log "Stack Trace`: $($Exception.StackTrace)" -Level "DEBUG"

    # Log inner exception if present
    if ($null -ne $Exception.InnerException) {
        Write-Log "Inner Exception`: $($Exception.InnerException.Message)" -Level $Level
        Write-Log "Inner Stack Trace`: $($Exception.InnerException.StackTrace)" -Level "DEBUG"
    }
}

# Convenience functions for different log levels
function Write-LogError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log $Message -Level "ERROR"
}

function Write-LogWarn {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log $Message -Level "WARN"
}

function Write-LogInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log $Message -Level "INFO"
}

function Write-LogDebug {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Log $Message -Level "DEBUG"
}