<#
.SYNOPSIS
    Deploys Azure Communication Services Email infrastructure from scratch, adds
    SMTP endpoints to existing deployments, or sends test emails.

.DESCRIPTION
    This script automates the end-to-end deployment of Azure Communication Services (ACS)
    Email infrastructure. It supports three execution modes:

    FULL DEPLOYMENT (default): Creates all required Azure resources, configures a custom
    domain, sets up DNS records, creates Entra ID authentication, assigns IAM roles,
    creates SMTP usernames, and sends a test email. Designed for IT consultants and
    administrators who need to deploy ACS Email quickly and consistently.

    ADD SMTP ENDPOINT (-AddSmtpEndpoint): Adds a new authenticated SMTP endpoint to an
    existing ACS Email deployment. Creates a new Entra app registration, client secret,
    IAM role assignment, SMTP username, and optional MailFrom address. Use this when a
    client needs separate credentials for different systems (ERP, printers, firewalls)
    without redeploying the entire infrastructure.

    TEST EMAIL ONLY (-TestEmailOnly): Sends a test email using an existing ACS deployment
    to verify connectivity. Use after manual steps (domain verification, SMTP username
    creation) are completed, or to re-test after resolving issues.

    Resources created (Full Deployment):
    - Resource Group (optional, if it doesn't exist)
    - Azure Email Communication Service
    - Azure Communication Service
    - Custom Domain (with verification guidance or automated Azure DNS)
    - DNS Records (automated when using Azure DNS, manual guidance otherwise)
    - MailFrom Sender Addresses
    - Entra ID App Registration with Client Secret
    - IAM Role Assignment (Communication and Email Service Owner)
    - SMTP Username (email format: username@domain for device compatibility)

    Subscription Selection:
    If the logged-in Azure account has access to multiple subscriptions, the script
    presents a numbered list (with tenant IDs visible) and prompts the user to choose.
    Both Az PowerShell and Az CLI contexts are synchronized to the selected subscription
    and tenant, preventing cross-tenant resource creation in multi-tenant environments.

    DNS Automation (Azure DNS):
    When -DnsZoneResourceGroupName is specified, the script automatically creates or
    updates DNS records in the Azure DNS Zone. Domain verification TXT records are
    appended to existing record sets. SPF records are intelligently merged with existing
    SPF entries. DKIM and DKIM2 CNAME records are created if they don't exist. The
    function is subdomain-aware for notify.contoso.com style deployments.

    Domain Verification:
    After DNS records are created, the script initiates verification and polls for up
    to 3 minutes. If verification is still pending (common with external DNS providers),
    the script provides the Azure Portal URL to complete verification manually and
    continues with remaining steps. Domain linking is attempted automatically when
    verification succeeds; if the domain is not yet verified, the exact PowerShell
    command to link it manually is provided.

    SMTP Username Format:
    The script creates SMTP usernames in email format (e.g., acs-smtp@contoso.com)
    rather than freeform text. This format is compatible with copier and printer admin
    panels that expect email-style credentials. The legacy long-form username
    (ResourceName.AppID.TenantID) is also displayed as a fallback.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group. Will be created if it doesn't exist.
    Example: acs-email-prod-eastus-rg

.PARAMETER Location
    The Azure region for the Resource Group.
    Default: eastus

.PARAMETER DataLocation
    The data location for ACS resources. Must match supported regions.
    Default: UnitedStates

.PARAMETER EmailServiceName
    The name for the Email Communication Service resource.
    Example: acs-email-contoso-prod-eastus

.PARAMETER CommunicationServiceName
    The name for the Communication Service resource. Keep this SHORT - it becomes
    part of the legacy SMTP username format.
    Example: acs-contoso

.PARAMETER CustomDomainName
    The custom domain to configure for sending email.
    Example: contoso.com

.PARAMETER MailFromAddresses
    An array of MailFrom sender usernames to create (without the domain).
    Default: @("donotreply")
    Example: @("donotreply", "scanner", "alerts", "noreply")

.PARAMETER MailFromDisplayNames
    An array of display names corresponding to each MailFrom address.
    Must match the count of MailFromAddresses.
    Default: @("Do Not Reply")
    Example: @("Do Not Reply", "Scanner", "System Alerts", "No Reply")

.PARAMETER EntraAppName
    The display name for the Entra ID App Registration used for SMTP authentication.
    For -AddSmtpEndpoint, use a unique name per endpoint (e.g., acs-smtp-printers).
    Default: acs-smtp-relay

.PARAMETER SmtpUsername
    The SMTP Username prefix. Combined with the domain to create the full email-format
    username (e.g., acs-smtp@contoso.com). Keep short for device compatibility.
    For -AddSmtpEndpoint, use a unique prefix per endpoint (e.g., printer-smtp).
    Default: acs-smtp

.PARAMETER SecretExpirationMonths
    Number of months before the Entra app client secret expires.
    Default: 12

.PARAMETER TestRecipientEmail
    Email address to send a test email to. Required for -TestEmailOnly mode.

.PARAMETER SkipDomainVerification
    Switch to skip the domain verification step. Use when DNS records are pre-configured
    or when running in a CI/CD pipeline with manual verification.

.PARAMETER UseAzureManagedDomain
    Switch to use an Azure-managed domain instead of a custom domain.
    Useful for testing before configuring a custom domain.

.PARAMETER DnsZoneResourceGroupName
    The Resource Group containing your Azure DNS Zone. When specified, DNS records are
    created automatically. If omitted, manual DNS guidance is displayed.
    Example: rg-dns-prod

.PARAMETER DnsZoneName
    The Azure DNS Zone name. Defaults to CustomDomainName. Use when the zone differs
    from the custom domain (e.g., subdomain deployments).
    Example: contoso.com

.PARAMETER DnsZoneSubscriptionId
    Subscription ID where the DNS Zone resides, if different from the ACS subscription.
    Only needed when DNS is intentionally in a separate subscription.

.PARAMETER TestEmailOnly
    Switch to send a test email only, skipping all resource creation. Requires
    -TestRecipientEmail and either -SmtpPassword or interactive password prompt.
    Tries the custom SMTP username first, then falls back to the legacy format.

.PARAMETER SmtpPassword
    The SMTP password (Entra app client secret) for -TestEmailOnly mode.
    If omitted in -TestEmailOnly mode, the script prompts securely.

.PARAMETER AddSmtpEndpoint
    Switch to add a new SMTP endpoint to an existing ACS deployment. Creates a new
    Entra app, client secret, IAM role assignment, SMTP username, and optional
    MailFrom address without touching infrastructure. Requires -ResourceGroupName,
    -CommunicationServiceName, -EntraAppName, and -SmtpUsername.

.PARAMETER NewMailFromAddress
    MailFrom username for the new endpoint (used with -AddSmtpEndpoint).
    Example: erp-notifications

.PARAMETER NewMailFromDisplayName
    Display name for the new MailFrom address (used with -AddSmtpEndpoint).
    Example: ERP Notifications

.PARAMETER WhatIf
    Shows what would happen without making any changes.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-prod-eastus-rg" `
        -EmailServiceName "acs-email-contoso-prod-eastus" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "contoso.com" `
        -DnsZoneResourceGroupName "rg-dns-prod" `
        -MailFromAddresses @("donotreply", "scanner", "alerts") `
        -MailFromDisplayNames @("Do Not Reply", "Scanner", "System Alerts") `
        -TestRecipientEmail "admin@contoso.com"

    Full deployment with automated Azure DNS. Creates all resources, DNS records,
    Entra app, and sends a test email.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-prod-eastus-rg" `
        -CommunicationServiceName "acs-contoso" `
        -EmailServiceName "acs-email-contoso-prod-eastus" `
        -CustomDomainName "contoso.com" `
        -AddSmtpEndpoint `
        -EntraAppName "acs-smtp-printers" `
        -SmtpUsername "printer-smtp" `
        -NewMailFromAddress "scanner" `
        -NewMailFromDisplayName "Scanner" `
        -TestRecipientEmail "admin@contoso.com"

    Adds a new SMTP endpoint for printers to an existing deployment. Creates a
    dedicated Entra app, SMTP username (printer-smtp@contoso.com), and MailFrom
    address (scanner@contoso.com) with independent credentials.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-prod-eastus-rg" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "contoso.com" `
        -TestEmailOnly `
        -SmtpPassword "your-client-secret-here" `
        -TestRecipientEmail "admin@contoso.com"

    Sends a test email using existing ACS infrastructure. Use after completing
    manual domain verification or SMTP username creation.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-prod-eastus-rg" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "contoso.com" `
        -TestEmailOnly `
        -TestRecipientEmail "admin@contoso.com"

    Sends a test email with secure password prompt (no password on command line).

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-prod-eastus-rg" `
        -EmailServiceName "acs-email-contoso-prod-eastus" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "contoso.com" `
        -MailFromAddresses @("donotreply", "scanner", "alerts") `
        -MailFromDisplayNames @("Do Not Reply", "Scanner", "System Alerts") `
        -TestRecipientEmail "admin@contoso.com"

    Full deployment without Azure DNS automation. DNS records must be added
    manually (interactive prompts guide you through the process).

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "acs-email-test-eastus-rg" `
        -EmailServiceName "acs-email-test" `
        -CommunicationServiceName "acs-test" `
        -UseAzureManagedDomain `
        -TestRecipientEmail "admin@contoso.com"

    Quick test deployment with an Azure-managed domain. No DNS configuration needed.

.NOTES
    Script Name  : Deploy-ACSEmail.ps1
    Version      : 2.0.0
    Author       : John O'Neill Sr.
    Company      : Azure Innovators
    Website      : https://www.azureinnovators.com
    Blog         : https://azureinnovators.com/blog
    GitHub       : https://github.com/JONeillSr/acs-email-toolkit

    Prerequisites:
    - Azure PowerShell module (Az): Install-Module -Name Az -Force
    - Az.Communication module: Install-Module -Name Az.Communication -Force
    - Az.Dns module (only for Azure DNS automation): Install-Module -Name Az.Dns -Force
    - Azure CLI (required for domain verification and Entra app operations)
    - Azure and Entra ID permissions:
        * Azure Subscription Contributor or Owner
        * Entra ID Application Administrator or Global Administrator
        * DNS Zone Contributor (only for Azure DNS automation)
    - PowerShell 7.0 or later recommended

    Change Log:
    v2.0.0 - 2026-04-30 - Added -TestEmailOnly mode for re-testing after manual steps,
                          added -AddSmtpEndpoint mode for adding endpoints to existing
                          deployments, SMTP username now uses email format (user@domain)
                          for copier/printer compatibility, test email tries custom
                          username then falls back to legacy format, domain verification
                          polling with retry (up to 3 minutes) and Portal URL guidance,
                          tenant-aware subscription selector with Az CLI sync,
                          New-AzCommunicationServiceSmtpUsername cmdlet tried before
                          REST API fallback
    v1.2.0 - 2026-04-29 - Added interactive subscription selector for multi-subscription
                          environments, DnsZoneSubscriptionId parameter for cross-subscription
                          DNS, improved domain linking error handling for unverified domains,
                          fixed client secret JSON parsing for Az CLI warning output,
                          Az CLI context synchronized with Az PowerShell subscription selection
    v1.1.0 - 2026-04-29 - Added Azure DNS automation (New-ACSDnsRecords function),
                          DnsZoneResourceGroupName and DnsZoneName parameters,
                          domain creation retry with Az CLI fallback,
                          resource provider auto-registration,
                          improved error handling with -ErrorAction Stop,
                          fixed empty string Write-Log calls
    v1.0.0 - 2026-04-29 - Initial release
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Resource Group name for ACS resources")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(HelpMessage = "Azure region for the Resource Group")]
    [string]$Location = "eastus",

    [Parameter(HelpMessage = "Data location for ACS resources")]
    [ValidateSet("UnitedStates", "Europe", "UnitedKingdom", "Japan", "Australia")]
    [string]$DataLocation = "UnitedStates",

    [Parameter(Mandatory = $true, HelpMessage = "Email Communication Service name")]
    [ValidateNotNullOrEmpty()]
    [string]$EmailServiceName,

    [Parameter(Mandatory = $true, HelpMessage = "Communication Service name (keep short)")]
    [ValidateNotNullOrEmpty()]
    [string]$CommunicationServiceName,

    [Parameter(HelpMessage = "Custom domain name for sending email")]
    [string]$CustomDomainName,

    [Parameter(HelpMessage = "Array of MailFrom sender usernames")]
    [string[]]$MailFromAddresses = @("DoNotReply"),

    [Parameter(HelpMessage = "Array of display names for MailFrom addresses")]
    [string[]]$MailFromDisplayNames = @("Do Not Reply"),

    [Parameter(HelpMessage = "Entra ID App Registration display name")]
    [string]$EntraAppName = "acs-smtp-relay",

    [Parameter(HelpMessage = "Custom SMTP Username (keep short for device compatibility)")]
    [string]$SmtpUsername = "acs-smtp",

    [Parameter(HelpMessage = "Client secret expiration in months")]
    [ValidateRange(1, 24)]
    [int]$SecretExpirationMonths = 12,

    [Parameter(HelpMessage = "Email address for test email")]
    [string]$TestRecipientEmail,

    [Parameter(HelpMessage = "Skip interactive domain verification")]
    [switch]$SkipDomainVerification,

    [Parameter(HelpMessage = "Use Azure-managed domain instead of custom")]
    [switch]$UseAzureManagedDomain,

    [Parameter(HelpMessage = "Azure DNS Zone Resource Group (enables automatic DNS record creation)")]
    [string]$DnsZoneResourceGroupName,

    [Parameter(HelpMessage = "Azure DNS Zone name (defaults to CustomDomainName if not specified)")]
    [string]$DnsZoneName,

    [Parameter(HelpMessage = "Subscription ID where the Azure DNS Zone resides (if different from ACS subscription)")]
    [string]$DnsZoneSubscriptionId,

    [Parameter(HelpMessage = "Send a test email only using existing ACS deployment (skips all resource creation)")]
    [switch]$TestEmailOnly,

    [Parameter(HelpMessage = "SMTP password/client secret for test email (used with -TestEmailOnly)")]
    [string]$SmtpPassword,

    [Parameter(HelpMessage = "Add a new SMTP endpoint to an existing ACS deployment (new Entra app, role, SMTP username, MailFrom)")]
    [switch]$AddSmtpEndpoint,

    [Parameter(HelpMessage = "MailFrom username for the new endpoint (used with -AddSmtpEndpoint)")]
    [string]$NewMailFromAddress,

    [Parameter(HelpMessage = "Display name for the new MailFrom address (used with -AddSmtpEndpoint)")]
    [string]$NewMailFromDisplayName
)

#Requires -Version 5.1

# ============================================================================
# CONFIGURATION
# ============================================================================

$ErrorActionPreference = "Stop"
$script:LogFile = Join-Path $PSScriptRoot "Deploy-ACSEmail_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to both the console and a log file with timestamp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor Cyan }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
    }

    Add-Content -Path $script:LogFile -Value $logEntry
}

# ============================================================================
# PREREQUISITE VALIDATION
# ============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that all required modules, tools, and parameters are available.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Validating prerequisites..." -Level INFO

    # Check required Az modules and install if missing
    $requiredModules = @("Az.Accounts", "Az.Resources", "Az.Communication")

    # Add Az.Dns if Azure DNS automation is requested
    if (-not [string]::IsNullOrWhiteSpace($DnsZoneResourceGroupName)) {
        $requiredModules += "Az.Dns"
    }

    foreach ($moduleName in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            Write-Log "$moduleName module not found. Installing..." -Level WARNING
            try {
                Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser
                Write-Log "$moduleName module installed." -Level SUCCESS
            }
            catch {
                Write-Log "Failed to install $moduleName. Run manually: Install-Module -Name $moduleName -Force -Scope CurrentUser" -Level ERROR
                throw "Required module $moduleName could not be installed."
            }
        }
        else {
            Write-Log "$moduleName module is available." -Level INFO
        }
    }

    # Check Azure CLI
    try {
        $null = az --version 2>&1
        Write-Log "Azure CLI is available." -Level INFO
    }
    catch {
        Write-Log "Azure CLI is required but not installed. Please install from https://aka.ms/installazurecli" -Level ERROR
        throw "Azure CLI not found."
    }

    # Validate MailFrom arrays match
    if ($MailFromAddresses.Count -ne $MailFromDisplayNames.Count) {
        Write-Log "MailFromAddresses count ($($MailFromAddresses.Count)) must match MailFromDisplayNames count ($($MailFromDisplayNames.Count))." -Level ERROR
        throw "MailFrom parameter mismatch."
    }

    # Validate domain parameters
    if (-not $UseAzureManagedDomain -and [string]::IsNullOrWhiteSpace($CustomDomainName)) {
        Write-Log "Either -CustomDomainName or -UseAzureManagedDomain must be specified." -Level ERROR
        throw "No domain specified."
    }

    # Check Azure login
    $context = Get-AzContext
    if (-not $context) {
        Write-Log "Not logged into Azure. Running Connect-AzAccount..." -Level WARNING
        Connect-AzAccount
        $context = Get-AzContext
    }

    # Subscription selection - prompt if multiple subscriptions exist
    $subscriptions = Get-AzSubscription -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Enabled" }

    if ($subscriptions.Count -gt 1) {
        Write-Log "Multiple Azure subscriptions found:" -Level INFO
        Write-Log " " -Level INFO
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            $current = if ($subscriptions[$i].Id -eq $context.Subscription.Id) { " (current)" } else { "" }
            $tenantLabel = $subscriptions[$i].TenantId
            Write-Log "  [$($i + 1)] $($subscriptions[$i].Name) ($($subscriptions[$i].Id)) [Tenant: $tenantLabel]$current" -Level INFO
        }
        Write-Log " " -Level INFO

        $selection = Read-Host "Select the subscription for this deployment (1-$($subscriptions.Count)), or press ENTER to keep current"

        if (-not [string]::IsNullOrWhiteSpace($selection)) {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $subscriptions.Count) {
                $selectedSub = $subscriptions[$selectedIndex]
                Set-AzContext -SubscriptionId $selectedSub.Id -TenantId $selectedSub.TenantId | Out-Null
                Write-Log "Switched to subscription: $($selectedSub.Name) (Tenant: $($selectedSub.TenantId))" -Level SUCCESS
                $context = Get-AzContext
            }
            else {
                Write-Log "Invalid selection. Using current subscription." -Level WARNING
            }
        }
        else {
            Write-Log "Keeping current subscription: $($context.Subscription.Name)" -Level INFO
        }
    }

    $activeTenantId = $context.Tenant.Id
    $activeSubId = $context.Subscription.Id
    Write-Log "Active subscription: '$($context.Subscription.Name)' ($activeSubId)" -Level INFO
    Write-Log "Active tenant: $activeTenantId" -Level INFO

    # Ensure Az CLI is logged into the SAME tenant and subscription as Az PowerShell
    # This is critical for multi-tenant environments (e.g., consultants managing client tenants)
    Write-Log "Synchronizing Azure CLI to the same tenant and subscription..." -Level INFO

    $cliAccountJson = az account show -o json 2>&1
    $cliNeedsLogin = $false

    if ($LASTEXITCODE -ne 0) {
        $cliNeedsLogin = $true
    }
    else {
        try {
            $cliAccount = $cliAccountJson | ConvertFrom-Json
            if ($cliAccount.tenantId -ne $activeTenantId) {
                Write-Log "Az CLI is on tenant '$($cliAccount.tenantId)' but needs to be on '$activeTenantId'. Re-authenticating..." -Level WARNING
                $cliNeedsLogin = $true
            }
        }
        catch {
            $cliNeedsLogin = $true
        }
    }

    if ($cliNeedsLogin) {
        Write-Log "Logging Az CLI into tenant '$activeTenantId'..." -Level INFO
        az login --tenant $activeTenantId 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Az CLI interactive login required for tenant '$activeTenantId'..." -Level WARNING
            az login --tenant $activeTenantId --use-device-code
        }
    }

    az account set --subscription $activeSubId 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to set Az CLI subscription. Trying explicit login..." -Level WARNING
        az login --tenant $activeTenantId --use-device-code
        az account set --subscription $activeSubId 2>&1 | Out-Null
    }

    # Verify CLI is synced
    $cliVerify = az account show --query "{tenantId:tenantId, id:id}" -o json 2>&1 | ConvertFrom-Json
    if ($cliVerify.tenantId -eq $activeTenantId -and $cliVerify.id -eq $activeSubId) {
        Write-Log "Az CLI synchronized: tenant '$activeTenantId', subscription '$activeSubId'" -Level SUCCESS
    }
    else {
        Write-Log "WARNING: Az CLI may not be synchronized. CLI tenant: $($cliVerify.tenantId), CLI sub: $($cliVerify.id)" -Level WARNING
        Write-Log "Entra app operations may fail. Consider running: az login --tenant $activeTenantId --use-device-code" -Level WARNING
    }

    # Check Microsoft.Communication resource provider registration
    Write-Log "Checking Microsoft.Communication resource provider..." -Level INFO
    $provider = Get-AzResourceProvider -ProviderNamespace Microsoft.Communication -ErrorAction SilentlyContinue
    if (-not $provider -or $provider[0].RegistrationState -ne "Registered") {
        Write-Log "Microsoft.Communication provider not registered. Registering..." -Level WARNING
        Register-AzResourceProvider -ProviderNamespace Microsoft.Communication | Out-Null

        # Wait for registration
        $maxWait = 120
        $elapsed = 0
        do {
            Start-Sleep -Seconds 10
            $elapsed += 10
            $provider = Get-AzResourceProvider -ProviderNamespace Microsoft.Communication
            Write-Log "Registration state: $($provider[0].RegistrationState) (waited $elapsed seconds)..." -Level INFO
        } while ($provider[0].RegistrationState -ne "Registered" -and $elapsed -lt $maxWait)

        if ($provider[0].RegistrationState -eq "Registered") {
            Write-Log "Microsoft.Communication provider registered successfully." -Level SUCCESS
        }
        else {
            Write-Log "Provider registration timed out. Please register manually: Register-AzResourceProvider -ProviderNamespace Microsoft.Communication" -Level ERROR
            throw "Resource provider registration failed."
        }
    }
    else {
        Write-Log "Microsoft.Communication provider is registered." -Level INFO
    }

    Write-Log "All prerequisites validated." -Level SUCCESS
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================

function New-ACSResourceGroup {
    <#
    .SYNOPSIS
        Creates the Resource Group if it doesn't already exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Checking Resource Group '$ResourceGroupName'..." -Level INFO

    $existingRg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if ($existingRg) {
        Write-Log "Resource Group '$ResourceGroupName' already exists in '$($existingRg.Location)'." -Level INFO
        return $existingRg
    }

    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group")) {
        Write-Log "Creating Resource Group '$ResourceGroupName' in '$Location'..." -Level INFO
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag @{
            Purpose     = "ACS-Email"
            CreatedBy   = "Deploy-ACSEmail.ps1"
            CreatedDate = (Get-Date -Format "yyyy-MM-dd")
            Company     = "Azure Innovators"
        }
        Write-Log "Resource Group '$ResourceGroupName' created successfully." -Level SUCCESS
        return $rg
    }
}

# ============================================================================
# EMAIL COMMUNICATION SERVICE
# ============================================================================

function New-ACSEmailService {
    <#
    .SYNOPSIS
        Creates the Email Communication Service resource.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Checking Email Communication Service '$EmailServiceName'..." -Level INFO

    $existing = Get-AzEmailService -ResourceGroupName $ResourceGroupName -Name $EmailServiceName -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Log "Email Communication Service '$EmailServiceName' already exists." -Level INFO
        return $existing
    }

    if ($PSCmdlet.ShouldProcess($EmailServiceName, "Create Email Communication Service")) {
        Write-Log "Creating Email Communication Service '$EmailServiceName'..." -Level INFO
        try {
            $emailService = New-AzEmailService `
                -ResourceGroupName $ResourceGroupName `
                -Name $EmailServiceName `
                -DataLocation $DataLocation `
                -ErrorAction Stop

            Write-Log "Email Communication Service '$EmailServiceName' created successfully." -Level SUCCESS
            return $emailService
        }
        catch {
            Write-Log "Failed to create Email Communication Service: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }
}

# ============================================================================
# COMMUNICATION SERVICE
# ============================================================================

function New-ACSCommunicationService {
    <#
    .SYNOPSIS
        Creates the Communication Service resource.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Checking Communication Service '$CommunicationServiceName'..." -Level INFO

    $existing = Get-AzCommunicationService -ResourceGroupName $ResourceGroupName -Name $CommunicationServiceName -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Log "Communication Service '$CommunicationServiceName' already exists." -Level INFO
        return $existing
    }

    if ($PSCmdlet.ShouldProcess($CommunicationServiceName, "Create Communication Service")) {
        Write-Log "Creating Communication Service '$CommunicationServiceName'..." -Level INFO
        try {
            $commService = New-AzCommunicationService `
                -ResourceGroupName $ResourceGroupName `
                -Name $CommunicationServiceName `
                -DataLocation $DataLocation `
                -Location "Global" `
                -ErrorAction Stop

            Write-Log "Communication Service '$CommunicationServiceName' created successfully." -Level SUCCESS
            return $commService
        }
        catch {
            Write-Log "Failed to create Communication Service: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }
}

