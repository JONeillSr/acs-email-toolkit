<#
.SYNOPSIS
    Deploys Azure Communication Services Email infrastructure from scratch.

.DESCRIPTION
    This script automates the end-to-end deployment of Azure Communication Services (ACS)
    Email infrastructure. It creates all required Azure resources, configures a custom domain,
    sets up Entra ID authentication for SMTP, assigns IAM roles, creates SMTP usernames,
    configures MailFrom sender addresses, and sends a test email to validate the deployment.

    The script is designed for IT consultants and administrators who need to deploy ACS Email
    for multiple clients quickly and consistently. All operations are implemented as individual
    functions following PowerShell best practices with full error handling and logging.

    Resources created:
    - Resource Group (optional, if it doesn't exist)
    - Email Communication Service
    - Communication Service
    - Custom Domain (with verification guidance)
    - MailFrom Sender Addresses
    - Entra ID App Registration with Client Secret
    - IAM Role Assignment (Communication and Email Service Owner)
    - SMTP Username

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group. Will be created if it doesn't exist.
    Example: rg-acs-email-prod

.PARAMETER Location
    The Azure region for the Resource Group.
    Default: eastus

.PARAMETER DataLocation
    The data location for ACS resources. Must match supported regions.
    Default: UnitedStates

.PARAMETER EmailServiceName
    The name for the Email Communication Service resource.
    Example: acs-email-contoso-prod

.PARAMETER CommunicationServiceName
    The name for the Communication Service resource. Keep this SHORT — it becomes
    part of the SMTP username if custom SMTP Usernames are not used.
    Example: acs-contoso

.PARAMETER CustomDomainName
    The custom domain to configure for sending email.
    Example: contoso.com

.PARAMETER MailFromAddresses
    An array of MailFrom sender usernames to create (without the domain).
    Default: @("DoNotReply")
    Example: @("DoNotReply", "scanner", "alerts", "noreply")

.PARAMETER MailFromDisplayNames
    An array of display names corresponding to each MailFrom address.
    Must match the count of MailFromAddresses.
    Default: @("Do Not Reply")
    Example: @("Do Not Reply", "Scanner", "System Alerts", "No Reply")

.PARAMETER EntraAppName
    The display name for the Entra ID App Registration used for SMTP authentication.
    Default: acs-smtp-relay

.PARAMETER SmtpUsername
    The custom SMTP Username to create. Use something short that fits device
    username field limits (50-64 characters on most copiers).
    Default: acs-smtp

.PARAMETER SecretExpirationMonths
    Number of months before the Entra app client secret expires.
    Default: 12

.PARAMETER TestRecipientEmail
    Email address to send a test email to after deployment. If empty, test is skipped.

.PARAMETER SkipDomainVerification
    Switch to skip the interactive domain verification step. Use when DNS records
    are pre-configured or when running in a CI/CD pipeline with manual verification.

.PARAMETER UseAzureManagedDomain
    Switch to use an Azure-managed domain instead of a custom domain.
    Useful for testing before configuring a custom domain.

.PARAMETER WhatIf
    Shows what would happen without making any changes.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "rg-acs-email-prod" `
        -EmailServiceName "acs-email-contoso-prod" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "contoso.com" `
        -MailFromAddresses @("DoNotReply", "scanner", "alerts") `
        -MailFromDisplayNames @("Do Not Reply", "Scanner", "System Alerts") `
        -TestRecipientEmail "admin@contoso.com"

    Deploys a complete ACS Email environment with a custom domain and three sender addresses.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "rg-acs-email-test" `
        -EmailServiceName "acs-email-test" `
        -CommunicationServiceName "acs-test" `
        -UseAzureManagedDomain `
        -TestRecipientEmail "admin@contoso.com"

    Deploys ACS Email with an Azure-managed domain for quick testing.

.EXAMPLE
    .\Deploy-ACSEmail.ps1 `
        -ResourceGroupName "rg-acs-email-prod" `
        -EmailServiceName "acs-email-contoso-prod" `
        -CommunicationServiceName "acs-contoso" `
        -CustomDomainName "notify.contoso.com" `
        -SmtpUsername "scanner-smtp" `
        -SecretExpirationMonths 24

    Deploys using a subdomain with a custom short SMTP username and 2-year secret expiration.

.NOTES
    Script Name  : Deploy-ACSEmail.ps1
    Version      : 1.0.0
    Author       : John O'Neill Sr.
    Company      : Azure Innovators
    Website      : https://www.azureinnovators.com
    Blog Post    : https://azureinnovators.com/blog
    GitHub       : https://github.com/AzureInnovators

    Prerequisites:
    - Azure PowerShell module (Az) installed: Install-Module -Name Az -Force
    - Az.Communication module installed: Install-Module -Name Az.Communication -Force
    - Azure CLI installed (required for domain verification and sender username creation)
    - Microsoft Graph PowerShell module: Install-Module -Name Microsoft.Graph -Force
    - Appropriate Azure and Entra ID permissions:
        * Azure Subscription Contributor or Owner
        * Entra ID Application Administrator or Global Administrator
    - PowerShell 7.0 or later recommended

    Change Log:
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
    [switch]$UseAzureManagedDomain
)

