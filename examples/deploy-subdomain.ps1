<#
.SYNOPSIS
    Example: Deploy ACS Email using a subdomain to isolate email reputation.

.DESCRIPTION
    Uses a subdomain (e.g., notify.contoso.com) instead of the root domain.
    This isolates ACS Email reputation from your primary domain. If automated
    email encounters deliverability issues, your main domain stays untouched.

    Recommended for organizations that:
    - Send high volumes of automated email
    - Want to protect their primary domain reputation
    - Need separate SPF/DKIM records for system email

.NOTES
    Author  : John O'Neill Sr.
    Company : Azure Innovators
    Blog    : https://www.azureinnovators.com/blog/
#>

$params = @{
    ResourceGroupName       = "rg-acs-email-prod"
    Location                = "eastus"
    EmailServiceName        = "acs-email-contoso-prod"
    CommunicationServiceName = "acs-contoso"
    CustomDomainName        = "notify.contoso.com"
    MailFromAddresses       = @("DoNotReply", "scanner", "alerts", "monitoring")
    MailFromDisplayNames    = @("Do Not Reply", "Scanner", "System Alerts", "Monitoring")
    EntraAppName            = "acs-smtp-relay-prod"
    SmtpUsername             = "notify-smtp"
    SecretExpirationMonths  = 12
    TestRecipientEmail      = "admin@contoso.com"
}

& "$PSScriptRoot\..\scripts\Deploy-ACSEmail.ps1" @params
