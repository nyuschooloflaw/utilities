<#
  Bind certificate to Filemaker Server.

  Based on GetSSL.ps1 v0.9 by David Nahodyl, Blue Feather

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
$FMS_PATH = 'C:\Program Files\FileMaker\FileMaker Server\'
$FMS_DB_PATH = "$FMS_PATH\Database Server\"


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


Write-Log "Information" "Begin update of Filemaker Server certificate binding."


# Check script parameters, if empty log it and exit.
if (-not $result) {
  Write-Log "Error" "Missing parameters from CertifyTheWeb.  Cannot continue."
  Return
}


# Check if the certificate was renewed.
# If the renewal failed there's nothing to do.  Log the result and exit.
if (-not $result.IsSuccess) {
  $resultMessage = $result.Message
  Write-Log "Error" "Certify the Web failed to renew the certificate with the following reason: $resultMessage.  Cannot Continue."
  Return
}

#set "OPENSSL_CONF=C:\Program Files\OpenSSL-Win64\bin\openssl.cfg"


# Get path of certificate
# e.g. C:\ProgramData\Certify\certes\assets\pfx\878d3f2e-48fb-47a1-b6e5-3f51d9a74519.pfx
$origCertPath = $result.ManagedItem.CertificatePath
Write-Log "Information" "Using certificate path $origCertPath"

# Export the private key
$keyPath = $FMS_PATH + 'CStore\serverKey.pem'
Remove-Item $keyPath;
openssl pkcs12 -in $origCertPath -out $keyPath -nocerts -nodes -passin pass:

# Export the certificate
$certPath = $FMS_PATH + 'CStore\crt.pem'
Remove-Item $certPath;
openssl pkcs12 -in $origCertPath -out $certPath -clcerts -nokeys -passin pass:

# Export the Intermediary
$intermPath = $FMS_PATH + 'CStore\interm.pem'
Remove-Item $intermPath;
openssl pkcs12 -in $origCertPath -out $intermPath -cacerts -nokeys -chain -passin pass:

# cd to FMS directory to run fmsadmin commands
cd $FMS_DB_PATH

# Install the certificate
.\fmsadmin certificate import $certPath --yes; 


<# Restart the FMS service #>
Write-Log "Information" "Restarting FileMaker Server."
net stop 'FileMaker Server'
if ($?) {
  net start 'FileMaker Server'
  if ($?) {
    Write-Log "Information" "FileMaker Server restarted successfully."
  }
  else {
    Write-Log "Warning" "FileMaker Server failed to start.  Trying again."
    net start 'FileMaker Server'
    if (-not $?) {
      Write-Log "Error" "FileMaker Server failed to start.  Cannot continue."
      Return
    }
  }
}
else {
  Write-Log "Error" "Failed to restart FileMaker Server.  Cannot continue."
  Return
}


Write-Log "Information" "Completed update of Filemaker Server certificate binding." 0

Return
