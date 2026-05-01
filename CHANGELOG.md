# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-30

### Added
- `-TestEmailOnly` mode for sending test emails without resource creation
- `-AddSmtpEndpoint` mode for adding new SMTP endpoints to existing deployments
- `-CompleteSetup` mode for finishing deployment after manual domain verification
- `-SmtpPassword` parameter for test-only mode (prompts securely if omitted)
- `-NewMailFromAddress` and `-NewMailFromDisplayName` parameters for endpoint creation
- SMTP username now uses email format (username@domain) for copier/printer compatibility
- `New-AzCommunicationServiceSmtpUsername` cmdlet attempted before REST API fallback
- Test email tries custom username first, automatically falls back to legacy format
- Domain verification polling with retry (up to 6 attempts over 3 minutes)
- Azure Portal URL output when domain verification requires manual completion
- Re-initiation of verification on each polling attempt for pending record types
- Full deployment now splits into Phase 1 (infrastructure/DNS) and Phase 2 (auth/SMTP)
- Phase 1 outputs the exact -CompleteSetup command for Phase 2
- Phase 2 validates all four verification statuses before proceeding
- If verification completes during polling, Phase 2 runs automatically (no manual step)
- Endpoint creation summary with full SMTP settings for `-AddSmtpEndpoint` mode
- Communication Service existence validation for `-AddSmtpEndpoint` and `-CompleteSetup`

### Changed
- Script version bumped to 2.0.0
- Orchestrator refactored into four execution modes (Full/Phase1, CompleteSetup, AddEndpoint, TestOnly)
- SMTP Username function returns the created username for downstream use
- Test email function accepts optional username override
- Deployment summary shows email-format username alongside legacy format
- README restructured around execution modes with examples for each

## [1.2.0] - 2026-04-29

### Added
- Interactive subscription selector for multi-subscription environments
- Tenant ID displayed next to each subscription in the selector
- Tenant-aware Az CLI synchronization (prevents cross-tenant resource creation)
- `-DnsZoneSubscriptionId` parameter for cross-subscription DNS zones
- Domain linking graceful failure with manual command output for unverified domains

### Fixed
- Client secret JSON parsing filters out Az CLI warning text before parsing
- Az CLI context now synced to same tenant as Az PowerShell (critical for multi-tenant)
- IAM role assignment falls back to Az CLI on BadRequest with manual Portal guidance

## [1.1.0] - 2026-04-29

### Added
- Azure DNS automation (`New-ACSDnsRecords` function)
- `-DnsZoneResourceGroupName` and `-DnsZoneName` parameters
- Domain verification TXT record appended to existing record sets
- SPF record intelligently merged with existing SPF entries
- DKIM and DKIM2 CNAME records created with duplicate detection
- Subdomain-aware DNS record name calculation
- Domain creation retry mechanism (3 attempts with Az CLI fallback)
- Resource provider auto-registration for Microsoft.Communication
- 15-second provisioning delay between service creation and domain setup

### Fixed
- Error handling improved with `-ErrorAction Stop` on all Az cmdlets
- Empty string `Write-Log` calls replaced with space character
- Non-ASCII characters (em dashes) replaced with ASCII hyphens

## [1.0.0] - 2026-04-29

### Added
- `Deploy-ACSEmail.ps1` -- Full end-to-end ACS Email deployment automation
- Resource Group creation with standard tagging
- Email Communication Service resource creation
- Communication Service resource creation
- Custom domain and Azure-managed domain support
- Interactive DNS verification workflow (Domain, SPF, DKIM, DKIM2)
- MailFrom sender address creation via Az CLI
- Domain-to-Communication Service linking
- Entra ID App Registration with configurable secret expiration
- IAM role assignment directly on Communication Service resource
- Custom SMTP Username creation via ARM REST API
- Test email validation via Send-MailMessage
- Deployment summary with all SMTP settings for device configuration
- Full `-WhatIf` support on all operations
- Timestamped log file output
- Comprehensive PowerShell help with examples
- README with quick start, parameters, known gotchas, and repo structure
- MIT License
