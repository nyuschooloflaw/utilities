<# 
  Webhook script to send notification via Slack on success or failure of
  certificate renewal.

  This script can only be run as a Certify the Web post-request script hook.
  https://docs.certifytheweb.com/docs/script-hooks.html
  https://github.com/webprofusion/certify

  Version 1.0.1
#>


# Get results object from Certify the Web
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


Write-Log "Information" "Begin Slack notify."


# Check script parameters, if empty log it and exit.
if (-not $result) {
  Write-Log "Error" "Missing parameters from CertifyTheWeb.  Cannot continue."
  Return
}


# Let's only alert on failure
if ($result.IsSuccess) {
  Write-Log "Information" "Certificate renewal succeeded.  Exiting without sending Slack notification."
  Return
}


# Set parameters for API call to Slack
$contentType = "application/json"
$uri = "https://hooks.slack.com/services/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"

# Conditional message content based on success or failure
if ($result.IsSuccess) {
   $successText = "Succeeded"
   $attachColor = "good"      # Slack colors: good, warning, danger
}
else {
   $successText = "Failed"
   $attachColor = "danger"
}

# More message content
$attachFallback = "Certificate renewal " + $successText + " for " + $result.ManagedItem.Name + " - " + $result.ManagedItem.RequestConfig.PrimaryDomain + " with the reason " + $result.message
$attachMessageValue = $result.message

# Build message body as a PowerShell array
$arrayBody = @{
   attachments = @(
      @{
         fallback = $attachFallback
         pretext = "Certificate renewal attempted for " + $result.ManagedItem.Name + "."
         color = $attachColor
         fields = @(
            @{
               title = "Renewal status"
               value = $successText
               short = "true"
            },
            @{
               title = "Domain"
               value = $result.ManagedItem.RequestConfig.PrimaryDomain
               short = "true"
            },
            @{
               title = "Message"
               value = $attachMessageValue
            }
         )
      }  
   )
}

# Convert message body from PowerShell array to JSON
$jsonBody = ConvertTo-Json -Depth 4 $arrayBody

# Execute HTTP POST API call
$webhookResult = Invoke-WebRequest -UseBasicParsing -URI $uri -Method 'POST' -Body $jsonBody

# Write results to log
Write-Log "Information" "HTTP POST attempted.  Result: $webhookResult"

Write-Log "Information" "Completed Slack notify." 0

Return
