<#
.SYNOPSIS
    Installs Puppet tooling on a Windows machine
.DESCRIPTION
    Installs the requested version of Puppet agent/bolt for your operating system.
    You can either specify the major version that you want installed whereby the latest version for that release will be installed,
    or you can specify a specific version. (e.g. 7.25.0)
.EXAMPLE
    Install-Puppet

    This would install the latest version of Puppet agent 7 for your operating system.
.EXAMPLE
    Install-Puppet -Application 'agent' -AgentVersion '7.25.0'

    This would install version 7.25.0 of Puppet agent for your operating system.
.EXAMPLE
    Install-Puppet -Application 'bolt', 'agent' -BoltVersion '3' -AgentVersion '7'

    This would install the latest version of Puppet bolt and Puppet agent 7 for your operating system.
#>
function Install-Puppet
{
    [CmdletBinding()]
    param
    (
        # The major version of Puppet agent to install
        [Parameter(Mandatory = $false)]
        [string]
        $AgentVersion = '7',

        # The major version of Puppet bolt to install
        [Parameter(Mandatory = $false)]
        [string]
        $BoltVersion = '3',

        # Whether to install Puppet server or Puppet agent
        [Parameter(Mandatory = $false)]
        [string[]]
        [ValidateSet('agent', 'bolt')]
        $Application = 'agent'
    )

    begin
    {

    }

    process
    {
        foreach ($App in $Application)
        {
            if ($IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop'))
            {
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                $Administrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (!$Administrator)
                {
                    throw 'Must be run as administrator'
                }
                switch ($App)
                {
                    'agent'
                    {
                        $Command = 'puppet'
                        # Check to see if the user has supplied an exact version or just a major version
                        if ($AgentVersion -match '^\d+\.\d+\.\d+$')
                        {
                            Write-Verbose "Will attempt to install exact version '$AgentVersion' of Puppet agent"
                            $ExactVersion = $AgentVersion
                            $MajorVersion = $AgentVersion.Split('.')[0]
                        }
                        elseif ($AgentVersion -match '^\d+$')
                        {
                            Write-Verbose "Will attempt to install latest version for major version '$AgentVersion' of Puppet agent"
                            $ExactVersion = $null
                            $MajorVersion = $AgentVersion
                        }
                        else
                        {
                            throw "'-AgentVersion' must be a major version (e.g. 7) or an exact version (e.g. 7.10.2)"
                        }
                        $BaseURL = "http://downloads.puppetlabs.com/windows/puppet$($MajorVersion)"
                    }
                    'bolt'
                    {
                        $Command = 'bolt'
                        # Check to see if the user has supplied an exact version or just a major version
                        if ($BoltVersion -match '^\d+\.\d+\.\d+$')
                        {
                            Write-Verbose "Will attempt to install exact version '$BoltVersion' of Puppet bolt"
                            $ExactVersion = $BoltVersion
                            $MajorVersion = $BoltVersion.Split('.')[0]
                        }
                        elseif ($BoltVersion -match '^\d+$')
                        {
                            Write-Verbose "Will attempt to install latest version for major version '$BoltVersion' of Puppet bolt"
                            $ExactVersion = $null
                            $MajorVersion = $BoltVersion
                        }
                        else
                        {
                            throw "'-BoltVersion' must be a major version (e.g. 3) or an exact version (e.g. 3.23.1)"
                        }
                        # As of 2024-11-18, the bolt installers are not sectioned off into directories by major version
                        $BaseURL = 'http://downloads.puppetlabs.com/windows/puppet-tools'
                    }
                }
                $PuppetCheck = Get-Command $Command -ErrorAction SilentlyContinue
                if ($PuppetCheck)
                {
                    Write-Host "puppet-$App is already installed:`n$($PuppetCheck.Source)"
                    $InstallApplication = $false
                }
                if ($InstallApplication)
                {
                    if ($ExactVersion)
                    {
                        $DownloadURL = $BaseURL + "/puppet-$App-$($ExactVersion)-x64.msi"
                    }
                    else
                    {
                        $DownloadURL = $BaseURL + "/puppet-$App-x64-latest.msi"
                    }

                    # Download it
                    $TempFile = Join-Path $env:TEMP "$App.msi"
                    Write-Verbose "Downloading from $DownloadURL to $TempFile"
                    try
                    {
                        Invoke-WebRequest -Uri $DownloadURL -OutFile $TempFile
                    }
                    catch
                    {
                        throw "Failed to download $App.`n$($_.Exception.Message)"
                    }

                    # Install it
                    Write-Verbose "Installing from $TempFile"
                    # Use start process so we can wait for completion
                    $Install = Start-Process 'msiexec' -ArgumentList "/qn /norestart /i $TempFile" -Wait -NoNewWindow -PassThru
                    if ($Install.ExitCode -ne 0)
                    {
                        throw "Failed to install $App"
                    }
                    Write-Host "Successfully installed $App, you may need to restart your shell to use it"
                }
            }
            else
            {
                throw 'This PowerShell module is only supported on Windows, please use PuppetPython for other operating systems.'
            }
        }
    }

    end
    {

    }
}