#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Communication

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

    # Check Az module
    if (-not (Get-Module -ListAvailable -Name Az.Communication)) {
        Write-Log "Az.Communication module not found. Installing..." -Level WARNING
        Install-Module -Name Az.Communication -Force -AllowClobber -Scope CurrentUser
        Write-Log "Az.Communication module installed." -Level SUCCESS
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
    }
    else {
        Write-Log "Logged into Azure as '$($context.Account.Id)' on subscription '$($context.Subscription.Name)'." -Level INFO
    }

    # Ensure Az CLI is also logged in
    $azAccount = az account show 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Azure CLI not logged in. Running az login..." -Level WARNING
        az login
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
        $emailService = New-AzEmailService `
            -ResourceGroupName $ResourceGroupName `
            -Name $EmailServiceName `
            -DataLocation $DataLocation

        Write-Log "Email Communication Service '$EmailServiceName' created successfully." -Level SUCCESS
        return $emailService
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
        $commService = New-AzCommunicationService `
            -ResourceGroupName $ResourceGroupName `
            -Name $CommunicationServiceName `
            -DataLocation $DataLocation `
            -Location "Global"

        Write-Log "Communication Service '$CommunicationServiceName' created successfully." -Level SUCCESS
        return $commService
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
            $domain = New-AzEmailServiceDomain `
                -ResourceGroupName $ResourceGroupName `
                -EmailServiceName $EmailServiceName `
                -Name $CustomDomainName `
                -DomainManagement "CustomerManaged"

            Write-Log "Custom domain '$CustomDomainName' created." -Level SUCCESS

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
        Initiates domain verification and guides the user through DNS record creation.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Initiating domain verification for '$CustomDomainName'..." -Level INFO

    # Initiate Domain verification
    az communication email domain initiate-verification `
        --domain-name $CustomDomainName `
        --email-service-name $EmailServiceName `
        --resource-group $ResourceGroupName `
        --verification-type Domain 2>&1 | Out-Null

    Write-Log "============================================================" -Level WARNING
    Write-Log "ACTION REQUIRED: Add DNS records for domain verification" -Level WARNING
    Write-Log "============================================================" -Level WARNING
    Write-Log "" -Level INFO
    Write-Log "1. Log into the Azure Portal" -Level INFO
    Write-Log "2. Navigate to: Email Communication Services > $EmailServiceName > Provision Domains" -Level INFO
    Write-Log "3. Click on '$CustomDomainName'" -Level INFO
    Write-Log "4. Add the TXT, SPF, and DKIM records shown to your DNS provider" -Level INFO
    Write-Log "5. Click 'Verify' for each record type" -Level INFO
    Write-Log "" -Level INFO

    $continue = Read-Host "Press ENTER once DNS records are added and verified (or type 'skip' to continue without verification)"

    if ($continue -ne "skip") {
        # Verify each type
        $verificationTypes = @("Domain", "SPF", "DKIM", "DKIM2")

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

        # Wait and check status
        Write-Log "Waiting 30 seconds for verification propagation..." -Level INFO
        Start-Sleep -Seconds 30

        $domainStatus = Get-AzEmailServiceDomain `
            -ResourceGroupName $ResourceGroupName `
            -EmailServiceName $EmailServiceName `
            -Name $CustomDomainName

        Write-Log "Domain verification status: $($domainStatus.DomainVerificationStatusDomain)" -Level INFO
        Write-Log "SPF verification status: $($domainStatus.DomainVerificationStatusSpf)" -Level INFO
        Write-Log "DKIM verification status: $($domainStatus.DomainVerificationStatusDkim)" -Level INFO
        Write-Log "DKIM2 verification status: $($domainStatus.DomainVerificationStatusDkim2)" -Level INFO
    }
    else {
        Write-Log "Verification skipped. Complete verification in the Azure Portal before sending email." -Level WARNING
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
            Write-Log "Skipping 'DoNotReply' — created by default." -Level INFO
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
                -LinkedDomain @($domainResourceId)

            Write-Log "Domain linked to Communication Service successfully." -Level SUCCESS
        }
        catch {
            Write-Log "Failed to link domain: $($_.Exception.Message)" -Level ERROR
            throw
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

        $secretJson = az ad app credential reset `
            --id $appId `
            --append `
            --display-name "ACS-SMTP-Secret" `
            --end-date $expirationDate `
            -o json 2>&1

        $secretResult = $secretJson | ConvertFrom-Json
        $clientSecret = $secretResult.password
        $tenantId = $secretResult.tenant

        Write-Log "Client secret created. Expires: $expirationDate" -Level SUCCESS
        Write-Log "============================================================" -Level WARNING
        Write-Log "SAVE THIS SECRET NOW — it will not be shown again!" -Level WARNING
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
        # Get the service principal object ID
        $spJson = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" -o tsv 2>&1
        $spObjectId = $spJson.Trim()

        if ([string]::IsNullOrWhiteSpace($spObjectId)) {
            Write-Log "Service principal not found for AppId '$AppId'. Creating..." -Level WARNING
            az ad sp create --id $AppId 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            $spJson = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" -o tsv 2>&1
            $spObjectId = $spJson.Trim()
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
        This avoids the long legacy format (ResourceName.AppID.TenantID)
        which breaks on devices with username character limits.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    Write-Log "Creating SMTP Username '$SmtpUsername'..." -Level INFO
    Write-Log "This custom username replaces the legacy long-form format for device compatibility." -Level INFO

    if ($PSCmdlet.ShouldProcess($SmtpUsername, "Create SMTP Username")) {
        # SMTP Username creation is done through the Azure Portal or ARM REST API
        # Using Az CLI for this operation
        $subscriptionId = (Get-AzContext).Subscription.Id

        $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Communication/CommunicationServices/$CommunicationServiceName/smtpUsernames/$SmtpUsername`?api-version=2025-04-01-preview"

        $body = @{
            properties = @{
                username        = $SmtpUsername
                entraApplicationId = $AppId
            }
        } | ConvertTo-Json -Depth 5

        try {
            $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
            $headers = @{
                "Authorization" = "Bearer $token"
                "Content-Type"  = "application/json"
            }

            $response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -Body $body
            Write-Log "SMTP Username '$SmtpUsername' created successfully." -Level SUCCESS
        }
        catch {
            Write-Log "SMTP Username creation via REST API failed: $($_.Exception.Message)" -Level WARNING
            Write-Log "You may need to create the SMTP Username manually in the Azure Portal:" -Level WARNING
            Write-Log "  Communication Service > SMTP Usernames > +Add SMTP Username" -Level WARNING
            Write-Log "  Select your Entra app and enter username: $SmtpUsername" -Level WARNING
        }
    }
}

