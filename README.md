# Azure Communication Services Email Deployment Toolkit

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Azure](https://img.shields.io/badge/Azure-Communication%20Services-0078D4.svg)](https://learn.microsoft.com/en-us/azure/communication-services/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Blog](https://img.shields.io/badge/Blog-Azure%20Innovators-green.svg)](https://www.azureinnovators.com/blog/)

Automate the end-to-end deployment of Azure Communication Services (ACS) Email -- from resource creation to sending your first authenticated email. Built for IT consultants and administrators who deploy ACS Email for multiple clients and need consistency, speed, and repeatability.

> **Part of the [ACS Email Blog Series](https://www.azureinnovators.com/blog/) by [Azure Innovators](https://www.azureinnovators.com)**

---

## Five Modes of Operation

### 1. Full Deployment (default)
Creates everything from scratch -- Resource Group, Email Communication Service, Communication Service, custom domain, DNS records, MailFrom addresses, Entra ID authentication, IAM roles, SMTP username, and sends a test email. If domain verification completes during the polling window, everything runs in one pass. Otherwise, the script stops cleanly and outputs the exact `-CompleteSetup` command for Phase 2.

### 2. Complete Setup (`-CompleteSetup`)
Finishes the deployment after manual domain verification in the Azure Portal. Checks all four verification statuses, links the domain, creates the Entra app, assigns IAM roles, creates the SMTP username, and sends a test email. If verification is still pending, shows the Portal URL and exits without making changes.

### 3. Add Domain (`-AddDomain`)
Adds a new domain to an existing ACS deployment -- for LLCs with multiple DBAs, organizations with regional domains, or MSPs managing multiple brands. Creates the domain, DNS records, MailFrom addresses, and links it alongside any previously linked domains. Existing SMTP credentials can immediately send from the new domain.

### 4. Add SMTP Endpoint (`-AddSmtpEndpoint`)
Adds a new authenticated SMTP endpoint to an existing deployment. Creates a dedicated Entra app, client secret, IAM role, SMTP username, and optional MailFrom address -- without touching the infrastructure. Use when a client needs separate credentials for printers, ERP systems, firewalls, or other applications.

### 5. Test Email Only (`-TestEmailOnly`)
Sends a test email using an existing ACS deployment. Use after completing manual steps (domain verification, SMTP username creation in the Portal) or to re-test after resolving issues. Tries the custom SMTP username first, then falls back to the legacy format automatically.

---

## Quick Start

### Full Deployment with Azure DNS automation

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -DnsZoneResourceGroupName "rg-dns-prod" `
    -MailFromAddresses @("donotreply", "scanner", "alerts") `
    -MailFromDisplayNames @("Do Not Reply", "Scanner", "System Alerts") `
    -TestRecipientEmail "admin@contoso.com"
```

### Add a printer SMTP endpoint to an existing deployment

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -CommunicationServiceName "acs-contoso" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CustomDomainName "contoso.com" `
    -AddSmtpEndpoint `
    -EntraAppName "acs-smtp-printers" `
    -SmtpUsername "printer-smtp" `
    -NewMailFromAddress "scanner" `
    -NewMailFromDisplayName "Scanner"
```

### Re-test email after manual Portal steps

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -TestEmailOnly `
    -TestRecipientEmail "admin@contoso.com"
```

### Complete setup after Portal domain verification

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -CompleteSetup `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -TestRecipientEmail "admin@contoso.com"
```

### Add a second domain to an existing deployment

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -AddDomain `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "subsidiary.com" `
    -DnsZoneResourceGroupName "rg-dns-prod" `
    -DnsZoneName "subsidiary.com" `
    -MailFromAddresses @("donotreply", "orders") `
    -MailFromDisplayNames @("Do Not Reply", "Orders")
```

### Dry run (see what would happen)

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -WhatIf
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| **PowerShell** | 7.0 or later ([Install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)) |
| **Azure PowerShell** | Az module (`Install-Module -Name Az -Force`) |
| **Az.Communication** | ACS module (`Install-Module -Name Az.Communication -Force`) |
| **Az.Dns** | DNS module, only for Azure DNS automation (`Install-Module -Name Az.Dns -Force`) |
| **Azure CLI** | Required for domain verification and Entra app operations ([Install](https://aka.ms/installazurecli)) |
| **Azure Subscription** | Contributor or Owner role |
| **Entra ID** | Application Administrator or Global Administrator |

---

## What the Script Does (Full Deployment)

1. **Selects subscription** -- prompts if multiple subscriptions exist, shows tenant IDs, syncs both Az PowerShell and Az CLI to the same tenant
2. **Registers resource provider** -- auto-registers Microsoft.Communication if needed
3. **Creates Resource Group** with standard tags
4. **Creates Email Communication Service**
5. **Creates Communication Service**
6. **Configures custom domain** with retry and Az CLI fallback
7. **Creates DNS records** (Azure DNS) or displays manual DNS guidance
8. **Polls for domain verification** (up to 3 minutes) with Portal URL fallback
9. **Creates MailFrom sender addresses**
10. **Links domain** to Communication Service (or provides manual command if unverified)
11. **Creates Entra ID App Registration** with configurable secret expiration
12. **Assigns IAM role** directly on Communication Service with Az CLI fallback
13. **Creates SMTP Username** in email format (username@domain) with cmdlet and REST API fallback
14. **Sends test email** trying custom username first, then legacy format
15. **Outputs deployment summary** with all SMTP settings ready for device configuration

---

## SMTP Username Format

The script creates SMTP usernames in **email format** (e.g., `acs-smtp@contoso.com`) rather than freeform text. This is important because:

- Most copier and printer admin panels expect email-style usernames
- The email format works alongside the legacy format -- both are valid
- The legacy format (`ResourceName.AppID.TenantID`) is 80-100+ characters and breaks on devices with 50-64 character username limits
- Both formats are shown in the deployment summary so you can use whichever works for your devices

---

## Adding Multiple SMTP Endpoints

After the initial deployment, use `-AddSmtpEndpoint` to create separate authenticated endpoints for different systems:

```powershell
# Endpoint for ERP system
.\scripts\Deploy-ACSEmail.ps1 -AddSmtpEndpoint `
    -ResourceGroupName "rg-acs-email-prod" `
    -CommunicationServiceName "acs-contoso" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CustomDomainName "contoso.com" `
    -EntraAppName "acs-smtp-erp" `
    -SmtpUsername "erp-smtp" `
    -NewMailFromAddress "erp-notifications" `
    -NewMailFromDisplayName "ERP System"

# Endpoint for firewall alerts
.\scripts\Deploy-ACSEmail.ps1 -AddSmtpEndpoint `
    -ResourceGroupName "rg-acs-email-prod" `
    -CommunicationServiceName "acs-contoso" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CustomDomainName "contoso.com" `
    -EntraAppName "acs-smtp-firewall" `
    -SmtpUsername "firewall-smtp" `
    -NewMailFromAddress "alerts" `
    -NewMailFromDisplayName "Firewall Alerts"
```

Each endpoint gets its own Entra app, client secret, and SMTP username. If one endpoint's credentials are compromised or need rotation, the others are unaffected.

---

## Multi-Domain Deployments

For organizations with multiple domains (LLCs with DBAs, regional brands, MSPs), use `-AddDomain` to add each domain to the same ACS infrastructure:

```powershell
# Initial deployment with primary domain
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-prod" `
    -CommunicationServiceName "acs-prod" `
    -CustomDomainName "azureinnovators.com" `
    -DnsZoneResourceGroupName "rg-dns-prod" `
    -MailFromAddresses @("donotreply", "scanner") `
    -MailFromDisplayNames @("Do Not Reply", "Scanner") `
    -TestRecipientEmail "admin@azureinnovators.com"

# Add second domain (after Phase 1 + verification + CompleteSetup)
.\scripts\Deploy-ACSEmail.ps1 -AddDomain `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-prod" `
    -CommunicationServiceName "acs-prod" `
    -CustomDomainName "jtcustomtrailers.com" `
    -DnsZoneResourceGroupName "rg-dns-prod" `
    -DnsZoneName "jtcustomtrailers.com" `
    -MailFromAddresses @("donotreply", "orders") `
    -MailFromDisplayNames @("Do Not Reply", "Orders")

# Add third domain
.\scripts\Deploy-ACSEmail.ps1 -AddDomain `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-prod" `
    -CommunicationServiceName "acs-prod" `
    -CustomDomainName "awesomewildstuff.com" `
    -DnsZoneResourceGroupName "rg-dns-prod" `
    -DnsZoneName "awesomewildstuff.com" `
    -MailFromAddresses @("donotreply", "support") `
    -MailFromDisplayNames @("Do Not Reply", "Support")
```

All domains share the same ACS infrastructure. A single set of SMTP credentials can send from any MailFrom address on any linked domain -- the From address in the email determines which domain is used. For isolation, combine with `-AddSmtpEndpoint` to create separate credentials per domain.

---

## Known Gotchas This Script Handles

**Multi-tenant Az CLI/PowerShell mismatch.** Consultants managing multiple client tenants can end up with Az CLI pointed at one tenant and Az PowerShell at another. The script detects this and synchronizes both tools to the same tenant before creating any resources.

**IAM role inheritance doesn't work reliably.** The script assigns the "Communication and Email Service Owner" role directly on the Communication Service resource, not the Resource Group.

**SMTP username length breaks devices.** The legacy format exceeds 80 characters. The script creates email-format usernames that work on any device.

**Domain verification requires Portal interaction.** The Az CLI `initiate-verification` command doesn't always trigger verification. The script polls and provides the Portal URL when manual verification is needed.

**Two resources, not one.** ACS Email requires both an Email Communication Service and a Communication Service. The script creates and links both.

**Az CLI outputs warnings before JSON.** Multi-tenant accounts produce warning text that breaks JSON parsing. The script filters for JSON content in all Az CLI output.

**Service principal propagation timing.** The script waits 15 seconds after app creation before looking up the service principal, with 3 retry attempts.

**Em dash encoding issues.** The script uses only ASCII characters to prevent encoding problems when downloaded across different platforms.

---

## Project Structure

```
acs-email-toolkit/
|-- README.md
|-- LICENSE
|-- CHANGELOG.md
|-- .gitignore
|
|-- scripts/
|   |-- Deploy-ACSEmail.ps1             # Main deployment script (5 modes)
|   |-- Send-ACSTestEmail.ps1           # Standalone test email script (planned)
|   +-- Remove-ACSEmail.ps1             # Teardown/cleanup script (planned)
|
|-- examples/
|   |-- deploy-custom-domain.ps1        # Custom domain deployment
|   |-- deploy-azure-managed.ps1        # Azure-managed domain (testing)
|   |-- deploy-subdomain.ps1            # Subdomain isolation pattern
|   +-- deploy-multi-client.ps1         # Batch deployment from CSV
|
|-- docs/
|   |-- TROUBLESHOOTING.md              # Common issues and solutions
|   |-- COPIER-CONFIG.md                # Copier/printer configuration guide
|   +-- SECRET-ROTATION.md              # Client secret rotation procedures
|
+-- templates/
    |-- device-smtp-settings.md         # SMTP settings handoff doc
    +-- client-deployment-checklist.md  # Pre-deployment checklist
```

---

## Roadmap

- [ ] `Send-ACSTestEmail.ps1` -- Standalone test email script with detailed diagnostics
- [ ] `Remove-ACSEmail.ps1` -- Clean teardown of all ACS Email resources
- [ ] `deploy-multi-client.ps1` -- Batch deployment from a CSV of client configurations
- [ ] `TROUBLESHOOTING.md` -- Expanded troubleshooting guide with error codes
- [ ] `COPIER-CONFIG.md` -- Brand-specific guides (Sharp, Canon, Ricoh, HP, Xerox)
- [ ] `SECRET-ROTATION.md` -- Zero-downtime secret rotation procedure
- [ ] Pester tests for deployment validation
- [ ] GitHub Actions workflow for CI testing

---

## Contributing

Contributions are welcome! Copier/printer configuration guides for additional brands are especially appreciated.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/xerox-config`)
3. Commit your changes (`git commit -am 'Add Xerox copier configuration'`)
4. Push to the branch (`git push origin feature/xerox-config`)
5. Open a Pull Request

---

## License

MIT License -- see [LICENSE](LICENSE) for details.

---

## About Azure Innovators

[Azure Innovators](https://www.azureinnovators.com) helps organizations modernize their IT infrastructure with Microsoft Azure, Entra ID, Microsoft 365, and enterprise security solutions.

- **Website:** [www.azureinnovators.com](https://www.azureinnovators.com)
- **Blog:** [Azure Innovators Blog](https://www.azureinnovators.com/blog/)
- **Contact:** [Get in Touch](https://www.azureinnovators.com/contact-us/)
- **GitHub:** [github.com/JONeillSr](https://github.com/JONeillSr)
