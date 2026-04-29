# Azure Communication Services Email Deployment Toolkit

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Azure](https://img.shields.io/badge/Azure-Communication%20Services-0078D4.svg)](https://learn.microsoft.com/en-us/azure/communication-services/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Blog](https://img.shields.io/badge/Blog-Azure%20Innovators-green.svg)](https://www.azureinnovators.com/blog/)

Automate the end-to-end deployment of Azure Communication Services (ACS) Email — from resource creation to sending your first authenticated email. Built for IT consultants and administrators who deploy ACS Email for multiple clients and need consistency, speed, and repeatability.

> **Part of the [ACS Email Blog Series](https://www.azureinnovators.com/blog/) by [Azure Innovators](https://www.azureinnovators.com)**

---

## What This Toolkit Does

The `Deploy-ACSEmail.ps1` script automates every step of an ACS Email deployment:

1. **Creates the Resource Group** with standard tagging
2. **Creates the Email Communication Service** resource
3. **Creates the Communication Service** resource
4. **Configures a custom domain** (or Azure-managed domain for testing)
5. **Guides you through DNS verification** (Domain, SPF, DKIM, DKIM2)
6. **Creates MailFrom sender addresses** (scanner@, alerts@, noreply@, etc.)
7. **Links the email domain** to the Communication Service
8. **Creates an Entra ID App Registration** with a client secret
9. **Assigns the IAM role** directly on the Communication Service resource
10. **Creates a custom SMTP Username** (short format for device compatibility)
11. **Sends a test email** to validate the deployment
12. **Outputs a deployment summary** with all SMTP settings ready to configure devices

Total deployment time: **under 10 minutes** (plus DNS propagation).

---

## Why This Exists

Setting up ACS Email manually through the Azure Portal involves clicking through multiple blades, creating two separate resources, registering an Entra app, assigning IAM roles, configuring DNS records, and connecting everything together. It's a 30-minute process that's easy to get wrong — especially the SMTP username format and IAM role assignment, which are the #1 and #2 causes of authentication failures.

This script eliminates those pain points. Run it once with your parameters, and you get a fully functional ACS Email environment with proper authentication, governance, and device-ready SMTP credentials.

For the full walkthrough of what this script automates, read the blog series:
- **[Part 1: Why SMTP Relay Is Breaking Your Applications](https://azureinnovators.com/why-smtp-relay-is-breaking-your-applications-and-how-to-fix-it-with-azure-communication-services/)** — The problem and why ACS Email is the solution
- **Part 2: How to Set Up ACS Email from Scratch in Under 30 Minutes** — Step-by-step setup guide (this script automates Part 2)
- **Part 3: Domain Configuration and DNS (SPF, DKIM, DMARC)** — Deep dive into email authentication
- **Part 4: Managing Sender Identities and Real-World Automation** — Production patterns and automation

---

## Prerequisites

| Requirement | Details |
|---|---|
| **PowerShell** | 7.0 or later ([Install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)) |
| **Azure PowerShell** | Az module (`Install-Module -Name Az -Force`) |
| **Az.Communication** | ACS module (`Install-Module -Name Az.Communication -Force`) |
| **Azure CLI** | Required for domain verification and sender username creation ([Install](https://aka.ms/installazurecli)) |
| **Azure Subscription** | Contributor or Owner role |
| **Entra ID** | Application Administrator or Global Administrator |

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/AzureInnovators/acs-email-toolkit.git
cd acs-email-toolkit
```

### 2. Run with your parameters

**Custom domain deployment (production):**

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -MailFromAddresses @("DoNotReply", "scanner", "alerts") `
    -MailFromDisplayNames @("Do Not Reply", "Scanner", "System Alerts") `
    -SmtpUsername "scanner-smtp" `
    -TestRecipientEmail "admin@contoso.com"
```

**Azure-managed domain (quick testing):**

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-test" `
    -EmailServiceName "acs-email-test" `
    -CommunicationServiceName "acs-test" `
    -UseAzureManagedDomain `
    -TestRecipientEmail "admin@contoso.com"
```

**Dry run (see what would happen without making changes):**

```powershell
.\scripts\Deploy-ACSEmail.ps1 `
    -ResourceGroupName "rg-acs-email-prod" `
    -EmailServiceName "acs-email-contoso-prod" `
    -CommunicationServiceName "acs-contoso" `
    -CustomDomainName "contoso.com" `
    -WhatIf
```

### 3. Configure your devices

After deployment, the script outputs a summary with all SMTP settings:

```
SMTP SETTINGS (for devices and applications):
  SMTP Server:              smtp.azurecomm.net
  Port:                     587
  Encryption:               STARTTLS
  Username:                 scanner-smtp
  Password:                 (Entra app client secret)
```

Enter these settings into your copier, printer, application, or script. Done.

---

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `ResourceGroupName` | Yes | — | Azure Resource Group name |
| `Location` | No | `eastus` | Azure region for the Resource Group |
| `DataLocation` | No | `UnitedStates` | Data location for ACS resources |
| `EmailServiceName` | Yes | — | Email Communication Service name |
| `CommunicationServiceName` | Yes | — | Communication Service name (**keep short**) |
| `CustomDomainName` | No* | — | Custom domain for sending email |
| `MailFromAddresses` | No | `@("DoNotReply")` | Array of sender usernames |
| `MailFromDisplayNames` | No | `@("Do Not Reply")` | Array of display names (must match count) |
| `EntraAppName` | No | `acs-smtp-relay` | Entra ID App Registration name |
| `SmtpUsername` | No | `acs-smtp` | Custom SMTP Username |
| `SecretExpirationMonths` | No | `12` | Client secret expiration (1-24 months) |
| `TestRecipientEmail` | No | — | Email address for test email |
| `SkipDomainVerification` | No | `$false` | Skip interactive DNS verification |
| `UseAzureManagedDomain` | No | `$false` | Use Azure-managed domain instead of custom |

*Either `-CustomDomainName` or `-UseAzureManagedDomain` must be specified.

---

## Known Gotchas This Script Handles

These are real-world issues that cause hours of troubleshooting. The script addresses each one:

**IAM role inheritance doesn't work reliably.** Assigning the role at the Resource Group level and relying on inheritance to reach the Communication Service resource either takes an unpredictable amount of time or doesn't work at all. This script assigns the role directly on the Communication Service resource.

**SMTP username length breaks devices.** The legacy username format (`ResourceName.AppID.TenantID`) creates usernames of 80-100+ characters. Most copiers and printers have a 50-64 character limit. This script creates a custom SMTP Username (e.g., `scanner-smtp`) that fits any device.

**Two resources, not one.** ACS Email requires both an Email Communication Service and a Communication Service. Many guides don't make this clear. This script creates and links both.

**The "wrong resource" mistake.** When assigning IAM roles, you must target the Communication Service — not the Email Communication Service. When forming the legacy SMTP username, you use the Communication Service name — not the Email Communication Service name. This script gets it right.

---

## Project Structure

```
acs-email-toolkit/
├── README.md                           # This file
├── LICENSE                             # MIT License
├── CHANGELOG.md                        # Version history
├── .gitignore                          # Git ignore rules
│
├── scripts/
│   ├── Deploy-ACSEmail.ps1             # Main deployment script
│   ├── Send-ACSTestEmail.ps1           # Standalone test email script
│   └── Remove-ACSEmail.ps1             # Teardown/cleanup script
│
├── examples/
│   ├── deploy-custom-domain.ps1        # Example: Custom domain deployment
│   ├── deploy-azure-managed.ps1        # Example: Azure-managed domain
│   ├── deploy-subdomain.ps1            # Example: Subdomain deployment
│   └── deploy-multi-client.ps1         # Example: Multi-client batch deployment
│
├── docs/
│   ├── TROUBLESHOOTING.md              # Common issues and solutions
│   ├── COPIER-CONFIG.md                # Copier/printer configuration guide
│   ├── SECRET-ROTATION.md              # Client secret rotation procedures
│   └── images/                         # Screenshots and diagrams
│       └── deployment-flow.png
│
└── templates/
    ├── device-smtp-settings.md         # Template: SMTP settings handoff doc
    └── client-deployment-checklist.md  # Template: Pre-deployment checklist
```

---

## Roadmap

- [ ] `Send-ACSTestEmail.ps1` — Standalone test email script with detailed diagnostics
- [ ] `Remove-ACSEmail.ps1` — Clean teardown of all ACS Email resources
- [ ] `deploy-multi-client.ps1` — Batch deployment from a CSV of client configurations
- [ ] `TROUBLESHOOTING.md` — Expanded troubleshooting guide with error codes
- [ ] `COPIER-CONFIG.md` — Brand-specific configuration guides (Sharp, Canon, Ricoh, HP, Xerox)
- [ ] `SECRET-ROTATION.md` — Step-by-step secret rotation with zero-downtime procedure
- [ ] Pester tests for deployment validation
- [ ] GitHub Actions workflow for CI testing

---

## Contributing

Contributions are welcome! If you've deployed ACS Email for a device or application that isn't covered here, please submit a PR with configuration details. Copier/printer configuration guides for additional brands are especially appreciated.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/xerox-config`)
3. Commit your changes (`git commit -am 'Add Xerox copier configuration'`)
4. Push to the branch (`git push origin feature/xerox-config`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## About Azure Innovators

[Azure Innovators](https://www.azureinnovators.com) helps organizations modernize their IT infrastructure with Microsoft Azure, Entra ID, Microsoft 365, and enterprise security solutions. We specialize in cloud migration, identity management, and cybersecurity strategy.

- **Website:** [www.azureinnovators.com](https://www.azureinnovators.com)
- **Blog:** [Azure Innovators Blog](https://www.azureinnovators.com/blog/)
- **Contact:** [Get in Touch](https://www.azureinnovators.com/contact-us/)
- **LinkedIn:** [Azure Innovators](https://www.linkedin.com/company/azure-innovators/)
