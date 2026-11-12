<#
.SYNOPSIS
    This script will aid you in installing and configuring OpenVox on Windows.
.DESCRIPTION
    This script will guide you through the process of installing and configuring OpenVox on Windows.
    The script can be run fully automated by passing in all the required parameters, or it can be run interactively
    which will guide you through the process of installing and configuring OpenVox.
    For detailed information refer to the repository README.md file.
#>
[CmdletBinding()]
param (
    # The version of OpenVox agent to install, can be a major version (e.g. 7) or an exact version (e.g. 7.12.0)
    [Parameter(Mandatory = $false)]
    [int]
    $AgentVersion = 7,

    # The OpenVox server to connect to
    [Parameter(Mandatory = $false)]
    [string]
    $OpenVoxServer,

    # The OpenVox server port to connect to
    [Parameter(Mandatory = $false)]
    [int]
    $OpenVoxServerPort = 8140,

    # The OpenVox environment to use
    [Parameter(Mandatory = $false)]
    [string]
    $Environment = 'production',

    # Set this to change the default certificate name
    [Parameter(Mandatory = $false)]
    [string]
    $CertificateName,

    # Any certificate extensions to add to the OpenVox agent certificate
    [Parameter(Mandatory = $false)]
    [hashtable]
    $CSRExtensions,

    # Whether or not to enable the service at system startup
    [Parameter(Mandatory = $false)]
    [string]
    $EnableService = $true,

    # The credentials to use for the OpenVox service
    [Parameter(Mandatory = $false)]
    [pscredential]
    $ServiceAccountCredentials,

    # The domain to use for the OpenVox service account
    [Parameter(Mandatory = $false)]
    [string]
    $ServiceAccountDomain,

    # If set the OpenVox agent will wait for the certificate to be signed before continuing
    [Parameter(Mandatory = $false)]
    [string]
    $CSRRetryInterval = 30,

    # If set will change the Hostname of this node
    [Parameter(Mandatory = $false)]
    [string]
    $NewHostname,

    # Skip the OpenVox server check
    [switch]
    $SkipOpenVoxServerCheck,

    # Skips all optional prompts
    [switch]
    $SkipOptionalPrompts,

    # Skips the confirmation prompt
    [switch]
    $SkipConfirmation,

    # Skips the initial OpenVox run, useful in some edge-cases
    [switch]
    $SkipInitialRun,

    # Set to run the script in unattended mode
    [switch]
    $Unattended
)

$ErrorActionPreference = 'Stop'

if ($Unattended)
{
    $SkipConfirmation = $true
    $SkipOptionalPrompts = $true
    $SkipOpenVoxServerCheck = $true
}

# Always get current hostname so we can skip setting it if it's not changing
$CurrentNodeName = $env:ComputerName

function Get-Response
{
    param
    (
        # The prompt to post on screen
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $Prompt,

        # The type of value to return
        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        [ValidateSet('string', 'bool', 'array')]
        $ResponseType,

        # Make the response mandatory (applies to string and arrays only)
        [Parameter(
            Mandatory = $false
        )]
        [switch]
        $Mandatory
    )
    # I've seen some weirdness where $Response can end up hanging around so set it to $null every time this cmdlet is called.
    $Response = $null
    switch ($ResponseType)
    {
        'bool'
        {
            # Booleans are always mandatory by their very nature
            while (!$Response)
            {
                $Response = Read-Host "$Prompt [y]es/[n]o"
                switch ($Response.ToLower())
                {
                    { ($_ -eq 'y') -or ($_ -eq 'yes') }
                    {
                        Return $true
                    }
                    { ($_ -eq 'n') -or ($_ -eq 'no') }
                    {
                        Return $false
                    }
                    Default
                    {
                        Write-Host "Invalid response '$Response'" -ForegroundColor red
                        Clear-Variable 'Response'
                    }
                }
            }
        }
        'string'
        {
            # If the string is mandatory then keep prompting until we get a valid response
            if ($Mandatory)
            {
                While (!$Response)
                {
                    $Response = Read-Host "$($Prompt): "
                }
            }
            # If not then allow us to skip
            else
            {
                $Prompt = $Prompt + ' (Optional - press enter to skip): '
            }
            # Only return an object if we have one
            if ($Response)
            {
                Return [string]$Response
            }
        }
        'array'
        {
            # If the array is mandatory then keep prompting until we get a value
            if ($Mandatory)
            {
                While (!$Response)
                {
                    $Response = Read-Host "$Prompt [if specifying more than one separate with a comma]"
                }
            }
            # Otherwise allow the user to skip by hitting enter
            else
            {
                $Response = Read-Host "$Prompt [if specifying more than one separate with a comma] (Optional - press enter to skip)"
            }
            # Only return an object if we have one
            if ($Response)
            {
                $Array = $Response -split ','
                Return $Array
            }
        }
    }
}
function Test-Administrator
{

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $Return = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Return $Return
}

