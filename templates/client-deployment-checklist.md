# ACS Email — Pre-Deployment Checklist

> **Client:** [Client Name]
> **Consultant:** [Your Name]
> **Target Date:** [Date]

---

## Before You Start

- [ ] Azure subscription confirmed with Contributor or Owner access
- [ ] Entra ID permissions confirmed (Application Administrator or Global Administrator)
- [ ] Custom domain name decided: `________________`
- [ ] DNS provider login credentials available
- [ ] PowerShell 7.0+ installed
- [ ] Az PowerShell module installed (`Install-Module -Name Az`)
- [ ] Az.Communication module installed (`Install-Module -Name Az.Communication`)
- [ ] Azure CLI installed and logged in

## Naming Decisions

| Resource | Naming Convention | Chosen Name |
|---|---|---|
| Resource Group | `rg-acs-email-[env]` | |
| Email Communication Service | `acs-email-[client]-[env]` | |
| Communication Service | `acs-[client]` (keep short!) | |
| Entra App Registration | `acs-smtp-[client]-[env]` | |
| SMTP Username | `[client]-smtp` or `scanner-smtp` | |

## Sender Addresses Needed

| MailFrom Username | Display Name | Purpose |
|---|---|---|
| DoNotReply | Do Not Reply | Default |
| | | |
| | | |
| | | |

## Devices/Applications to Configure

| Device/App | Location | Current SMTP | Contact Person |
|---|---|---|---|
| | | | |
| | | | |
| | | | |

## Post-Deployment

- [ ] Test email received successfully
- [ ] First device configured and tested
- [ ] Client secret stored in credential vault
- [ ] Secret expiration reminder set (30 days before)
- [ ] SMTP settings handoff document delivered to client
- [ ] Deployment log file archived