# ============================================================================
# DOMAIN CONFIGURATION
# ============================================================================

function New-ACSEmailDomain {
    <#
    .SYNOPSIS
        Creates and optionally verifies an email domain (Azure-managed or custom).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($UseAzureManagedDomain) {
        Write-Log "Creating Azure-managed domain..." -Level INFO

        if ($PSCmdlet.ShouldProcess("AzureManagedDomain", "Create Azure Managed Domain")) {
            $domain = New-AzEmailServiceDomain `
                -ResourceGroupName $ResourceGroupName `
                -EmailServiceName $EmailServiceName `
                -Name "AzureManagedDomain" `
                -DomainManagement "AzureManaged"

            Write-Log "Azure-managed domain created successfully." -Level SUCCESS
            Write-Log "Azure-managed domain sender: DoNotReply@$($domain.MailFromSenderDomain)" -Level INFO
            return $domain
        }
    }
    else {
        Write-Log "Creating custom domain '$CustomDomainName'..." -Level INFO

        if ($PSCmdlet.ShouldProcess($CustomDomainName, "Create Custom Domain")) {
            $domain = $null
            $maxRetries = 3
            $retryDelay = 15

            for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
                # Attempt 1-2: Use Az PowerShell module
                if ($attempt -le 2) {
                    try {
                        Write-Log "Attempt $attempt of $maxRetries (Az PowerShell)..." -Level INFO
                        $domain = New-AzEmailServiceDomain `
                            -ResourceGroupName $ResourceGroupName `
                            -EmailServiceName $EmailServiceName `
                            -Name $CustomDomainName `
                            -DomainManagement "CustomerManaged" `
                            -ErrorAction Stop

                        Write-Log "Custom domain '$CustomDomainName' created." -Level SUCCESS
                        break
                    }
                    catch {
                        Write-Log "Attempt $attempt failed: $($_.Exception.Message)" -Level WARNING
                        if ($attempt -lt $maxRetries) {
                            Write-Log "Waiting $retryDelay seconds before retry (Email Service may still be provisioning)..." -Level INFO
                            Start-Sleep -Seconds $retryDelay
                        }
                    }
                }
                # Attempt 3: Fallback to Az CLI
                else {
                    Write-Log "Attempt $attempt of $maxRetries (Az CLI fallback)..." -Level INFO
                    try {
                        $cliResult = az communication email domain create `
                            --domain-name $CustomDomainName `
                            --email-service-name $EmailServiceName `
                            --location "Global" `
                            --resource-group $ResourceGroupName `
                            --domain-management "CustomerManaged" `
                            -o json 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            Write-Log "Custom domain '$CustomDomainName' created via Az CLI." -Level SUCCESS
                            # Retrieve the domain object via PowerShell for consistency
                            $domain = Get-AzEmailServiceDomain `
                                -ResourceGroupName $ResourceGroupName `
                                -EmailServiceName $EmailServiceName `
                                -Name $CustomDomainName -ErrorAction SilentlyContinue
                            break
                        }
                        else {
                            Write-Log "Az CLI fallback failed: $cliResult" -Level ERROR
                            throw "All $maxRetries attempts to create domain '$CustomDomainName' failed."
                        }
                    }
                    catch {
                        Write-Log "Az CLI fallback failed: $($_.Exception.Message)" -Level ERROR
                        throw
                    }
                }
            }

            if (-not $domain) {
                Write-Log "Domain creation failed after $maxRetries attempts." -Level ERROR
                throw "Could not create domain '$CustomDomainName'."
            }

            if (-not $SkipDomainVerification) {
                Request-DomainVerification
            }
            else {
                Write-Log "Domain verification skipped. Verify manually in the Azure Portal." -Level WARNING
            }

            return $domain
        }
    }
}