function Split-Version
{
    param (
        [string]$version
    )

    $majorVersion = $version.Split('.')[0]

    if ($version -match '^\d+\.\d+\.\d+$')
    {
        $exactVersion = $version
    }
    else
    {
        $exactVersion = $null
    }

    return @{
        majorVersion = $majorVersion
        exactVersion = $exactVersion
    }
}
function Get-CSRAttributes
{
    $Continue = $true
    $CSRExtensions = @{}
    while ($Continue)
    {
        $KeyName = Get-Response 'Please enter the key name (e.g pp_environment)' 'string' -Mandatory
        $Value = Get-Response "Please enter the value for '$KeyName'" 'string' -Mandatory
        $CSRExtensions.Add($KeyName, $Value)
        $Continue = Get-Response 'Would you like to add another key? [y]es/[n]o' 'bool'
    }
}

function Set-CertificateExtensions
{
    [CmdletBinding()]
    param
    (
        # The extension attributes to be set
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]
        $ExtensionAttributes
    )
    $ppRegCertExtShortNames = @(
        'pp_uuid',
        'pp_uuid',
        'pp_instance_id',
        'pp_image_name',
        'pp_preshared_key',
        'pp_cost_center',
        'pp_product',
        'pp_project',
        'pp_application',
        'pp_service',
        'pp_employee',
        'pp_created_by',
        'pp_environment',
        'pp_role',
        'pp_software_version',
        'pp_department',
        'pp_cluster',
        'pp_provisioner',
        'pp_region',
        'pp_datacenter',
        'pp_zone',
        'pp_network',
        'pp_securitypolicy',
        'pp_cloudplatform',
        'pp_apptier',
        'pp_hostname'
    )
    $ppAuthCertExtShortNames = @(
        'pp_authorization',
        'pp_auth_role'
    )
    $ValidExtensionShortNames = $ppRegCertExtShortNames + $ppAuthCertExtShortNames

    $CSRYamlContent = "extension_requests:`n"
    # Make sure they are all valid
    $ExtensionAttributes.GetEnumerator() | ForEach-Object {
        if ($_.Key -notin $ValidExtensionShortNames)
        {
            throw "Invalid extension short name: $($_.Key)"
        }
        $CSRYamlContent += "    $($_.Key): $($_.Value)`n"
    }
    $CSRYamlPath = 'C:\ProgramData\PuppetLabs\puppet\etc\csr_attributes.yaml'
    # Write the file, we set force so it always overwrites even if it already exists
    try
    {
        New-Item $CSRYamlPath -Force -ItemType File -Value $CSRYamlContent
    }
    catch
    {
        throw "Failed to write CSR attributes file to $CSRYamlPath.`n$($_.Exception.Message)"
    }
}

function Set-OpenVoxConfigOption
{
    [CmdletBinding()]
    param
    (
        # The option(s) to set
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ConfigOptions,

        # The path to the configuration file (if not using the default)
        [Parameter(Mandatory = $false)]
        [string]
        $ConfigFilePath,

        # The section that you wish to set the options in (defaults to 'agent')
        [Parameter(Mandatory = $false)]
        [string]
        [ValidateSet('agent', 'main', 'master')]
        $Section = 'agent'
    )

    if (!$ConfigFilePath)
    {
        $ConfigFilePath = 'C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf'
    }
    $OpenVoxBin = Get-Command 'puppet' | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
    if (!(Test-Path $OpenVoxBin))
    {
        throw "Could not find the puppet command at $OpenVoxBin"
    }
    if (!(Test-Path $ConfigFilePath))
    {
        throw "Could not find the puppet configuration file at $ConfigFilePath"
    }
    $ConfigOptions.GetEnumerator() | ForEach-Object {
        Write-Verbose "Now setting $($_.Key) = $($_.Value)"
        & $OpenVoxBin config set "$($_.Key)" "$($_.Value)" --config $ConfigFilePath --section $Section
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Failed to set $($_.Key) to $($_.Value)"
        }
    }
}

