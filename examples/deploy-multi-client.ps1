<#
.SYNOPSIS
    Example: Batch deploy ACS Email for multiple clients from a CSV file.

.DESCRIPTION
    Reads client configurations from a CSV file and deploys ACS Email for each one.
    Designed for IT consultants managing multiple client environments.

    CSV Format (clients.csv):
    ClientName,ResourceGroup,EmailService,CommService,Domain,SmtpUser,TestEmail
    Contoso,rg-acs-contoso,acs-email-contoso,acs-contoso,contoso.com,smtp-contoso,admin@contoso.com
    Fabrikam,rg-acs-fabrikam,acs-email-fabrikam,acs-fabrikam,fabrikam.com,smtp-fabrikam,admin@fabrikam.com

.NOTES
    Author  : John O'Neill Sr.
    Company : Azure Innovators
    Blog    : https://www.azureinnovators.com/blog/
#>

$csvPath = Join-Path $PSScriptRoot "clients.csv"

if (-not (Test-Path $csvPath)) {
    Write-Host "Create a clients.csv file in the examples folder. See this script's header for format." -ForegroundColor Yellow
    exit
}

$clients = Import-Csv $csvPath

foreach ($client in $clients) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Deploying ACS Email for: $($client.ClientName)" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $params = @{
        ResourceGroupName        = $client.ResourceGroup
        EmailServiceName         = $client.EmailService
        CommunicationServiceName = $client.CommService
        CustomDomainName         = $client.Domain
        SmtpUsername              = $client.SmtpUser
        MailFromAddresses        = @("DoNotReply", "scanner", "alerts")
        MailFromDisplayNames     = @("Do Not Reply", "Scanner", "System Alerts")
        EntraAppName             = "acs-smtp-$($client.ClientName.ToLower())"
        TestRecipientEmail       = $client.TestEmail
        SkipDomainVerification   = $true  # Verify manually after batch deployment
    }

    try {
        & "$PSScriptRoot\..\scripts\Deploy-ACSEmail.ps1" @params
        Write-Host "`n$($client.ClientName): Deployment SUCCEEDED" -ForegroundColor Green
    }
    catch {
        Write-Host "`n$($client.ClientName): Deployment FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Batch deployment complete." -ForegroundColor Cyan
Write-Host "  Remember to verify domains manually in the Azure Portal." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
