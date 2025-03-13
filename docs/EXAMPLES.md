# Examples

Below you'll find some examples of how to use the bootstrap scripts.

## Example 1: Bootstrapping a Linux agent in guided mode

```bash
# First download the script
curl -sSL https://raw.githubusercontent.com/red-gate/puppet-bootstrap-v2/main/bootstrap_puppet-linux.py

# Then call the script and it will guide you through the process
./bootstrap_puppet-linux.py
```

As no command line options have been provided, the script will guide you through the process of bootstrapping a Linux agent.
It will prompt you for all information required to configure and bootstrap the agent.

## Example 2: Bootstrapping a Windows agent in guided mode

```powershell
# First download the script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/red-gate/puppet-bootstrap-v2/main/bootstrap_puppet-windows.ps1' -OutFile bootstrap_puppet-windows.ps1

# Then call the script and it will guide you through the process
.\bootstrap_puppet-windows.ps1
```

As no command line options have been provided, the script will guide you through the process of bootstrapping a Linux agent.
It will prompt you for all information required to configure and bootstrap the agent.

## Example 3: Bootstrapping a Linux agent with common options set

```bash
# First download the script
curl -sSL https://raw.githubusercontent.com/red-gate/puppet-bootstrap-v2/main/bootstrap_puppet-linux.py

# Then call the script with all options set
./bootstrap_puppet-linux.py --new-hostname "linux-agent.example.com" --agent-version '7' --puppet-server "puppetserver.example.com" --environment "production" --csr-extensions '{"pp_environment":"live","pp_role":"example_node","pp_service":"example_node"}' --skip-optional-prompts
```

In this example, all required information has been provided as command line options. As the `--skip-optional-prompts` option has been provided, the script will not prompt for any additional information. A confirmation prompt will be displayed before any changes are made.

## Example 4: Bootstrapping a Windows agent in unattended mode

```powershell
# First download the script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/red-gate/puppet-bootstrap-v2/main/bootstrap_puppet-windows.ps1' -OutFile bootstrap_puppet-windows.ps1

# Then call the script with all options set
.\bootstrap_puppet-windows.ps1 -NewHostname "windows-agent.example.com" -AgentVersion '7' -PuppetServer "puppetserver.example.com" -Environment "production" -CsrExtensions @{pp_environment="live";pp_role="example_node";pp_service="example_node"} -Unattended
```

In this example all required information has been provided as command line options. As the `-Unattended` option has been provided, the script will not prompt for any additional information nor will it display a confirmation prompt before making changes.
