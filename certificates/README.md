# Certificate Automation

Automation of certificate requests and renewals is done using the [ACME protocol](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment), created by the [IRSG](https://www.abetterinternet.org/about) (the organization behind [Let’s Encrypt](https://letsencrypt.org/about)).  This protocol is supported by many major certificate authorities with a wide variety of clients available for any platform.  Most clients support automated installation and replacement of certificates on servers, such as web servers and reverse proxies (e.g. IIS, Apache, nginx, etc).

It’s recommended that automation is designed and configured with transparency and business continuity in mind.  Expired certificates can wreak havoc on systems and so steps should be taken to reduce that risk to the greatest extent possible.  To that end, the Law School does the following:
- Grant Certificate Authority to multiple individuals within each team that uses it.
- Maintain an NYU Google Group as the e-mail address for the CA accounts and for the clients (i.e. `certificate.management@law.nyu.edu`).
- Maintain documentation available to all in the department and ensure many people understand how it works.


# Certificate Authority

With most ACME certificate clients there are multiple choices of Certificate Authority – the organization that signs the certificate you request.  When requesting certificates for nyu.edu subdomains we should always choose [Sectigo](https://cert-manager.com/customer/InCommon).  For all others, use the free Let’s Encrypt (often the default of the ACME client).

## Sectigo

This is the official CA used by NYU.  We can use it at no cost.  Certificates can be requested for any nyu.edu subdomain.

https://cert-manager.com/customer/InCommon

### How It Works

With Sectigo, you register your client by authenticating to an existing Sectigo account using a set of credentials (Key ID and HMAC) and e-mail address.  Sectigo internally manages authorization for the specific domain at the time of certificate request without the need for HTTP or DNS validation.  It should be noted that most clients will require you to choose a validation method–HTTP or DNS–even though it won’t be used with Sectigo.  

### Configure for ACME

> [!TIP]
> It is recommended to create separate accounts for different system types, environments (e.g. Production, QA), etc.

**Setup an ACME account:**

 1. Login to the NYU Certificate Manager (InCommon) and navigate to *Enrollment > ACME*.
 2. Select the *Universal ACME* endpoint (https://acme.enterprise.sectigo.com) and click *Accounts*.
 3. Click the *green plus* icon to add an account.
 4. Enter a descriptive name (e.g. `Production IIS`, or `QA Kubernetes`).
 5. Ensure *Organization* has `New York University` selected, and *Department* has, e.g. `School of Law` selected.
 6. Change Certificate Profile to `V2 IGTF Multi Domain (CA3)`[^1].
 7. Click *Save*.
 8. Copy the connection and authentication information provided to add to the desired ACME client (also save this in Law ITS password manager for easy reference!).

[^1]: Through trial-and-error this certificate profile was found to work best when certificates may need to include multiple domains.  If a different certificate type is needed, ensure you choose from the V2 options only.

> [!NOTE]
> Initial attempts at configuring and using ACME failed due to how the Law School’s subdomain was setup in the certificate manager.  Our account was configured as `nyu.edu > *.law.nyu.edu`.  We eventually found that for ACME, we need to use `law.nyu.edu` (without the wildcard) and we were able to add the subdomain under *Domains*, so it is now `nyu.edu > law.nyu.edu > *.law.nyu.edu`.  **(this note is believed to be outdated since the move to the Universal ACME endpoint and should probably be ignored...)**

**Retrieve account information needed to configure ACME client:**

 1. Login to the NYU Certificate Manager and navigate to *Enrollment > ACME*.
 2. Select *Universal ACME*, then click *Accounts*.
 3. Select an account, e.g. `Production IIS`, then click *Details*.
 4. Copy the **ACME URL**, **Key ID**, and **HMAC Key** to use to configure your ACME client.

> [!TIP]
> An example of how to use the certbot client with Sectigo is on this *Account Details* page.

### Support and Troubleshooting

For support and to request accounts, contact keymaster@nyu.edu.

Documentation and support articles

https://spaces.at.internet2.edu/display/ICCS/InCommon+Certificate+Service+Home
https://sectigo.com/knowledge-base/detail/Sectigo-Certificate-Manager-SCM-ACME-error-The-client-lacks-sufficient-authorization/kA03l00000117Sy
https://sectigo.status.io/

#### Known Issues

**Timeout during certificate order**

ACME clients seem to have a relatively short timeout of about 15 seconds when requesting a certificate, and Sectigo can easily take longer than 15 seconds to respond.  When this happens, the client will return an error that the request failed, while Sectigo successfully generates the certificate.  The client may not automatically retry.  Subsequent attempts usually succeed eventually, but at the cost of several duplicate certificates which must then be manually revoked.

Law ITS successfully worked with our preferred Windows ACME client vendor to increase the timeout in their software to accommodate for the long delays from Sectigo.  We also submitted a support request to Sectigo through NYU Keymaster, but this appears to remain an open issue.

Other clients may fail and require similar support requests to the vendor, or in the case of an open source client (which is most of them) could involve submitting an issue to their code repository, or better, submitting a pull request with a fix.

**Lacks Test/Staging Endpoint**

Unlike most other CAs which support ACME, Sectigo does not offer a staging endpoint against which one can test their client configuration without running the risk of hitting API limits, or generating a slew of real certificates that must be subsequently revoked.  

## Let’s Encrypt

Let’s Encrypt makes it easy to request a certificate - register an account using an e-mail address, then as part of the request process, prove you have control over the domain, either by temporarily hosting a file in the `/.well-known` directory at the root of the domain, or creating a temporary DNS resource record with a specific text string.

https://letsencrypt.org


# ACME Clients

The most popular clients are free and open source.  However, there are some paid clients which come with the benefits of a regular release cadence in addition to support.  It may not be possible to use the same client across all systems, depending on availability and required features.  The clients in use by Law ITS are outlined below.

## Certify The Web

This is the preferred client for Windows and IIS servers.  It handles certificate requests and renewals, and automatic binding to IIS sites.  The pre- and post-request scripting support includes a small library of prebuilt scripts, and allows for custom PowerShell scripts to be executed (for example, to bind certificates to Filemaker Pro or fire a notification to Slack via webhook).

While the free/community edition can be used for evaluation, a paid license must be purchased for production use.  They offer educational pricing if you contact them before purchasing.

https://certifytheweb.com

### Configure for NYU Certificate Manager (Sectigo)

**Retrieve account settings and credentials from Sectigo**

 1. Login to NYU Certificate Manager.
 2. Go to *Enrollment > ACME*.
 3. Check *Universal ACME*, then click *Accounts*.
 4. Check your pre-configured account, then click *Details*.
 5. Copy **ACME URL**, **Key ID**, and **HMAC Key**.

**Add NYU CA**

 1. Go to *Settings > Certificate Authorities*
 2. Click *Edit Certificate Authorities*
 3. Enter the following details
    - Title: `NYU Certificate Authority`
    - Production API: `https://acme.enterprise.sectigo.com`
    - Enabled: *checked*
    - Email Address Required: *un-checked*
    - Allow Untrusted TLS: *un-checked*

**Add Account for NYU CA**

 1. Go to *Settings > Certificate Authorities*
 2. Click *New Account*
 3. Select *NYU Certificate Authority*
 4. Email Address: `certificate.management@law.nyu.edu`
 5. Agree to the terms and conditions.
 6. Select the *Advanced* tab.
 7. Paste the **Key ID** and **HMAC Key**.
 8. Click *Register Contact*.

**Set NYU CA as Default**

 1. Go to Settings > Certificate Authorities
 2. For Preferred Certificate Authority, select NYU Certificate Manager.

> [!TIP] 
> The preferred CA can be set on a per-certificate basis.  This is helpful when a server hosts multiple services with a mix of nyu.edu subdomains and non-NYU domains.

**Request Certificate using NYU Certificate Authority**

  *add steps for example configurations with deploy scripts...*

### Installation

Certify can be installed manually by downloading the latest version from their website.  It’s also possible to script the installation in an endpoint management solution such as BigFix, SCCM, Workspace ONE, etc.  Some configuration is available via their CLI, but others must be imported by copying config files from an existing installation.  

This is also installable via winget.  From a privileged command prompt or PS shell, run `winget install CertifyTheWeb.CertifySSLManager`.

#### Support and Troubleshooting

Certify provides a fairly detailed log of every certificate request/renewal attempt.  These logs can be found in `C:\ProgramData\Certify\logs`.  This is especially helpful when forwarded to Splunk.

In addition to extensive documentation and their community forum, traditional support is provided via e-mail.  While their support can fall a little short on response time (nothing egregious), the service they provide is excellent.  While troubleshooting timeout issues with Sectigo, they worked with Law ITS to test a code change by offering a pre-release version with the fix, and included the fix in their next full release, despite affecting an insignificantly small portion of their customer base.

## Certbot

The original ACME client, created alongside the ACME protocol in concert with Let’s Encrypt, certbot is free and available for most platforms.  It’s Python-based, simple to use, and includes support for common webservers, reverse proxies, etc.

Certbot can be [downloaded](https://certbot.eff.org/) from their website, or installed via `winget install certbot`.

As noted elsewhere, Sectigo provides a sample certbot command when viewing the ACME Account Details page.  This can be copied and used after changing only a couple values.  

**Example**
```bash
certbot certonly --standalone --non-interactive --agree-tos \
--email certificate.management@law.nyu.edu \
--server https://acme.enterprise.sectigo.com \
--eab-kid GET_VALUE_FROM_NYU_CERT_MANAGER \
--eab-hmac-key GET_VALUE_FROM_NYU_CERT_MANAGER \
--domain somedomain.law.nyu.edu \
--cert-name SomedomainCert
```

## acme.sh

*add acme.sh info here...*




# Documentation Tasks

 - [ ] List systems where implemented, e.g. Windows servers, Linux, Synology NAS
 - [ ] add to github notification script for Slack (currently in *Infrastructure* repo)
 - [ ] add to github Filemaker Pro bind script
 - [ ] flesh out acme.sh client
 - [ ] add to github acme.sh script(s) from Synology?
