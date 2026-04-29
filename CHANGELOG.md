# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-29

### Added
- `Deploy-ACSEmail.ps1` — Full end-to-end ACS Email deployment automation
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
