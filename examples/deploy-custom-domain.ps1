<#
.SYNOPSIS
    Example: Deploy ACS Email with a custom domain for production use.

.DESCRIPTION
    This example deploys a complete ACS Email environment with a custom domain,
    three MailFrom sender addresses, and a short SMTP username for copier compatibility.

.NOTES
    Author  : John O'Neill Sr.
    Company : Azure Innovators
    Blog    : https://www.azureinnovators.com/blog/
#>

# Update these values for your environment
$params = @{
    ResourceGroupName       = "rg-acs-email-prod"
    Location                = "eastus"
    EmailServiceName        = "acs-email-contoso-prod"
    CommunicationServiceName = "acs-contoso"
    CustomDomainName        = "contoso.com"
    MailFromAddresses       = @("DoNotReply", "scanner", "alerts", "noreply")
    MailFromDisplayNames    = @("Do Not Reply", "Scanner", "System Alerts", "No Reply")
    EntraAppName            = "acs-smtp-relay-prod"
    SmtpUsername             = "scanner-smtp"
    SecretExpirationMonths  = 12
    TestRecipientEmail      = "admin@contoso.com"
}

# Run the deployment
& "$PSScriptRoot\..\scripts\Deploy-ACSEmail.ps1" @params
