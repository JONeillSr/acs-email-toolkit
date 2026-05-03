# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-04-30

### Added
- `-AddDomain` mode for multi-domain deployments (LLCs with DBAs, MSPs, regional domains)
- Multi-domain support in `Connect-ACSDomain` -- preserves existing linked domains when linking new ones
- Domain linking command output includes all linked domains for multi-domain setups
- Verification-pending output for `-AddDomain` includes re-run command
- `-AddDomain` example in help documentation

### Changed
- `Connect-ACSDomain` now queries existing linked domains before updating, preventing overwrite
- Domain link error message includes full domain array for manual multi-domain linking

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
- Full deployment splits into Phase 1 (infrastructure/DNS) and Phase 2 (auth/SMTP)
- Phase 1 outputs the exact -CompleteSetup command for Phase 2
- If verification completes during polling, Phase 2 runs automatically

### Changed
- Script version bumped to 2.0.0
- Orchestrator refactored into multiple execution modes
- Deployment summary shows email-format username alongside legacy format

## [1.2.0] - 2026-04-29

### Added
- Interactive subscription selector for multi-subscription environments
- Tenant ID displayed next to each subscription in the selector
- Tenant-aware Az CLI synchronization (prevents cross-tenant resource creation)
- `-DnsZoneSubscriptionId` parameter for cross-subscription DNS zones

### Fixed
- Client secret JSON parsing filters out Az CLI warning text
- Az CLI context synced to same tenant as Az PowerShell
- IAM role assignment falls back to Az CLI on BadRequest

## [1.1.0] - 2026-04-29

### Added
- Azure DNS automation (`New-ACSDnsRecords` function)
- `-DnsZoneResourceGroupName` and `-DnsZoneName` parameters
- SPF record intelligently merged with existing SPF entries
- Domain creation retry mechanism (3 attempts with Az CLI fallback)
- Resource provider auto-registration for Microsoft.Communication

### Fixed
- Error handling improved with `-ErrorAction Stop` on all Az cmdlets
- Non-ASCII characters replaced with ASCII hyphens

## [1.0.0] - 2026-04-29

### Added
- `Deploy-ACSEmail.ps1` -- Full end-to-end ACS Email deployment automation
- Resource Group, Email Service, Communication Service creation
- Custom domain and Azure-managed domain support
- DNS verification workflow
- MailFrom sender address creation
- Entra ID App Registration with configurable secret expiration
- IAM role assignment directly on Communication Service resource
- SMTP Username creation via ARM REST API
- Test email validation
- Full `-WhatIf` support
- Timestamped log file output
- MIT License
