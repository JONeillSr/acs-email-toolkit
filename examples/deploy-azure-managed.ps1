<#
.SYNOPSIS
    Example: Deploy ACS Email with an Azure-managed domain for quick testing.

.DESCRIPTION
    Uses the free Azure-managed subdomain for rapid testing. The Azure-managed domain
    has strict sending limits (5 emails/min, 10 emails/hour) but requires no DNS
    configuration. Perfect for validating the setup before investing time in custom
    domain verification.

.NOTES
    Author  : John O'Neill Sr.
    Company : Azure Innovators
    Blog    : https://www.azureinnovators.com/blog/
#>

$params = @{
    ResourceGroupName       = "rg-acs-email-test"
    Location                = "eastus"
    EmailServiceName        = "acs-email-test"
    CommunicationServiceName = "acs-test"
    UseAzureManagedDomain   = $true
    EntraAppName            = "acs-smtp-relay-test"
    SmtpUsername             = "acs-test-smtp"
    SecretExpirationMonths  = 6
    TestRecipientEmail      = "admin@contoso.com"
}

& "$PSScriptRoot\..\scripts\Deploy-ACSEmail.ps1" @params