function Enable-OpenVoxService
{
    [CmdletBinding()]
    param
    (
        # The name of the OpenVox service
        [Parameter(Mandatory = $false)]
        [string]
        $ServiceName = 'puppet'
    )

    $Service = Get-Service $ServiceName
    if ($Service.StartupType -eq 'Disabled')
    {
        Write-Verbose 'Service is disabled, setting to start automatically'
        Set-Service -Name $ServiceName -StartupType Automatic
    }
    if ($Service.Status -ne 'Running')
    {
        Write-Verbose 'Service is not running, starting'
        Start-Service $ServiceName
    }

}

function Install-OpenVox
{
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $MajorVersion,

        [Parameter(Mandatory = $false)]
        [version]
        $ExactVersion,

        [Parameter(Mandatory = $false)]
        [pscredential]
        $ServiceAccountCredentials,

        [Parameter(Mandatory = $false)]
        [string]
        $ServiceAccountDomain
    )
    $URIBase = "https://downloads.puppetlabs.com/windows/puppet$MajorVersion"

    if ( [Environment]::Is64BitOperatingSystem )
    {
        $arch = 'x64'
    }
    else
    {
        $arch = 'x86'
    }

    if ($ExactVersion)
    {
        $URI = "$URIBase/puppet-agent-$ExactVersion-$arch.msi"
    }
    else
    {
        $URI = "$URIBase/puppet-agent-$arch-latest.msi"
    }

    $DownloadPath = "$env:TEMP\puppet-agent.msi"
    Write-Verbose "Downloading OpenVox agent from $URI to $DownloadPath"

    # Check if BITs is available and use it if it is
    if (Get-Command 'Start-BitsTransfer' -ErrorAction SilentlyContinue)
    {
        try
        {
            Start-BitsTransfer -Source $URI -Destination $DownloadPath
        }
        catch
        {
            # If we fail don't fail, fallback to Invoke-WebRequest
            $UseLegacy = $true
        }
    }
    else
    {
        $UseLegacy = $true
    }
    if ($UseLegacy)
    {
        Write-Warning 'BITS is not available, falling back to Invoke-WebRequest, this will be slow...'
        try
        {
            Invoke-WebRequest -Uri $URI -OutFile $DownloadPath
        }
        catch
        {
            throw "Failed to download OpenVox agent from $URI to $DownloadPath.`n$($_.Exception.Message)"
        }
    }
    $install_args = @(
        '/qn',
        '/norestart',
        '/i',
        $DownloadPath
    )
    <#
        !!! Don't set PUPPET_SERVER, PUPPET_CA_SERVER, PUPPET_AGENT_CERTNAME, or PUPPET_AGENT_ENVIRONMENT via MSI properties
        !!! If you do that then you'll run into unexpected consequences and will have to uninstall OpenVox completely to fix it
        !!! Instead these will be set by the Set-OpenVoxConfigOption function after installation
    #>

    # See https://www.puppet.com/docs/puppet/7/install_agents.html for more information on these properties
    if ($ServiceAccountCredentials)
    {
        $install_args += "PUPPET_AGENT_ACCOUNT_USER=$($ServiceAccountCredentials.UserName)"
        # We may not have a password if the account is a service account or similar
        if ($ServiceAccountCredentials.Password.Length -gt 0)
        {
            try
            {
                $DecryptedPassword = $ServiceAccountCredentials.Password | ConvertFrom-SecureString -AsPlainText
            }
            catch
            {
                throw "Failed to decrypt password for account $($ServiceAccountCredentials.UserName).`n$($_.Exception.Message)"
            }
            $install_args += "PUPPET_AGENT_ACCOUNT_PASSWORD=$DecryptedPassword"
        }
    }

    if ($ServiceAccountDomain)
    {
        $install_args += "PUPPET_AGENT_ACCOUNT_DOMAIN=$ServiceAccountDomain"
    }

    # Use Start-Process to install the MSI so we can wait for it to finish
    Write-Verbose "Installing OpenVox agent from $DownloadPath"
    $InstallProcess = Start-Process -FilePath 'msiexec.exe' -ArgumentList $install_args -Wait -PassThru -NoNewWindow
    if ($InstallProcess.ExitCode -ne 0)
    {
        throw "Failed to install OpenVox agent from $DownloadPath, exit code was $($InstallProcess.ExitCode)"
    }
}