function Request-DomainVerification {
    <#
    .SYNOPSIS
        Orchestrates domain verification - auto-creates DNS records if Azure DNS
        is configured, otherwise guides the user through manual DNS creation.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Starting domain verification for '$CustomDomainName'..." -Level INFO

    # Retrieve the domain to get verification records
    $domain = Get-AzEmailServiceDomain `
        -ResourceGroupName $ResourceGroupName `
        -EmailServiceName $EmailServiceName `
        -Name $CustomDomainName

    if (-not $domain.VerificationRecord) {
        Write-Log "No verification records found on domain. Check the Azure Portal." -Level ERROR
        return
    }

    # Parse verification records from the domain object
    $verificationRecords = $domain.VerificationRecord | ConvertFrom-Json

    # Check if Azure DNS automation is available
    if (-not [string]::IsNullOrWhiteSpace($DnsZoneResourceGroupName)) {
        $zoneName = if (-not [string]::IsNullOrWhiteSpace($DnsZoneName)) { $DnsZoneName } else { $CustomDomainName }
        New-ACSDnsRecords -VerificationRecords $verificationRecords -ZoneResourceGroup $DnsZoneResourceGroupName -ZoneName $zoneName
    }
    else {
        # Manual DNS guidance
        Write-Log "============================================================" -Level WARNING
        Write-Log "ACTION REQUIRED: Add DNS records for domain verification" -Level WARNING
        Write-Log "============================================================" -Level WARNING
        Write-Log " " -Level INFO
        Write-Log "Add the following records to your DNS provider:" -Level INFO
        Write-Log " " -Level INFO
        Write-Log "1. TXT Record (Domain Verification):" -Level INFO
        Write-Log "   Name: $($verificationRecords.Domain.name)" -Level INFO
        Write-Log "   Value: $($verificationRecords.Domain.value)" -Level INFO
        Write-Log " " -Level INFO
        Write-Log "2. TXT Record (SPF):" -Level INFO
        Write-Log "   Name: $($verificationRecords.SPF.name)" -Level INFO
        Write-Log "   Value: $($verificationRecords.SPF.value)" -Level INFO
        Write-Log " " -Level INFO
        Write-Log "3. CNAME Record (DKIM):" -Level INFO
        Write-Log "   Name: $($verificationRecords.DKIM.name)" -Level INFO
        Write-Log "   Value: $($verificationRecords.DKIM.value)" -Level INFO
        Write-Log " " -Level INFO
        Write-Log "4. CNAME Record (DKIM2):" -Level INFO
        Write-Log "   Name: $($verificationRecords.DKIM2.name)" -Level INFO
        Write-Log "   Value: $($verificationRecords.DKIM2.value)" -Level INFO
        Write-Log " " -Level INFO

        $continue = Read-Host "Press ENTER once DNS records are added (or type 'skip' to continue without verification)"

        if ($continue -eq "skip") {
            Write-Log "Verification skipped. Complete verification in the Azure Portal before sending email." -Level WARNING
            return
        }
    }

    # Initiate verification for each record type
    $verificationTypes = @("Domain", "SPF", "DKIM", "DKIM2")
    $allVerified = $true

    foreach ($vType in $verificationTypes) {
        Write-Log "Initiating $vType verification..." -Level INFO
        try {
            az communication email domain initiate-verification `
                --domain-name $CustomDomainName `
                --email-service-name $EmailServiceName `
                --resource-group $ResourceGroupName `
                --verification-type $vType 2>&1 | Out-Null

            Write-Log "$vType verification initiated." -Level INFO
        }
        catch {
            Write-Log "$vType verification failed or already verified: $($_.Exception.Message)" -Level WARNING
        }
    }

    # Poll for verification completion with retries
    $maxVerifyAttempts = 6
    $verifyInterval = 30
    $allVerified = $false

    for ($vAttempt = 1; $vAttempt -le $maxVerifyAttempts; $vAttempt++) {
        Write-Log "Waiting $verifyInterval seconds for verification (attempt $vAttempt of $maxVerifyAttempts)..." -Level INFO
        Start-Sleep -Seconds $verifyInterval

        $domainStatus = Get-AzEmailServiceDomain `
            -ResourceGroupName $ResourceGroupName `
            -EmailServiceName $EmailServiceName `
            -Name $CustomDomainName

        $statusMap = @{
            "Domain" = $domainStatus.DomainVerificationStatusDomain
            "SPF"    = $domainStatus.DomainVerificationStatusSpf
            "DKIM"   = $domainStatus.DomainVerificationStatusDkim
            "DKIM2"  = $domainStatus.DomainVerificationStatusDkim2
        }

        $pendingCount = 0
        foreach ($key in $statusMap.Keys) {
            $status = $statusMap[$key]
            if ($status -eq "Verified") {
                Write-Log "$key verification: $status" -Level SUCCESS
            }
            else {
                Write-Log "$key verification: $status" -Level WARNING
                $pendingCount++
            }
        }

        if ($pendingCount -eq 0) {
            $allVerified = $true
            Write-Log "All domain verifications passed." -Level SUCCESS
            break
        }

        # Re-initiate verification on pending items
        if ($vAttempt -lt $maxVerifyAttempts) {
            foreach ($vType in $verificationTypes) {
                $typeStatus = $statusMap[$vType]
                if ($typeStatus -ne "Verified") {
                    try {
                        az communication email domain initiate-verification `
                            --domain-name $CustomDomainName `
                            --email-service-name $EmailServiceName `
                            --resource-group $ResourceGroupName `
                            --verification-type $vType 2>&1 | Out-Null
                    }
                    catch { }
                }
            }
        }
    }

    if (-not $allVerified) {
        $subscriptionId = (Get-AzContext).Subscription.Id
        $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Communication/emailServices/$EmailServiceName/provision"

        Write-Log "Some verifications are still pending after $($maxVerifyAttempts * $verifyInterval) seconds." -Level WARNING
        Write-Log "Complete verification manually in the Azure Portal:" -Level WARNING
        Write-Log "  1. Open: $portalUrl" -Level WARNING
        Write-Log "  2. Click on '$CustomDomainName'" -Level WARNING
        Write-Log "  3. Click 'Verify' for each pending record type" -Level WARNING
        Write-Log "  4. After all four show 'Verified', link the domain using the command below" -Level WARNING
        Write-Log " " -Level INFO
        Write-Log "After verification, run the test with: -TestEmailOnly -SmtpPassword '<your-secret>'" -Level INFO
    }
}

