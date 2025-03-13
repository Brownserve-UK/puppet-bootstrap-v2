# Puppet bootstrap scripts

This repository contains a set of scripts to bootstrap the installation and configuration of a Puppet server and Puppet agents.
These scripts are designed to be used in Redgate environments, but may well be easily adapted to other environments.

The scripts have been tested on the following operating systems:

`bootstrap_puppet-linux.py`:
    - Ubuntu 22.04
    - Ubuntu 24.04

`bootstrap_puppet-windows.py`:
    - Windows Server 2016
    - Windows Server 2019
    - Windows Server 2022
    - Windows 10

`bootstrap_puppet-server.py`:
    - Ubuntu 22.04

## Usage

All scripts can be run fully interactively, or with command line arguments to automate the process.
If you forget to supply a required argument, the script will prompt you for it.
Several checks are performed throughout the process to ensure that the likelihood of failure is minimized.
The script is designed in such a way that it should recover from a failed run, with a simple re-running of the script.

The scripts can also be run completely non-interactively by supplying all required arguments on the command line and passing the `unattended` flag. (see below for more information)

### bootstrap_puppet-linux.py

| **Parameter**                | **Description**                                                                                                                                                                                                                                                                                                     | **Mandatory** | **Default**  |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------------ |
| `--agent-version`            | The Version of Puppet Agent to be installed. This can be specified as a major version (e.g. `7`) or an exact version (e.g. `7.1.2`)                                                                                                                                                                                 | N             | `7`          |
| `--new-hostname`             | Allows you to set a new hostname for the node.  ⚠ **NOTE**: Hostnames _must_ be fully qualified on Linux (e.g. `node.example.com`)                                                                                                                                                                              | N             | N/A          |
| `--puppet-server`            | The FQDN of the Puppet server that will manage this node (e.g. `puppetserver.example.com`)                                                                                                                                                                                                                          | Y             | N/A          |
| `--puppet-server-port`       | The port to use to communicate with the Puppet server                                                                                                                                                                                                                                                               | N             | `8140`       |
| `--environment`              | The environment you wish to use                                                                                                                                                                                                                                                                                     | N             | `production` |
| `--certificate-name`         | Allows you to set a custom certificate name for this node in Puppet.                                                                                                                                                                                                                                                | N             | N/A          |
| `--csr-extensions`           | Any CSR extensions you wish to set, should be supplied in JSON format (e.g. `{"pp_service":"puppetserver","pp_role":"puppetserver","pp_environment":"live"})`                                                                                                                                                       | N             | N/A          |
| `--csr-retry-interval`       | How long Puppet waits (in seconds) before checking to see if the CSR has been signed on the Puppet server.  Setting this to `0` will stop Puppet from waiting at all and instead Puppet will exit as soon as the CSR has been performed. This may be desirable when you are configuring multiple nodes at once. | N             | `30`         |
| `--enable-service`           | Enables the Puppet Agent service at the end of the script.                                                                                                                                                                                                                                                          | N             | `true`       |
| `--skip-initial-run`         | At the end of the bootstrap process a Puppet run is triggered, passing this parameter skips that run. This may be useful if you've not finished configuring your node/environment yet.                                                                                                                              | N             | N/A          |
| `--skip-puppet-server-check` | Pass this to parameter to skip the check that is performed that ensures the node being bootstrapped can contact the Puppet server.                                                                                                                                                                                  | N             | N/A          |
| `--skip-optional-prompts`    | Pass this parameter to skip all the optional prompts in the bootstrap script. This is useful if you know you've provided all the information you require via the command line.                                                                                                                                      | N             | N/A          |
| `--skip-confirmation`        | Caution: Use with care.Passing this parameter allows you to bypass the confirmation that is displayed during the bootstrap process. This can be useful if you're confident you've passed in all the required information.                                                                                       | N             | N/A          |
| `--unattended`               | Instructs the script to run in `unattended mode` this bypasses all user prompts and will fail where user input would be required to correct an error.                                                                                                                                                               | N             | N/A          |

### bootstrap_puppet-windows.ps1

| **Parameter**                      | **Description**                                                                                                                                                                                                                                                                                                     | **Mandatory** | **Default**  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------------ |
| `-AgentVersion`                    | The Version of Puppet Agent to be installed. This can be specified as a major version (e.g. `7`) or an exact version (e.g. `7.1.2`)                                                                                                                                                                                 | N             | `7`          |
| `-NewHostName`                     | Allows you to set a new hostname for the node.  ⚠ **NOTE**: Hostnames _must_ **NOT** be fully qualified on Windows (e.g. `node.example.com` should just be `node`)                                                                                                                                              | N             | N/A          |
| `-PuppetServer`                    | The FQDN of the Puppet server that will manage this node (e.g. `puppetserver.example.com`)                                                                                                                                                                                                                          | Y             | N/A          |
| `-PuppetServerPort`                | The port to use to communicate with the Puppet server                                                                                                                                                                                                                                                               | N             | `8140`       |
| `-Environment`                     | The environment you wish to use                                                                                                                                                                                                                                                                                     | N             | `production` |
| `-CertificateName`                 | Allows you to set a custom certificate name for this node in Puppet.                                                                                                                                                                                                                                                | N             | N/A          |
| `-CSRExtensions`                   | Any CSR extensions you wish to set, should be supplied in JSON format (e.g. `{"pp_service":"puppetserver","pp_role":"puppetserver","pp_environment":"live"})`                                                                                                                                                       | N             | N/A          |
| `-CSRRetryInterval`                | How long Puppet waits (in seconds) before checking to see if the CSR has been signed on the Puppet server.  Setting this to `0` will stop Puppet from waiting at all and instead Puppet will exit as soon as the CSR has been performed. This may be desirable when you are configuring multiple nodes at once. | N             | `30`         |
| `-EnableService`                   | Enables the Puppet Agent service at the end of the bootstrap process.                                                                                                                                                                                                                                               | N             | `$true`      |
| `-PuppetServiceAccountCredentials` | Allows you to specify the credentials (in `PSCredential` format) for the Puppet Agent service to use. When using domain accounts you should **NOT** fully qualify them and instead use the `-PuppetServiceAccountDomain` parameter to set the domain name.                                                          | N             | N/A          |
| `-PuppetServiceAccountDomain`      | When using a domain account to run the Puppet Agent service use this parameter to specify the domain name.                                                                                                                                                                                                          | N             | N/A          |
| `-SkipInitialRun`                  | At the end of the bootstrap process a Puppet run is triggered, passing this parameter skips that run. This may be useful if you've not finished configuring your node/environment yet.                                                                                                                              | N             | N/A          |
| `-SkipPuppetServerCheck`           | Pass this to parameter to skip the check that is performed that ensures the node being bootstrapped can contact the Puppet server.                                                                                                                                                                                  | N             | N/A          |
| `-SkipOptionalPrompts`             | Pass this parameter to skip all the optional prompts in the bootstrap script. This is useful if you know you've provided all the information you require via the command line.                                                                                                                                      | N             | N/A          |
| `-SkipConfirmation`                | Caution: Use with care.Passing this parameter allows you to bypass the confirmation that is displayed during the bootstrap process. This can be useful if you're confident you've passed in all the required information.                                                                                       | N             | N/A          |
| `-Unattended`                      | Instructs the script to run in `unattended mode` this bypasses all user prompts and will fail where user input would be required to correct an error.                                                                                                                                                               | N             | N/A          |

### bootstrap_puppet-server.py

| **Parameter**                 | **Description**                                                                                                                                                                                                                   | **Mandatory** | **Default**            |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ---------------------- |
| `--puppetserver-version`      | The Version of Puppet Server to be installed. This can be specified as a major version (e.g. `7`) or an exact version (e.g. `7.1.2`)                                                                                              | Y             | N/A                    |
| `--new-hostname`              | Allows you to set a new hostname for the node.  ⚠ **NOTE**: Hostnames _must_ be fully qualified on Linux (e.g. `puppetserver.example.com`)                                                                                    | N             | N/A                    |
| `--bootstrap-environment`     | The environment you wish to use to bootstrap from. If you have a special environment for bootstrapping Puppet then set this here.                                                                                                 | N             | `production`           |
| `--bootstrap-hiera`           | The Hiera file to use when bootstrapping a new Puppet Server. Path is relative to the root of your Puppet code repository.                                                                                                        | N             | `hiera.bootstrap.yaml` |
| `--puppetserver-class`        | The name of your Puppet Server class/module. This is used in the Puppet Apply step to ensure the correct class is applied to the Puppet server.                                                                                   | N             | N/A                    |
| `--csr-extensions`            | Any CSR extensions you wish to set, should be supplied in JSON format (e.g. `{"pp_service":"puppetserver","pp_role":"puppetserver","pp_environment":"live"})`                                                                     | N             | N/A                    |
| `--r10k-repository`           | If you wish to use `r10k` to manage your environments then specify your repository here.                                                                                                                                          | N             | N/A                    |
| `--r10k-repository-key`       | If you are using SSH to access your repository please provide the SSH/deploy key here.**NOTE**: This needs to be a path to a key on disk as opposed to the contents of an SSH key directly (e.g. `/home/joebloggs/r10k_key`). | N             | N/A                    |
| `--r10k-repository-key-owner` | The local user who should own the repository key.                                                                                                                                                                                 | N             | `root`                 |
| `--r10k-version`              | The version of `r10k` to install. If unspecified the latest version will be installed, however depending on the version of Ruby you have available you may wish to specify this manually.                                         | N             | N/A                    |
| `--eyaml-privatekey`          | If you wish to use `hiera-eyaml` then please provide the path on disk to your _private_ key here (typically called `private_key.pkcs7.pem`)                                                                                       | N             | N/A                    |
| `--eyaml-publickey`           | If you wish to use `hiera-eyaml` then please provide the path on disk to your _public_ key here (typically called `public_key.pkcs7.pem`)                                                                                         | N             | N/A                    |
| `--hiera-eyaml-version`       | Allows you to override the version of the `hiera-eyaml` gem that's installed. This is usually dependant on the version of Ruby/Puppet server you have. Leave blank to install the latest available version                        | N             | N/A                    |
| `--remove-original-keys`      | When set to `true` this will clean-up any user supplied `eyaml` and `r10k` keys after they have been successfully copied to their respective locations.Please note this defaults to `true` for security.                      | N             | `true`                 |
| `--r10k-path`                 | Allows you to provide a path to the `r10k` binary in case the script struggles to find it.                                                                                                                                        | N             | N/A                    |
| `--skip-initial-run`          | At the end of the bootstrap process a Puppet run is triggered, passing this parameter skips that run. This may be useful if you've not finished configuring your node/environment yet.                                            | N             | N/A                    |
| `--skip-optional-prompts`     | Pass this parameter to skip all the optional prompts in the bootstrap script. This is useful if you know you've provided all the information you require via the command line.                                                    | N             | N/A                    |
| `--skip-confirmation`         | Caution: Use with care.Passing this parameter allows you to bypass the confirmation that is displayed during the bootstrap process. This can be useful if you're confident you've passed in all the required information.     | N             | N/A                    |
| `--unattended`                | Instructs the script to run in `unattended mode` this bypasses all user prompts and will fail where user input would be required to correct an error.                                                                             | N             | N/A                    |

## Examples

You can find some examples of how to use the bootstrap scripts in the [EXAMPLES.md](docs/EXAMPLES.md) file.

## Development

> ℹ Please keep in mind the philosophy of these scripts is to be simple yet powerful.
They should guide a novice user through the process of bootstrapping a Puppet server or agent, but also allow an experienced user to automate the process.

### Building the Python scripts

The `bootstrap_puppet-linux.py` and `bootstrap_puppet-server.py` scripts share a lot of the same code.
Therefore to cut down on duplication, the shared code has been moved into a separate file called [`common.py`](.build/PuppetPython/common.py) this is then combined with the main script files ([`puppet_agent.py`](.build/PuppetPython/puppet_agent.py) and [`puppet_server.py`](.build/PuppetPython/puppet_server.py)) to create the final scripts.

To build the scripts, simply run the following command from the root of the repository:

```powershell
.\.build\PuppetPython\build.ps1
```

This will update the `bootstrap_puppet-linux.py` and `bootstrap_puppet-server.py` scripts in the root of the repository, with any changes made to the `puppet_agent.py` and `puppet_server.py` files in the `.build/PuppetPython` directory.

### Testing

In the `.build` directory you will find a Vagrantfile that can be used to test the scripts in a controlled environment.

#### Pre-requisites

* Vagrant (Tested with version 2.4.1)
* VirtualBox (Tested with version 7.0.14)
* At least 16GB of RAM on the host machine

#### Running the tests

To run the automated tests, simply run the following command from the `.build` directory:

```bash
vagrant up
```

This will first bootstrap the Puppet server and then 2 agents - one Windows and one Linux.
All 3 machines will be bootstrapped using the scripts in this repository in unattended mode.

If you wish to run the tests in interactive mode, you can do so by running the following command:

```bash
vagrant up auto-puppetserver manual-linux-agent manual-windows-agent
```

This will spin up a Puppet server and 2 agents, the Puppet server will be bootstrapped in unattended mode, however the agents won't be bootstrapped at all.
You can then `vagrant ssh` or `vagrant winrm` into the machines and run the scripts manually.
The scripts should be available in the `/puppet_bootstrap` directory on the machines.