# Check if we are running as an administrator
if (!(Test-Administrator))
{
    throw 'You must run this script as an administrator'
}

<#
    The below prompts the user for the _required_ information to install and configure OpenVox
    if the information has not been passed in via parameters
#>
if (!$OpenVoxServer)
{
    if ($Unattended)
    {
        throw 'The OpenVox server FQDN is required for bootstrapping'
    }
    while (!$OpenVoxServer)
    {
        $OpenVoxServer = Read-Host -Prompt 'Enter the OpenVox server FQDN: '
    }
}

if ($OpenVoxServer -notmatch '\.[a-zA-Z0-9-]+$')
{
    if (!$Unattended)
    {
        while ($OpenVoxServer -notmatch '^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$')
        {
            Write-Host 'The OpenVox server must be fully qualified (e.g. "openvoxserver.domain")' -ForegroundColor Red
            $OpenVoxServer = Read-Host -Prompt 'Enter the OpenVox server FQDN: '
        }
    }
    else
    {
        throw 'The OpenVox server must be fully qualified (e.g. "openvoxserver.domain")'
    }
}

# Extract the domain name from the OpenVox server
# Due to the way OpenVox certs work it's helpful to know this especially when renaming a node
$DomainName = $OpenVoxServer -replace '^[a-zA-Z0-9-]+\.', ''

if (!$AgentVersion)
{
    $VersionPrompt = $null
    while ($VersionPrompt -notmatch '^\d+(\.\d+)*$')
    {
        $VersionPrompt = Read-Host -Prompt 'Enter the version of OpenVox agent to install, Can be a major version (e.g. 7) or exact (e.g 7.1.2):'
    }
    $AgentVersion = $VersionPrompt
}

$VersionSplit = Split-Version -version $AgentVersion
$MajorVersion = $VersionSplit.majorVersion
if ($VersionSplit.exactVersion)
{
    $ExactVersion = $VersionSplit.exactVersion
}

Write-Verbose "Installing Version $AgentVersion"

# Check we can contact the OpenVox Server
# This is handy as we don't want to get too far in the script if we can't contact the server!
if (!$SkipOpenVoxServerCheck)
{
    Write-Verbose "Checking if we can ping $OpenVoxServer"
    $arguments = @($OpenVoxServer)
    $OpenVoxServerPing = & ping $arguments
    if ($LASTEXITCODE -ne 0)
    {
        $OpenVoxServerPing
        throw "Unable to ping $OpenVoxServer, are you sure it's correct?"
    }
}

<#
    The below prompts the user for the _optional_ information to install and configure OpenVox
    providing they have not been passed in via the script parameters or the user has not skipped them.
    We don't prompt for everything the user could possibly want, only the most common options
    that are wanted in like 99% of cases, theses are:
        - OpenVox Environment
        - CSR Extensions
        - New Hostname
