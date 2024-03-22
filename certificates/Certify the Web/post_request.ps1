<# 
  Script to call other post-request scripts.

  Execute all PowerShell scripts in current directory with $results parameters
  passed from CertifyTheWeb.

  This script can only be run as a Certify the Web post-request script hook.
  https://docs.certifytheweb.com/docs/script-hooks.html
  https://github.com/webprofusion/certify

  Version 1.0.0
#>


# Get certificate renewal results from Certify the Web.
param($result)

# Constants
$EVENT_LOG_PATH = "C:\ProgramData\Certify\logs\"
$EVENT_LOG_NAME = "Application"
$EVENT_LOG_SOURCE = $MyInvocation.MyCommand.Name


#######################################
# Write an event to the Windows Event Log or a log file.
# Defaults to Windows Event Log.  Set $EVENT_LOG_PATH to a directory for a log
# file to instead write to a log file with the name of "$EVENT_LOG_SOURCE.log".
# Globals:
#   $EVENT_LOG_PATH
#   $EVENT_LOG_NAME
#   $EVENT_LOG_SOURCE
# Arguments:
#   $entryType = {Information, Warning, Error}
#   $message = any string
#   $eventLogID
# Returns:
#   None
#######################################
function Write-Log {
  # Get parameters.
  param($entryType, $message, [INT]$eventLogID=1)
  
  # Build array of parameters.
  $eventLogParameters = @{
    'LogName'   = $EVENT_LOG_NAME
    'Source'    = $EVENT_LOG_SOURCE
    'EventID'   = $eventLogID
    'EntryType' = $entryType
    'Message'   = $message
  }

  # Write log entry.
  if ( ($EVENT_LOG_PATH -eq $null) -or ($EVENT_LOG_PATH -eq '') ) {
    ### Use Windows Event Log.
    # Create source if it does not exist.
    if ([System.Diagnostics.EventLog]::SourceExists($EVENT_LOG_SOURCE) -eq $FALSE) {
      New-EventLog -LogName $EVENT_LOG_NAME -Source $EVENT_LOG_SOURCE
    }
    # Write to the Windows Event Log.
    Write-EventLog @eventLogParameters
  }
  else {
    ### Use log file.
    $EVENT_LOG_FILE = "$($EVENT_LOG_PATH.trim('\'))\$EVENT_LOG_SOURCE.log"
    $timestamp = Get-Date -Date (Get-Date).ToUniversalTime() `
      -UFormat "%Y-%m-%d %T UTC"
    $eventLogString = "$timestamp [$entryType] [$eventLogID] $message"
    # Write to log file.
    $eventLogString | Out-File -FilePath $EVENT_LOG_FILE -Append
    Clear-Variable timestamp
  }
}


Write-Log "Information" "Begin Post-Request script."


# Check script parameters, if empty log it and continue.
if (-not $result) {
  Write-Log "Warning" "Missing parameters from CertifyTheWeb."
}


# Get all scripts in current directory except this script.
$scriptPath = Split-Path $MyInvocation.MyCommand.Definition -Parent
$scriptName = $MyInvocation.MyCommand.Name
$scripts = Get-ChildItem -Path $scriptPath -Exclude $scriptName

# Loop through each script file and execute with same parameters.
ForEach ($script in $scripts) {
  Write-Log "Information" "Execute $script."
  & $script.FullName @result
}


Write-Log "Information" "Completed Post-Request script." 0

# Exit