# ============================================================================
# TEST EMAIL
# ============================================================================

function Send-ACSTestEmail {
    <#
    .SYNOPSIS
        Sends a test email using PowerShell's Send-MailMessage to validate the deployment.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ClientSecret
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

    Write-Log "Sending test email from '$fromAddress' to '$TestRecipientEmail'..." -Level INFO

    if ($PSCmdlet.ShouldProcess($TestRecipientEmail, "Send Test Email")) {
        try {
            $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
            $credential = New-Object PSCredential($SmtpUsername, $securePassword)

            Send-MailMessage `
                -SmtpServer "smtp.azurecomm.net" `
                -Port 587 `
                -UseSsl `
                -Credential $credential `
                -From $fromAddress `
                -To $TestRecipientEmail `
                -Subject "ACS Email Deployment Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
                -Body "This test email confirms that Azure Communication Services Email has been successfully deployed by Deploy-ACSEmail.ps1. Deployment completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')." `
                -WarningAction SilentlyContinue

            Write-Log "Test email sent successfully to '$TestRecipientEmail'." -Level SUCCESS
        }
        catch {
            Write-Log "Test email failed: $($_.Exception.Message)" -Level ERROR
            Write-Log "Common causes:" -Level WARNING
            Write-Log "  1. Domain not fully verified (check Azure Portal)" -Level WARNING
            Write-Log "  2. IAM role propagation not complete (wait a few more minutes)" -Level WARNING
            Write-Log "  3. SMTP Username not in 'Ready to use' status" -Level WARNING
            Write-Log "  4. MailFrom address not authorized for sending" -Level WARNING
        }
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

    Write-Log "" -Level INFO
    Write-Log "============================================================" -Level SUCCESS
    Write-Log "  ACS EMAIL DEPLOYMENT COMPLETE" -Level SUCCESS
    Write-Log "============================================================" -Level SUCCESS
    Write-Log "" -Level INFO
    Write-Log "AZURE RESOURCES:" -Level INFO
    Write-Log "  Resource Group:           $ResourceGroupName" -Level INFO
    Write-Log "  Email Communication Svc:  $EmailServiceName" -Level INFO
    Write-Log "  Communication Service:    $CommunicationServiceName" -Level INFO
    Write-Log "  Domain:                   $domainName" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "SMTP SETTINGS (for devices and applications):" -Level INFO
    Write-Log "  SMTP Server:              smtp.azurecomm.net" -Level INFO
    Write-Log "  Port:                     587" -Level INFO
    Write-Log "  Encryption:               STARTTLS" -Level INFO
    Write-Log "  Username:                 $SmtpUsername" -Level INFO
    Write-Log "  Password:                 (Entra app client secret — see above)" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "SENDER ADDRESSES:" -Level INFO
    foreach ($sender in $MailFromAddresses) {
        Write-Log "  $sender@$domainName" -Level INFO
    }
    Write-Log "" -Level INFO
    Write-Log "ENTRA ID APPLICATION:" -Level INFO
    Write-Log "  App Name:                 $EntraAppName" -Level INFO
    Write-Log "  App (Client) ID:          $($EntraApp.AppId)" -Level INFO
    Write-Log "  Tenant ID:                $($EntraApp.TenantId)" -Level INFO
    Write-Log "  Secret Expires:           $(((Get-Date).AddMonths($SecretExpirationMonths)).ToString('yyyy-MM-dd'))" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "LEGACY SMTP USERNAME (if custom SMTP Username is unavailable):" -Level INFO
    Write-Log "  $CommunicationServiceName.$($EntraApp.AppId).$($EntraApp.TenantId)" -Level INFO
    Write-Log "" -Level INFO
    Write-Log "LOG FILE: $script:LogFile" -Level INFO
    Write-Log "============================================================" -Level SUCCESS
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Invoke-ACSEmailDeployment {
    <#
    .SYNOPSIS
        Orchestrates the full ACS Email deployment pipeline.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-Log "============================================================" -Level INFO
    Write-Log "  Azure Communication Services Email Deployment" -Level INFO
    Write-Log "  Azure Innovators | www.azureinnovators.com" -Level INFO
    Write-Log "  Script Version: 1.0.0" -Level INFO
    Write-Log "============================================================" -Level INFO

    try {
        # Step 1: Validate prerequisites
        Test-Prerequisites

        # Step 2: Create Resource Group
        New-ACSResourceGroup

        # Step 3: Create Email Communication Service
        New-ACSEmailService

        # Step 4: Create Communication Service
        New-ACSCommunicationService

        # Step 5: Create and verify domain
        New-ACSEmailDomain

        # Step 6: Create MailFrom addresses
        New-ACSMailFromAddresses

        # Step 7: Link domain to Communication Service
        Connect-ACSDomain

        # Step 8: Create Entra ID App Registration
        $entraApp = New-ACSEntraApp

        # Step 9: Assign IAM role
        Set-ACSRoleAssignment -AppId $entraApp.AppId

        # Step 10: Create SMTP Username
        New-ACSSmtpUsername -AppId $entraApp.AppId

        # Step 11: Send test email
        Send-ACSTestEmail -ClientSecret $entraApp.ClientSecret

        # Step 12: Show summary
        Show-DeploymentSummary -EntraApp $entraApp

        $stopwatch.Stop()
        Write-Log "Total deployment time: $($stopwatch.Elapsed.ToString('mm\:ss'))" -Level SUCCESS
    }
    catch {
        $stopwatch.Stop()
        Write-Log "Deployment failed after $($stopwatch.Elapsed.ToString('mm\:ss')): $($_.Exception.Message)" -Level ERROR
        Write-Log "Review the log file for details: $script:LogFile" -Level ERROR
        throw
    }
}

# Run the deployment
Invoke-ACSEmailDeployment