#>
if (!$NewHostname)
{
    if (!$SkipOptionalPrompts)
    {
        Write-Host "Current hostname: $($CurrentNodeName)"
        $ChangeHostname = Get-Response 'Do you want to change the hostname?' -ResponseType 'bool'
    }
    if ($ChangeHostname)
    {
        $NewHostname = Get-Response 'Enter the new hostname' -ResponseType 'string' -Mandatory
    }
    else
    {
        $NewHostname = $CurrentNodeName
    }
}
if (!$SkipOptionalPrompts)
{
    if (!$Environment)
    {
        $Environment = Get-Response 'Enter the OpenVox environment to use (e.g production), press enter to skip' 'string'
    }

    if (!$CertificateName)
    {
        $CertificateCheck = Get-Response 'Do you want to set a custom certificate name?' 'bool'
        if ($CertificateCheck)
        {
            $CertificateName = Get-Response 'Enter the certificate name' 'string' -Mandatory
        }
    }

    if (!$CSRExtensions)
    {
        $CSRExtensionCheck = Get-Response 'Do you want to add CSR extensions?' 'bool'
        if ($CSRExtensionCheck)
        {
            $CSRExtensions = Get-CSRAttributes
        }
    }
}

# On Windows ensure the hostname is NOT fully qualified (this will break hostname changes)
# It's pretty annoying as on Linux they MUST be fully qualified
# So we don't fail and instead try to be helpful and remove the domain
if ($NewHostname -match '\.')
{
    $CertWarning = 'Hostname cannot be fully qualified, removing domain'
    # Suspect in most cases if the user has entered a fully qualified hostname they actually
    # want to use that as the certificate name
    if (!$CertificateName)
    {
        $CertificateName = $NewHostname
        $CertWarning += "`nCertificate name will be set to '$CertificateName'"
    }
    Write-Warning $CertWarning
    $NewHostname = $NewHostname -replace '\..*'
}
###

### Double check the user wants to continue ###
$Message = "`nOpenVox will be installed with the following options:`n`n"
$Message += @"
    OpenVox Server: $OpenVoxServer
    OpenVox Server Port: $OpenVoxServerPort
    Hostname: $NewHostname`n
"@
if ($CertificateName)
{
    $Message += "    Certificate Name: $($CertificateName)`n"
}
if ($CSRExtensions)
{
    $Message += "    Certificate Extensions:`n"
    $CSRExtensions.GetEnumerator() | ForEach-Object {
        $Message += "       $($_.Key): $($_.Value)`n"
    }

}
if ($CSRRetryInterval -gt 0)
{
    $Message += "    Wait for certificate: $($CSRRetryInterval)s`n"
}
if ($EnableService)
{
    $Message += "    Enable OpenVox Service: $($EnableService)`n"
}
if ($ServiceAccountCredentials)
{
    $Message += "    OpenVox Service Account: $($ServiceAccountCredentials.UserName)`n"
    if ($ServiceAccountCredentials.Password.Length -gt 0)
    {
        $Message += "    OpenVox Service Account Password: <redacted>`n"
    }
    else
    {
        $Message += "    OpenVox Service Account Password: <empty>`n"
    }
}
if ($ServiceAccountDomain)
{
    $Message += "    OpenVox Service Account Domain: $($ServiceAccountDomain)`n"
}

if (!$SkipConfirmation)
{
    $Message += "`nDo you want to continue?"
    $Confirm = Get-Response $Message -ResponseType 'bool'
    if (!$Confirm)
    {
        throw 'User cancelled installation'
    }
}
else
{
    Write-Host $Message
    # Even if they've skipped the confirmation give the user 10 seconds just to make sure they're paying attention
    Start-Sleep -Seconds 10
}


### Begin by making sure the Machine is ready to go with OpenVox ###
### Begin bootstrap ###
Write-Host 'Beginning bootstrap process' -ForegroundColor Magenta

# Perform the hostname change if required first before making any other changes
if ($NewHostname -ne $CurrentNodeName)
{
    Write-Host "Setting hostname to $NewHostname" -ForegroundColor Magenta
    # Not sure how to handle fqdn's on Windows 🤷
    # it'll largely be taken care of by DNS/DHCP, so just change the hostname
    try
    {
        Rename-Computer -NewName $NewHostname -Force -Confirm:$false
    }
    catch
    {
        throw "Failed to set hostname to $($NewHostname).`n$($_.Exception.Message)"
    }
    # Windows name changes don't take hold until after a reboot
    Write-Warning 'Hostname change will take effect after a reboot'
    # If we're changing hostnames as part of this process then we'll need to tell OpenVox to use the new hostname
    # in the certificate request otherwise we'd have to reboot and re-run the script to pick up the new hostname
    # (OpenVox seems to have a real hard time determining domain names on Windows...)
    # However if the user is overriding the certificate name then we don't need to do this as they're doing something
    # more advanced and will likely know what they're doing.
    if (!$CertificateName)
    {
        # This _must_ be lower case!
        $CertificateName = "$($NewHostname).$($DomainName)".ToLower()
    }
}

