[CmdletBinding()]
param(
    [string]$Hostname,
    [string]$AgentVersion
)

C:\puppet_bootstrap\bootstrap_puppet-windows.ps1 `
    -AgentVersion '7' `
    -PuppetServer 'puppetserver.example.com' `
    -Environment 'production' `
    -CSRExtensions @{'pp_environment'='live';'pp_role'='example_node';'pp_service'='example_node'} `
    -NewHostname $Hostname `
    -Unattended `
    -Verbose