# ============================================================================
# AZURE DNS RECORD AUTOMATION
# ============================================================================

function New-ACSDnsRecords {
    <#
    .SYNOPSIS
        Automatically creates or updates DNS records in an Azure DNS Zone for
        ACS Email domain verification (Domain TXT, SPF TXT, DKIM CNAME, DKIM2 CNAME).
        Intelligently merges with existing records to avoid conflicts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$VerificationRecords,

        [Parameter(Mandatory)]
        [string]$ZoneResourceGroup,

        [Parameter(Mandatory)]
        [string]$ZoneName
    )

    Write-Log "Configuring Azure DNS records in zone '$ZoneName' (RG: $ZoneResourceGroup)..." -Level INFO

    # Switch subscription context if DNS zone is in a different subscription
    $originalContext = $null
    if (-not [string]::IsNullOrWhiteSpace($DnsZoneSubscriptionId)) {
        $currentSubId = (Get-AzContext).Subscription.Id
        if ($DnsZoneSubscriptionId -ne $currentSubId) {
            Write-Log "DNS zone is in a different subscription. Switching context..." -Level INFO
            $originalContext = Get-AzContext
            Set-AzContext -SubscriptionId $DnsZoneSubscriptionId | Out-Null
            Write-Log "Switched to subscription '$DnsZoneSubscriptionId' for DNS operations." -Level INFO
        }
    }

    try {
    # Verify the DNS zone exists
    try {
        $zone = Get-AzDnsZone -ResourceGroupName $ZoneResourceGroup -Name $ZoneName -ErrorAction Stop
        Write-Log "Azure DNS Zone '$ZoneName' found." -Level INFO
    }
    catch {
        Write-Log "Azure DNS Zone '$ZoneName' not found in Resource Group '$ZoneResourceGroup'. Cannot auto-create DNS records." -Level ERROR
        Write-Log "If the DNS zone is in a different subscription, use -DnsZoneSubscriptionId parameter." -Level WARNING
        Write-Log "Falling back to manual DNS guidance." -Level WARNING
        return
    }

    # Determine the record name for the root domain
    # If domain matches zone name, use "@". If subdomain, extract the relative name.
    if ($CustomDomainName -eq $ZoneName) {
        $rootRecordName = "@"
    }
    else {
        # Subdomain: e.g., notify.contoso.com in zone contoso.com -> "notify"
        $rootRecordName = $CustomDomainName.Replace(".$ZoneName", "")
    }

    # --- 1. Domain Verification TXT Record ---
    Write-Log "Adding Domain verification TXT record..." -Level INFO
    $domainVerifValue = $VerificationRecords.Domain.value

    try {
        $existingTxt = Get-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
            -Name $rootRecordName -RecordType TXT -ErrorAction SilentlyContinue

        if ($existingTxt) {
            # Check if the verification value already exists
            $alreadyExists = $existingTxt.Records | Where-Object { $_.Value -contains $domainVerifValue }
            if ($alreadyExists) {
                Write-Log "Domain verification TXT record already exists. Skipping." -Level INFO
            }
            else {
                Add-AzDnsRecordConfig -RecordSet $existingTxt -Value $domainVerifValue
                Set-AzDnsRecordSet -RecordSet $existingTxt | Out-Null
                Write-Log "Domain verification TXT value added to existing record set." -Level SUCCESS
            }
        }
        else {
            New-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
                -Name $rootRecordName -RecordType TXT -Ttl 3600 `
                -DnsRecords (New-AzDnsRecordConfig -Value $domainVerifValue) | Out-Null
            Write-Log "Domain verification TXT record created." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Failed to create Domain verification TXT record: $($_.Exception.Message)" -Level WARNING
    }

    # --- 2. SPF TXT Record ---
    Write-Log "Adding SPF TXT record..." -Level INFO
    $spfValue = $VerificationRecords.SPF.value

    try {
        # Re-fetch in case we just modified it above
        $existingTxt = Get-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
            -Name $rootRecordName -RecordType TXT -ErrorAction SilentlyContinue

        if ($existingTxt) {
            # Check if there's already an SPF record
            $existingSpf = $existingTxt.Records | Where-Object { $_.Value -like "*v=spf1*" }

            if ($existingSpf) {
                $currentSpfValue = ($existingSpf.Value | Where-Object { $_ -like "v=spf1*" })

                if ($currentSpfValue -and $currentSpfValue -notlike "*include:spf.protection.outlook.com*") {
                    # Need to merge: add the include before the -all or ~all
                    $mergedSpf = $currentSpfValue -replace '(\s[-~]all)', ' include:spf.protection.outlook.com$1'
                    Write-Log "Merging ACS SPF include into existing SPF record..." -Level INFO

                    # Remove old SPF, add merged
                    Remove-AzDnsRecordConfig -RecordSet $existingTxt -Value $currentSpfValue | Out-Null
                    Add-AzDnsRecordConfig -RecordSet $existingTxt -Value $mergedSpf | Out-Null
                    Set-AzDnsRecordSet -RecordSet $existingTxt | Out-Null
                    Write-Log "SPF record merged: $mergedSpf" -Level SUCCESS
                }
                else {
                    Write-Log "SPF record already includes ACS SPF. Skipping." -Level INFO
                }
            }
            else {
                # No SPF exists, add it
                Add-AzDnsRecordConfig -RecordSet $existingTxt -Value $spfValue | Out-Null
                Set-AzDnsRecordSet -RecordSet $existingTxt | Out-Null
                Write-Log "SPF TXT value added to existing record set." -Level SUCCESS
            }
        }
        else {
            New-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
                -Name $rootRecordName -RecordType TXT -Ttl 3600 `
                -DnsRecords (New-AzDnsRecordConfig -Value $spfValue) | Out-Null
            Write-Log "SPF TXT record created." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Failed to create/update SPF record: $($_.Exception.Message)" -Level WARNING
    }

    # --- 3. DKIM CNAME Record ---
    Write-Log "Adding DKIM CNAME record..." -Level INFO
    $dkimName = $VerificationRecords.DKIM.name
    $dkimValue = $VerificationRecords.DKIM.value

    try {
        $existingDkim = Get-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
            -Name $dkimName -RecordType CNAME -ErrorAction SilentlyContinue

        if ($existingDkim) {
            Write-Log "DKIM CNAME record already exists. Skipping." -Level INFO
        }
        else {
            New-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
                -Name $dkimName -RecordType CNAME -Ttl 3600 `
                -DnsRecords (New-AzDnsRecordConfig -Cname $dkimValue) | Out-Null
            Write-Log "DKIM CNAME record created." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Failed to create DKIM CNAME record: $($_.Exception.Message)" -Level WARNING
    }

    # --- 4. DKIM2 CNAME Record ---
    Write-Log "Adding DKIM2 CNAME record..." -Level INFO
    $dkim2Name = $VerificationRecords.DKIM2.name
    $dkim2Value = $VerificationRecords.DKIM2.value

    try {
        $existingDkim2 = Get-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
            -Name $dkim2Name -RecordType CNAME -ErrorAction SilentlyContinue

        if ($existingDkim2) {
            Write-Log "DKIM2 CNAME record already exists. Skipping." -Level INFO
        }
        else {
            New-AzDnsRecordSet -ResourceGroupName $ZoneResourceGroup -ZoneName $ZoneName `
                -Name $dkim2Name -RecordType CNAME -Ttl 3600 `
                -DnsRecords (New-AzDnsRecordConfig -Cname $dkim2Value) | Out-Null
            Write-Log "DKIM2 CNAME record created." -Level SUCCESS
        }
    }
    catch {
        Write-Log "Failed to create DKIM2 CNAME record: $($_.Exception.Message)" -Level WARNING
    }

    Write-Log "Azure DNS record configuration complete." -Level SUCCESS

    } # end of outer try
    finally {
        # Restore original subscription context if we switched
        if ($originalContext) {
            Write-Log "Restoring original subscription context..." -Level INFO
            Set-AzContext -Context $originalContext | Out-Null
        }
    }
}

# ============================================================================
# MAILFROM SENDER ADDRESSES
# ============================================================================

function New-ACSMailFromAddresses {
    <#
    .SYNOPSIS
        Creates MailFrom sender addresses for the configured domain.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $domainName = if ($UseAzureManagedDomain) { "AzureManagedDomain" } else { $CustomDomainName }

    for ($i = 0; $i -lt $MailFromAddresses.Count; $i++) {
        $senderUsername = $MailFromAddresses[$i]
        $displayName = $MailFromDisplayNames[$i]

        # Skip DoNotReply as it's created by default
        if ($senderUsername -eq "DoNotReply") {
            Write-Log "Skipping 'DoNotReply' - created by default." -Level INFO
            continue
        }

        Write-Log "Creating MailFrom address: $senderUsername@$domainName (Display: $displayName)..." -Level INFO

        if ($PSCmdlet.ShouldProcess("$senderUsername@$domainName", "Create MailFrom Address")) {
            try {
                az communication email domain sender-username create `
                    --email-service-name $EmailServiceName `
                    --resource-group $ResourceGroupName `
                    --domain-name $domainName `
                    --sender-username $senderUsername `
                    --username $senderUsername `
                    --display-name $displayName 2>&1 | Out-Null

                Write-Log "MailFrom address '$senderUsername@$domainName' created." -Level SUCCESS
            }
            catch {
                Write-Log "Failed to create MailFrom '$senderUsername': $($_.Exception.Message)" -Level WARNING
            }
        }
    }
}

# ============================================================================
# LINK DOMAIN TO COMMUNICATION SERVICE
# ============================================================================

function Connect-ACSDomain {
    <#
    .SYNOPSIS
        Links the verified email domain to the Communication Service resource.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $domainName = if ($UseAzureManagedDomain) { "AzureManagedDomain" } else { $CustomDomainName }
    $subscriptionId = (Get-AzContext).Subscription.Id

    $domainResourceId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Communication/emailServices/$EmailServiceName/domains/$domainName"

    Write-Log "Linking domain '$domainName' to Communication Service '$CommunicationServiceName'..." -Level INFO

    if ($PSCmdlet.ShouldProcess($CommunicationServiceName, "Link Domain")) {
        try {
            Update-AzCommunicationService `
                -ResourceGroupName $ResourceGroupName `
                -Name $CommunicationServiceName `
                -LinkedDomain @($domainResourceId) `
                -ErrorAction Stop

            Write-Log "Domain linked to Communication Service successfully." -Level SUCCESS
        }
        catch {
            if ($_.Exception.Message -like "*not in a valid state*") {
                Write-Log "Domain is not yet verified - cannot link until verification completes." -Level WARNING
                Write-Log "After DNS verification is complete, link the domain manually:" -Level WARNING
                Write-Log "  Update-AzCommunicationService -ResourceGroupName '$ResourceGroupName' -Name '$CommunicationServiceName' -LinkedDomain @('$domainResourceId')" -Level WARNING
            }
            else {
                Write-Log "Failed to link domain: $($_.Exception.Message)" -Level ERROR
                throw
            }
        }
    }
}

# ============================================================================
# ENTRA ID APP REGISTRATION
# ============================================================================

function New-ACSEntraApp {
    <#
    .SYNOPSIS
        Creates an Entra ID App Registration and client secret for SMTP authentication.
    .OUTPUTS
        PSCustomObject with AppId, TenantId, and ClientSecret properties.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Log "Creating Entra ID App Registration '$EntraAppName'..." -Level INFO

    if ($PSCmdlet.ShouldProcess($EntraAppName, "Create Entra App Registration")) {

        # Check if app already exists
        $existingApp = az ad app list --display-name $EntraAppName --query "[0]" -o json 2>&1 | ConvertFrom-Json

        if ($existingApp.appId) {
            Write-Log "App Registration '$EntraAppName' already exists (AppId: $($existingApp.appId))." -Level INFO
            $appId = $existingApp.appId
        }
        else {
            # Create the app registration
            $appJson = az ad app create `
                --display-name $EntraAppName `
                --sign-in-audience "AzureADMyOrg" `
                -o json 2>&1

            $app = $appJson | ConvertFrom-Json
            $appId = $app.appId
            Write-Log "App Registration created. AppId: $appId" -Level SUCCESS

            # Create the service principal
            az ad sp create --id $appId 2>&1 | Out-Null
            Write-Log "Service Principal created for App Registration." -Level SUCCESS
        }

        # Create client secret
        $expirationDate = (Get-Date).AddMonths($SecretExpirationMonths).ToString("yyyy-MM-ddTHH:mm:ssZ")

        $secretOutput = az ad app credential reset `
            --id $appId `
            --append `
            --display-name "ACS-SMTP-Secret" `
            --end-date $expirationDate `
            -o json 2>&1

        # Filter out warning/info lines - keep only JSON content
        $jsonLines = ($secretOutput | Out-String).Split("`n") | Where-Object {
            $_.Trim().StartsWith('{') -or $_.Trim().StartsWith('"') -or
            $_.Trim().StartsWith('}') -or $_.Trim() -match '^[\[\]{},]' -or
            $_.Trim() -match '^\s*"'
        }

        if (-not $jsonLines) {
            # Fallback: try to find JSON object in the output
            $fullOutput = $secretOutput | Out-String
            $jsonMatch = [regex]::Match($fullOutput, '\{[^{}]*"password"[^{}]*\}')
            if ($jsonMatch.Success) {
                $jsonLines = $jsonMatch.Value
            }
            else {
                Write-Log "Failed to parse credential output. Raw output: $fullOutput" -Level ERROR
                throw "Could not parse client secret from az ad app credential reset output."
            }
        }

        $secretResult = ($jsonLines -join "`n") | ConvertFrom-Json
        $clientSecret = $secretResult.password
        $tenantId = $secretResult.tenant

        Write-Log "Client secret created. Expires: $expirationDate" -Level SUCCESS
        Write-Log "============================================================" -Level WARNING
        Write-Log "SAVE THIS SECRET NOW - it will not be shown again!" -Level WARNING
        Write-Log "Client Secret: $clientSecret" -Level WARNING
        Write-Log "============================================================" -Level WARNING

        return [PSCustomObject]@{
            AppId        = $appId
            TenantId     = $tenantId
            ClientSecret = $clientSecret
        }
    }
}

