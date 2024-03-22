# Certify the Web Deployment Scrips

## post_request.ps1

A wrapper script meant to call any other PowerShell script located in the same directory.  This is useful you need CertifyTheWeb to execute more than one script.


## webdeploy.ps1



## rdp.ps1



## slack_notify.ps1



## filemaker.ps1



# Deployment

Scripts should be copied to `C:\Program Files\lawits\certificates`.

**Assign script to a certificate in CertifyTheWeb:**
 1. Select the certificate.
 2. Check *Show Advanced Options*.
 3. Select *Scripting*.
 4. Under the *PowerShell Scripts* heading, browse for the script for Post-request PS Script.
 5. Test, then *Save*.