# Install the OpenVox agent
Write-Host 'Installing OpenVox agent' -ForegroundColor Magenta
$InstallArgs = @{
}
if ($ExactVersion)
{
    $InstallArgs.Add('ExactVersion', $ExactVersion)
}
else
{
    $InstallArgs.Add('MajorVersion', $MajorVersion)
}
if ($ServiceAccountCredentials)
{
    $InstallArgs.Add('ServiceAccountCredentials', $ServiceAccountCredentials)
}
if ($ServiceAccountDomain)
{
    $InstallArgs.Add('ServiceAccountDomain', $ServiceAccountDomain)
}
try
{
    Install-OpenVox @InstallArgs
}
catch
{
    throw "Failed to install OpenVox agent.`n$($_.Exception.Message)"
}
# Ensure path is updated to contain the newly installed OpenVox binaries
if ($env:Path -notcontains 'C:\Program Files\Puppet Labs\Puppet\bin' )
{
    $env:Path += ';C:\Program Files\Puppet Labs\Puppet\bin'
    [Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')
}

if ($CSRExtensions)
{
    try
    {
        Set-CertificateExtensions -ExtensionAttributes $CSRExtensions
    }
    catch
    {
        throw "Failed to set certificate extensions.`n$($_.Exception.Message)"
    }
}

$OpenVoxMainConfigOptions = @{server = $OpenVoxServer; masterport = $OpenVoxServerPort }
$OpenVoxAgentConfigOptions = @{}
if ($Environment)
{
    $OpenVoxAgentConfigOptions.Add('environment', $Environment)
}

if ($CertificateName)
{
    $OpenVoxMainConfigOptions.Add('certname', $CertificateName)
}

if ($OpenVoxMainConfigOptions)
{
    Write-Host 'Setting OpenVox [main] configuration options' -ForegroundColor Magenta
    try
    {
        Set-OpenVoxConfigOption -ConfigOptions $OpenVoxMainConfigOptions -Section 'main'
    }
    catch
    {
        throw "Failed to set OpenVox agent environment.`n$($_.Exception.Message)"
    }
}
if ($OpenVoxAgentConfigOptions)
{
    Write-Host 'Setting OpenVox [agent] configuration options' -ForegroundColor Magenta
    try
    {
        Set-OpenVoxConfigOption -ConfigOptions $OpenVoxAgentConfigOptions -Section 'agent'
    }
    catch
    {
        throw "Failed to set OpenVox agent configuration.`n$($_.Exception.Message)"
    }
}
###

# For some reason OpenVox sometimes isn't quite ready to go after all this
# I've found waiting for a few seconds seems to help :shrug:
Start-Sleep -Seconds 10

if (!$SkipInitialRun)
{
    # Perform first run of OpenVox
    Write-Host 'Performing initial OpenVox run' -ForegroundColor Magenta
    $OpenVoxArgs = @('agent', '-t', '--detailed-exitcodes')
    if ($CSRRetryInterval -gt 0)
    {
        $OpenVoxArgs += @('--waitforcert', $CSRRetryInterval)
        Write-Host 'Please ensure you sign the certificate for this node on the OpenVox server' -ForegroundColor Yellow
    }

    & puppet $OpenVoxArgs

    if ($LASTEXITCODE -notin (0, 2))
    {
        # Only warn as we want to continue if the run fails
        Write-Warning "First OpenVox run failed with exit code $LASTEXITCODE"
    }
}

if ($EnableService)
{
    Write-Host 'Enabling OpenVox Service' -ForegroundColor Magenta
    try
    {
        Enable-OpenVoxService
    }
    catch
    {
        throw "Failed to enable OpenVox service.`n$($_.Exception.Message)"
    }
}
Write-Host 'OpenVox bootstrapping complete 🎉' -ForegroundColor Green