# ============================================================================
# IAM ROLE ASSIGNMENT
# ============================================================================

function Set-ACSRoleAssignment {
    <#
    .SYNOPSIS
        Assigns the Communication and Email Service Owner role to the Entra app
        directly on the Communication Service resource.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    $subscriptionId = (Get-AzContext).Subscription.Id
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Communication/CommunicationServices/$CommunicationServiceName"

    Write-Log "Assigning 'Communication and Email Service Owner' role..." -Level INFO
    Write-Log "IMPORTANT: Assigning directly on Communication Service resource (not Resource Group)." -Level INFO

    if ($PSCmdlet.ShouldProcess($CommunicationServiceName, "Assign IAM Role")) {
        # Wait for service principal to propagate through Entra ID
        Write-Log "Waiting 15 seconds for service principal propagation..." -Level INFO
        Start-Sleep -Seconds 15

        # Get the service principal object ID with retry
        $spObjectId = $null
        $maxSpRetries = 3

        for ($spAttempt = 1; $spAttempt -le $maxSpRetries; $spAttempt++) {
            Write-Log "Looking up service principal for AppId '$AppId' (attempt $spAttempt)..." -Level INFO

            $spOutput = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" -o tsv 2>&1
            # Filter out warning lines
            $spObjectId = ($spOutput | Out-String).Split("`n") | Where-Object {
                $_.Trim() -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            } | Select-Object -First 1

            if (-not [string]::IsNullOrWhiteSpace($spObjectId)) {
                $spObjectId = $spObjectId.Trim()
                Write-Log "Service principal found: $spObjectId" -Level INFO
                break
            }

            if ($spAttempt -lt $maxSpRetries) {
                Write-Log "Service principal not found yet. Waiting 10 seconds..." -Level WARNING
                Start-Sleep -Seconds 10
            }
        }

        if ([string]::IsNullOrWhiteSpace($spObjectId)) {
            Write-Log "Service principal not found after $maxSpRetries attempts." -Level ERROR
            Write-Log "Try assigning the role manually in the Azure Portal:" -Level WARNING
            Write-Log "  Communication Service > Access control (IAM) > Add role assignment" -Level WARNING
            Write-Log "  Role: Communication and Email Service Owner" -Level WARNING
            Write-Log "  Member: $EntraAppName (AppId: $AppId)" -Level WARNING
            throw "Service principal lookup failed."
        }

        try {
            New-AzRoleAssignment `
                -ObjectId $spObjectId `
                -RoleDefinitionName "Communication and Email Service Owner" `
                -Scope $scope `
                -ErrorAction Stop

            Write-Log "IAM role assigned successfully." -Level SUCCESS
        }
        catch {
            if ($_.Exception.Message -like "*Conflict*" -or $_.Exception.Message -like "*already exists*") {
                Write-Log "Role assignment already exists." -Level INFO
            }
            elseif ($_.Exception.Message -like "*BadRequest*") {
                Write-Log "Role assignment returned BadRequest. Retrying with az CLI..." -Level WARNING
                try {
                    az role assignment create `
                        --assignee $AppId `
                        --role "Communication and Email Service Owner" `
                        --scope $scope 2>&1 | Out-Null

                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "IAM role assigned successfully via Az CLI." -Level SUCCESS
                    }
                    else {
                        Write-Log "Az CLI role assignment also failed. Assign manually in Azure Portal." -Level WARNING
                        Write-Log "  Communication Service > Access control (IAM) > Add role assignment" -Level WARNING
                        Write-Log "  Role: Communication and Email Service Owner" -Level WARNING
                        Write-Log "  Member: $EntraAppName (AppId: $AppId)" -Level WARNING
                    }
                }
                catch {
                    Write-Log "Az CLI fallback failed: $($_.Exception.Message)" -Level WARNING
                    Write-Log "Assign the role manually and continue." -Level WARNING
                }
            }
            else {
                Write-Log "Failed to assign role: $($_.Exception.Message)" -Level ERROR
                throw
            }
        }

        # Wait for propagation
        Write-Log "Waiting 30 seconds for IAM propagation..." -Level INFO
        Start-Sleep -Seconds 30
    }
}

# ============================================================================
# SMTP USERNAME
# ============================================================================

function New-ACSSmtpUsername {
    <#
    .SYNOPSIS
        Creates a custom SMTP Username for the Communication Service.
        Uses email format (username@domain) which is compatible with copier/printer
        admin panels that expect email-style usernames.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    # Build the email-format SMTP username
    $domainName = if ($UseAzureManagedDomain) {
        $domain = Get-AzEmailServiceDomain -ResourceGroupName $ResourceGroupName -EmailServiceName $EmailServiceName -Name "AzureManagedDomain"
        $domain.MailFromSenderDomain
    }
    else {
        $CustomDomainName
    }
    $smtpUsernameEmail = "$SmtpUsername@$domainName"

    Write-Log "Creating SMTP Username '$smtpUsernameEmail'..." -Level INFO
    Write-Log "This email-format username is compatible with copier/printer admin panels." -Level INFO

    if ($PSCmdlet.ShouldProcess($smtpUsernameEmail, "Create SMTP Username")) {
        $subscriptionId = (Get-AzContext).Subscription.Id

        # Try Az PowerShell cmdlet first (New-AzCommunicationServiceSmtpUsername)
        try {
            New-AzCommunicationServiceSmtpUsername `
                -CommunicationServiceName $CommunicationServiceName `
                -ResourceGroupName $ResourceGroupName `
                -SmtpUsername $smtpUsernameEmail `
                -EntraApplicationId $AppId `
                -Username $smtpUsernameEmail `
                -ErrorAction Stop | Out-Null

            Write-Log "SMTP Username '$smtpUsernameEmail' created successfully." -Level SUCCESS
            return $smtpUsernameEmail
        }
        catch {
            Write-Log "Az PowerShell SMTP Username creation failed: $($_.Exception.Message)" -Level WARNING
            Write-Log "Trying ARM REST API fallback..." -Level INFO
        }

        # Fallback to ARM REST API
        try {
            $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Communication/CommunicationServices/$CommunicationServiceName/smtpUsernames/$SmtpUsername`?api-version=2025-04-01-preview"

            $body = @{
                properties = @{
                    username           = $smtpUsernameEmail
                    entraApplicationId = $AppId
                }
            } | ConvertTo-Json -Depth 5

            $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
            $headers = @{
                "Authorization" = "Bearer $token"
                "Content-Type"  = "application/json"
            }

            $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
            Write-Log "SMTP Username '$smtpUsernameEmail' created via REST API." -Level SUCCESS
            return $smtpUsernameEmail
        }
        catch {
            Write-Log "REST API fallback also failed: $($_.Exception.Message)" -Level WARNING
            Write-Log "Create the SMTP Username manually in the Azure Portal:" -Level WARNING
            Write-Log "  Communication Service > SMTP Usernames > +Add SMTP Username" -Level WARNING
            Write-Log "  Select Entra app: $EntraAppName" -Level WARNING
            Write-Log "  Username type: Email" -Level WARNING
            Write-Log "  Username: $SmtpUsername" -Level WARNING
            Write-Log "  Domain: $domainName" -Level WARNING
            return $smtpUsernameEmail
        }
    }
}

# ============================================================================
# TEST EMAIL
# ============================================================================

function Send-ACSTestEmail {
    <#
    .SYNOPSIS
        Sends a test email to validate ACS Email connectivity.
        Tries the custom SMTP username (email format) first, falls back to legacy format.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ClientSecret,

        [Parameter()]
        [string]$SmtpUsernameOverride
    )

    if ([string]::IsNullOrWhiteSpace($TestRecipientEmail)) {
        Write-Log "No test recipient specified. Skipping test email." -Level INFO
        return
    }

    $domainName = if ($UseAzureManagedDomain) {
        $domain = Get-AzEmailServiceDomain -ResourceGroupName $ResourceGroupName -EmailServiceName $EmailServiceName -Name "AzureManagedDomain"
        $domain.MailFromSenderDomain
    }
    else {
        $CustomDomainName
    }

    $fromAddress = "$($MailFromAddresses[0])@$domainName"

    # Build the SMTP username - email format
    $smtpUser = if (-not [string]::IsNullOrWhiteSpace($SmtpUsernameOverride)) {
        $SmtpUsernameOverride
    }
    else {
        "$SmtpUsername@$domainName"
    }

    # Also prepare legacy username for fallback
    $tenantId = (Get-AzContext).Tenant.Id
    # Try to get AppId from existing Entra app
    $appIdForLegacy = az ad app list --display-name $EntraAppName --query "[0].appId" -o tsv 2>&1
    $legacyUsername = if (-not [string]::IsNullOrWhiteSpace($appIdForLegacy) -and $appIdForLegacy -match '^[0-9a-f-]+$') {
        "$CommunicationServiceName.$appIdForLegacy.$tenantId"
    }
    else {
        $null
    }

    Write-Log "Sending test email from '$fromAddress' to '$TestRecipientEmail'..." -Level INFO

    if ($PSCmdlet.ShouldProcess($TestRecipientEmail, "Send Test Email")) {
        $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force

        # Try custom SMTP username first
        Write-Log "Attempting with SMTP username: $smtpUser" -Level INFO
        try {
            $credential = New-Object PSCredential($smtpUser, $securePassword)
            Send-MailMessage `
                -SmtpServer "smtp.azurecomm.net" `
                -Port 587 `
                -UseSsl `
                -Credential $credential `
                -From $fromAddress `
                -To $TestRecipientEmail `
                -Subject "ACS Email Deployment Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
                -Body "This test email confirms that Azure Communication Services Email has been successfully deployed by Deploy-ACSEmail.ps1.`n`nSMTP Username: $smtpUser`nFrom: $fromAddress`nDeployment completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." `
                -WarningAction SilentlyContinue

            Write-Log "Test email sent successfully to '$TestRecipientEmail' using username '$smtpUser'." -Level SUCCESS
            return
        }
        catch {
            Write-Log "Custom username failed: $($_.Exception.Message)" -Level WARNING
        }

        # Fallback to legacy username
        if ($legacyUsername) {
            Write-Log "Trying legacy SMTP username: $legacyUsername" -Level INFO
            try {
                $credential = New-Object PSCredential($legacyUsername, $securePassword)
                Send-MailMessage `
                    -SmtpServer "smtp.azurecomm.net" `
                    -Port 587 `
                    -UseSsl `
                    -Credential $credential `
                    -From $fromAddress `
                    -To $TestRecipientEmail `
                    -Subject "ACS Email Deployment Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
                    -Body "This test email confirms that Azure Communication Services Email has been successfully deployed by Deploy-ACSEmail.ps1.`n`nSMTP Username: $legacyUsername (legacy format)`nFrom: $fromAddress`nDeployment completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')." `
                    -WarningAction SilentlyContinue

                Write-Log "Test email sent successfully using legacy username." -Level SUCCESS
                return
            }
            catch {
                Write-Log "Legacy username also failed: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Both failed
        Write-Log "Test email failed with both username formats." -Level ERROR
        Write-Log "Common causes:" -Level WARNING
        Write-Log "  1. Domain not fully verified (verify in Portal: Email Communication Service > Provision Domains)" -Level WARNING
        Write-Log "  2. Domain not linked (run the Update-AzCommunicationService command from the deployment output)" -Level WARNING
        Write-Log "  3. IAM role propagation not complete (wait a few more minutes)" -Level WARNING
        Write-Log "  4. SMTP Username not in 'Ready to use' status (check Portal: Communication Service > SMTP Usernames)" -Level WARNING
        Write-Log "  5. MailFrom address not authorized for sending" -Level WARNING
        Write-Log "Re-run with -TestEmailOnly to retry after resolving the issue." -Level INFO
    }
}

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

function Show-DeploymentSummary {
    <#
    .SYNOPSIS
        Displays a summary of the deployment with all connection details.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$EntraApp
    )

    $domainName = if ($UseAzureManagedDomain) {
        $domain = Get-AzEmailServiceDomain -ResourceGroupName $ResourceGroupName -EmailServiceName $EmailServiceName -Name "AzureManagedDomain"
        $domain.MailFromSenderDomain
    }
    else {
        $CustomDomainName
    }

    Write-Log " " -Level INFO
    Write-Log "============================================================" -Level SUCCESS
    Write-Log "  ACS EMAIL DEPLOYMENT COMPLETE" -Level SUCCESS
    Write-Log "============================================================" -Level SUCCESS
    Write-Log " " -Level INFO
    Write-Log "AZURE RESOURCES:" -Level INFO
    Write-Log "  Resource Group:           $ResourceGroupName" -Level INFO
    Write-Log "  Email Communication Svc:  $EmailServiceName" -Level INFO
    Write-Log "  Communication Service:    $CommunicationServiceName" -Level INFO
    Write-Log "  Domain:                   $domainName" -Level INFO
    Write-Log " " -Level INFO
    Write-Log "SMTP SETTINGS (for devices and applications):" -Level INFO
    Write-Log "  SMTP Server:              smtp.azurecomm.net" -Level INFO
    Write-Log "  Port:                     587" -Level INFO
    Write-Log "  Encryption:               STARTTLS" -Level INFO
    Write-Log "  Username:                 $SmtpUsername@$domainName" -Level INFO
    Write-Log "  Password:                 (Entra app client secret - see above)" -Level INFO
    Write-Log " " -Level INFO
    Write-Log "SENDER ADDRESSES:" -Level INFO
    foreach ($sender in $MailFromAddresses) {
        Write-Log "  $sender@$domainName" -Level INFO
    }
    Write-Log " " -Level INFO
    Write-Log "ENTRA ID APPLICATION:" -Level INFO
    Write-Log "  App Name:                 $EntraAppName" -Level INFO
    Write-Log "  App (Client) ID:          $($EntraApp.AppId)" -Level INFO
    Write-Log "  Tenant ID:                $($EntraApp.TenantId)" -Level INFO
    Write-Log "  Secret Expires:           $(((Get-Date).AddMonths($SecretExpirationMonths)).ToString('yyyy-MM-dd'))" -Level INFO
    Write-Log " " -Level INFO
    Write-Log "LEGACY SMTP USERNAME (if custom SMTP Username is unavailable):" -Level INFO
    Write-Log "  $CommunicationServiceName.$($EntraApp.AppId).$($EntraApp.TenantId)" -Level INFO
    Write-Log " " -Level INFO
    Write-Log "LOG FILE: $script:LogFile" -Level INFO
    Write-Log "============================================================" -Level SUCCESS
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Invoke-ACSEmailDeployment {
    <#
    .SYNOPSIS
        Orchestrates the ACS Email deployment, test, or endpoint addition.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-Log "============================================================" -Level INFO
    Write-Log "  Azure Communication Services Email Deployment" -Level INFO
    Write-Log "  Azure Innovators | www.azureinnovators.com" -Level INFO
    Write-Log "  Script Version: 2.0.0" -Level INFO
    Write-Log "============================================================" -Level INFO

    try {
        # Determine execution mode
        if ($TestEmailOnly) {
            # ============================================================
            # MODE: Test Email Only
            # ============================================================
            Write-Log "MODE: Test Email Only" -Level INFO

            if ([string]::IsNullOrWhiteSpace($TestRecipientEmail)) {
                Write-Log "-TestRecipientEmail is required for -TestEmailOnly mode." -Level ERROR
                throw "Missing required parameter: TestRecipientEmail"
            }

            if ([string]::IsNullOrWhiteSpace($SmtpPassword)) {
                $secureInput = Read-Host "Enter the SMTP password (client secret)" -AsSecureString
                $SmtpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
                )
            }

            Test-Prerequisites

            Send-ACSTestEmail -ClientSecret $SmtpPassword
        }
        elseif ($AddSmtpEndpoint) {
            # ============================================================
            # MODE: Add SMTP Endpoint
            # ============================================================
            Write-Log "MODE: Add SMTP Endpoint to Existing Deployment" -Level INFO

            Test-Prerequisites

            # Validate required params
            if ([string]::IsNullOrWhiteSpace($EntraAppName)) {
                Write-Log "-EntraAppName is required for -AddSmtpEndpoint mode." -Level ERROR
                throw "Missing required parameter: EntraAppName"
            }
            if ([string]::IsNullOrWhiteSpace($SmtpUsername)) {
                Write-Log "-SmtpUsername is required for -AddSmtpEndpoint mode." -Level ERROR
                throw "Missing required parameter: SmtpUsername"
            }

            # Verify the Communication Service exists
            $existingComm = Get-AzCommunicationService -ResourceGroupName $ResourceGroupName -Name $CommunicationServiceName -ErrorAction SilentlyContinue
            if (-not $existingComm) {
                Write-Log "Communication Service '$CommunicationServiceName' not found in Resource Group '$ResourceGroupName'." -Level ERROR
                throw "Communication Service not found. Run a full deployment first."
            }
            Write-Log "Communication Service '$CommunicationServiceName' found." -Level SUCCESS

            # Step 1: Create new MailFrom address if specified
            if (-not [string]::IsNullOrWhiteSpace($NewMailFromAddress)) {
                $displayName = if (-not [string]::IsNullOrWhiteSpace($NewMailFromDisplayName)) { $NewMailFromDisplayName } else { $NewMailFromAddress }
                $domainName = if ($UseAzureManagedDomain) { "AzureManagedDomain" } else { $CustomDomainName }

                Write-Log "Creating MailFrom address: $NewMailFromAddress@$domainName (Display: $displayName)..." -Level INFO

                if ($PSCmdlet.ShouldProcess("$NewMailFromAddress@$domainName", "Create MailFrom Address")) {
                    try {
                        az communication email domain sender-username create `
                            --email-service-name $EmailServiceName `
                            --resource-group $ResourceGroupName `
                            --domain-name $domainName `
                            --sender-username $NewMailFromAddress `
                            --username $NewMailFromAddress `
                            --display-name $displayName 2>&1 | Out-Null

                        Write-Log "MailFrom address '$NewMailFromAddress@$domainName' created." -Level SUCCESS
                    }
                    catch {
                        Write-Log "Failed to create MailFrom '$NewMailFromAddress': $($_.Exception.Message)" -Level WARNING
                    }
                }
            }

            # Step 2: Create Entra app
            $entraApp = New-ACSEntraApp

            if ($null -ne $entraApp -and -not [string]::IsNullOrWhiteSpace($entraApp.AppId)) {
                # Step 3: Assign IAM role
                Set-ACSRoleAssignment -AppId $entraApp.AppId

                # Step 4: Create SMTP Username
                $smtpUsernameResult = New-ACSSmtpUsername -AppId $entraApp.AppId

                # Step 5: Show endpoint summary
                $domainName = if ($UseAzureManagedDomain) { "AzureManagedDomain" } else { $CustomDomainName }

                Write-Log " " -Level INFO
                Write-Log "============================================================" -Level SUCCESS
                Write-Log "  NEW SMTP ENDPOINT CREATED" -Level SUCCESS
                Write-Log "============================================================" -Level SUCCESS
                Write-Log " " -Level INFO
                Write-Log "SMTP SETTINGS:" -Level INFO
                Write-Log "  SMTP Server:    smtp.azurecomm.net" -Level INFO
                Write-Log "  Port:           587" -Level INFO
                Write-Log "  Encryption:     STARTTLS" -Level INFO
                Write-Log "  Username:       $SmtpUsername@$domainName" -Level INFO
                Write-Log "  Password:       (client secret shown above)" -Level INFO
                if (-not [string]::IsNullOrWhiteSpace($NewMailFromAddress)) {
                    Write-Log "  From Address:   $NewMailFromAddress@$domainName" -Level INFO
                }
                Write-Log " " -Level INFO
                Write-Log "ENTRA APPLICATION:" -Level INFO
                Write-Log "  App Name:       $EntraAppName" -Level INFO
                Write-Log "  App ID:         $($entraApp.AppId)" -Level INFO
                Write-Log "  Secret Expires: $(((Get-Date).AddMonths($SecretExpirationMonths)).ToString('yyyy-MM-dd'))" -Level INFO
                Write-Log " " -Level INFO
                Write-Log "LEGACY USERNAME:" -Level INFO
                Write-Log "  $CommunicationServiceName.$($entraApp.AppId).$($entraApp.TenantId)" -Level INFO
                Write-Log "============================================================" -Level SUCCESS

                # Step 6: Test email if requested
                if (-not [string]::IsNullOrWhiteSpace($TestRecipientEmail)) {
                    Send-ACSTestEmail -ClientSecret $entraApp.ClientSecret
                }
            }
        }
        else {
            # ============================================================
            # MODE: Full Deployment
            # ============================================================
            Write-Log "MODE: Full Deployment" -Level INFO

            # Step 1: Validate prerequisites
            Test-Prerequisites

            # Step 2: Create Resource Group
            New-ACSResourceGroup

            # Step 3: Create Email Communication Service
            New-ACSEmailService

            # Step 4: Create Communication Service
            New-ACSCommunicationService

            # Brief pause to allow Email Communication Service to fully provision
            if (-not $WhatIfPreference) {
                Write-Log "Waiting 15 seconds for services to fully provision before domain setup..." -Level INFO
                Start-Sleep -Seconds 15
            }

            # Step 5: Create and verify domain
            New-ACSEmailDomain

            # Step 6: Create MailFrom addresses
            New-ACSMailFromAddresses

            # Step 7: Link domain to Communication Service
            Connect-ACSDomain

            # Step 8: Create Entra ID App Registration
            $entraApp = New-ACSEntraApp

            # Steps 9-12 depend on the Entra app - skip gracefully during -WhatIf
            if ($null -eq $entraApp -or [string]::IsNullOrWhiteSpace($entraApp.AppId)) {
                if ($WhatIfPreference) {
                    Write-Log "WhatIf: Would assign IAM role to Entra app on '$CommunicationServiceName'" -Level INFO
                    Write-Log "WhatIf: Would create SMTP Username '$SmtpUsername'" -Level INFO
                    Write-Log "WhatIf: Would send test email to '$TestRecipientEmail'" -Level INFO
                    Write-Log "WhatIf: Would display deployment summary" -Level INFO
                }
                else {
                    Write-Log "Entra app creation returned no result. Cannot proceed with Steps 9-12." -Level ERROR
                    throw "Entra app creation failed - no AppId returned."
                }
            }
            else {
                # Step 9: Assign IAM role
                Set-ACSRoleAssignment -AppId $entraApp.AppId

                # Step 10: Create SMTP Username
                New-ACSSmtpUsername -AppId $entraApp.AppId

                # Step 11: Send test email
                Send-ACSTestEmail -ClientSecret $entraApp.ClientSecret

                # Step 12: Show summary
                Show-DeploymentSummary -EntraApp $entraApp
            }
        }

        $stopwatch.Stop()
        Write-Log "Total execution time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -Level SUCCESS
    }
    catch {
        $stopwatch.Stop()
        Write-Log "Execution failed after $($stopwatch.Elapsed.ToString('mm\:ss')): $($_.Exception.Message)" -Level ERROR
        Write-Log "Review the log file for details: $script:LogFile" -Level ERROR
        throw
    }
}

# Run the deployment
Invoke-ACSEmailDeployment
