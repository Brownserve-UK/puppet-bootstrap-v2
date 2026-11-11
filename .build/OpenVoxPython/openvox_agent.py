#!/usr/bin/env python3

# ==============================================================================
# This script aids in the provisioning of OpenVox agent on Linux systems.
# It can be run in an unattended mode or in full interactive mode with guided
# prompts to help the user configure the system.
# Detailed information on the script can be found in the repo's README.md file.
# ==============================================================================

import os
import sys
import subprocess
import logging as log
import argparse
from urllib.request import urlretrieve
import re
import time
import json

### !!! Common Functions !!! ###

### Local functions ###
# Function to parse the command line arguments
def parse_args():
    # TODO: set types for the arguments
    parser = argparse.ArgumentParser(description="Install OpenVox Agent on Linux")
    parser.add_argument(
        "-v",
        "--agent-version",
        help="The version of OpenVox agent to install can be just the major version (e.g. '7') or the full version number (e.g. '7.12.0')",
        default="7",
    )
    parser.add_argument(
        "-s",
        "--openvox-server",
        help="The OpenVox server to connect to"
        )
    parser.add_argument(
        "-e",
        "--environment",
        help="The OpenVox environment to use",
        default="production",
    )
    parser.add_argument(
        "-c",
        "--csr-extensions",
        help="The CSR extension attributes to use",
        type=json.loads,
    )
    parser.add_argument(
        "--openvox-server-port",
        help="The port the OpenVox server is listening on",
        default="8140",
    )
    parser.add_argument(
        "--certificate-name",
        help="The certificate name to use"
        )
    parser.add_argument(
        "--enable-service",
        help="Enable the OpenVox service",
        default=True
    )
    parser.add_argument(
        "--csr-retry-interval",
        type=int,
        help="How long to wait for the certificate to be signed",
        default=30,
    )
    parser.add_argument(
        "--new-hostname",
        help="The new hostname to set"
        )
    parser.add_argument(
        "--skip-openvox-server-check",
        help="Skip the OpenVox server check",
        action="store_false",
    )
    parser.add_argument(
        "--skip-confirmation", help="Skip the confirmation prompt", action="store_true"
    )
    parser.add_argument(
        "--skip-optional-prompts", help="Skip optional prompts", action="store_true"
    )
    parser.add_argument(
        "--skip-initial-run", help="Skip the initial OpenVox run", action="store_true"
    )
    parser.add_argument(
        "--unattended", help="Run the script in unattended mode", action="store_true"
    )
    parser.add_argument(
        "-l",
        "--loglevel",
        help="Set the log level",
        choices=["ERROR", "INFO"],
        default="ERROR",
    )
    args = parser.parse_args()
    return args

# Main function
def main():
    # Set up logging - by default only log errors
    log.basicConfig(level=log.ERROR, format="%(asctime)s - %(levelname)s - %(message)s")

    app = "agent"
    skip_prompts = False
    skip_ping_check = False
    skip_confirmation = False
    unattended = False

    # Ensure we are in an environment that is supported and set some global variables
    get_os_id()
    check_supported_os()
    check_root()
    get_os_version()
    check_package_manager()

    # Parse the command line arguments
    args = parse_args()

    # Print out a welcome message
    print_welcome(app)

    if args.skip_optional_prompts:
        skip_prompts = True
    if args.skip_openvox_server_check:
        skip_ping_check = True
    if args.skip_confirmation:
        skip_confirmation = True
    if args.unattended:
        skip_prompts = True
        skip_ping_check = True
        skip_confirmation = True
        unattended = True

    ### Check we have all the _required_ information to proceed ###
    # We'll need to know the FQDN of the OpenVox server
    if not args.openvox_server:
        if unattended:
            print_error("Error: The OpenVox server FQDN is required for bootstrapping")
            sys.exit(1)
        openvox_server = None
        while not openvox_server:
            openvox_server = input("Please enter the FQDN of the OpenVox server: ")
    else:
        log.info(f"OpenVox server: {args.openvox_server}")
        openvox_server = args.openvox_server
    # Ensure the openvox_server is fully qualified
    if not re.match(r"(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}", openvox_server):
        if unattended:
            print_error("Error: The OpenVox server must be a fully qualified domain name")
            sys.exit(1)
        else:
            print_error("Error: The OpenVox server must be a fully qualified domain name")
            while not re.match(r"(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}", openvox_server):
                openvox_server = input("Please enter the FQDN of the OpenVox server: ")
    # Attempt to work out the domain name from the OpenVox server
    # It's useful to have the domain name for various parts of the logic throughout the script
    domain_name = openvox_server.split(".", 1)[1]
    # Strip the domain name of any leading periods
    domain_name = domain_name.lstrip(".")
    # If we don't have a version then we'll need to prompt the user
    if not args.agent_version:
        version_prompt = None
        while not version_prompt or not re.match(r"^\d+(\.\d+)*$", version_prompt):
            version_prompt = input(
                "Enter the version of OpenVox agent to install. Can be a major version (e.g. 7) or exact (e.g 7.1.2): "
            )
        version = version_prompt
    else:
        version = args.agent_version

    # Split the version into major and exact versions
    major_version, exact_version = split_version(version)
    if exact_version:
        message_version = exact_version
    else:
        message_version = f"{major_version} (latest available)"
    log.info(f"Major version: {major_version}, Exact version: {exact_version}")

    # Check if we can ping the OpenVox server, if not then raise an error and exit
    # This helps us avoid half configuring a system and failing at the end
    # If --skip-openvox-server-check is set then we'll skip this check
    if not skip_ping_check:
        try:
            subprocess.run(
                ["ping", "-c", "4", openvox_server],
                check=True,
                stdout=subprocess.DEVNULL,
            )
        except subprocess.CalledProcessError as e:
            print(
                f"Error: Could not ping the OpenVox server at {openvox_server}. Are you sure it's correct?"
            )
            sys.exit(1)

    current_hostname = subprocess.check_output(["hostname"], universal_newlines=True).strip()
    new_hostname = current_hostname

    # If the environment is set to the default of production then check if the user wants to change it
    if args.environment == "production" and not skip_prompts:
        print_important(
            "This machine will be bootstrapped from the 'production' environment"
        )
        environment_check = get_response(
            "Would you like to set a different environment?", "bool"
        )
        if environment_check:
            environment = get_response(
                "Please enter the environment to use", "string", mandatory=True
            )
        else:
            environment = args.environment
    else:
        environment = args.environment
    if not args.csr_extensions:
        if not skip_prompts:
            csr_check = get_response(
                "Would you like to set any CSR extension attributes?", "bool"
            )
            if csr_check:
                csr_extensions = get_csr_attributes()
            else:
                csr_extensions = None
        else:
            csr_extensions = None
    else:
        csr_extensions = args.csr_extensions

    if not args.new_hostname and not skip_prompts:
        new_hostname = check_hostname_change()
    else:
        new_hostname = args.new_hostname

    if not args.certificate_name:
        if not skip_prompts:
            set_certname = get_response(
                "Would you like to set a custom certificate name?", "bool"
            )
            if set_certname:
                certname = get_response(
                    "Please enter the certificate name to use", "string", mandatory=True
                )
            else:
                certname = None
        else:
            certname = None
    else:
        certname = args.certificate_name


    # If the new hostname isn't fully qualified it can cause us a couple of problems.
    # Firstly it can cause some issues when registering the node in DNS.
    # Secondly we end up with odd nodes hanging around in OpenVox which makes it harder to manage.
    # Therefore ensure the hostname is fully qualified at this stage, even if the user is
    # setting a custom certname for OpenVox
    if not re.match(r"(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}", new_hostname):
        print_important('The new hostname was not fully qualified, appending the domain name')
        # Add the same domain as the OpenVox server, that's usually a safe bet
        new_hostname = f"{new_hostname}.{domain_name}"
    else:
        log.info(f"New hostname appears to be fully qualified: {new_hostname}")
    ### Ensure the user is happy and wants to proceed ###
    confirmation_message = f"""
OpenVox will be installed and configured with the following settings:

    - OpenVox Agent version: {message_version}
    - OpenVox server: {openvox_server}
    - OpenVox port: {args.openvox_server_port}
    - OpenVox environment: {environment}
    - Hostname: {new_hostname}
"""
    if certname:
        confirmation_message += f"    - Certificate name: {certname}"
    if csr_extensions:
        confirmation_message += "    - CSR extension attributes:\n"
        for key, value in csr_extensions.items():
            confirmation_message += f"        - {key}: {value}\n"
    if args.csr_retry_interval > 0:
        confirmation_message += (
            f"    - Wait for certificate: {args.csr_retry_interval} seconds\n"
        )
    if args.enable_service:
        confirmation_message += "    - Enable the OpenVox service: true\n"

    print_important(confirmation_message)

    # Only ask the user to confirm if we're not skipping the confirmation
    if not skip_confirmation:
        confirm = get_response("Do you want to proceed?", "bool")
        if not confirm:
            print_error("User cancelled installation")
            sys.exit(0)
    else:
        # Even though the user has skipped the confirmation prompt lets just pause for 10 seconds
        # to make sure they have time to cancel the script if they want to
        time.sleep(10)

    ### Begin the installation process ###
    print_important("Beginning the bootstrap process")

    # Set the hostname
    # We do this first so we can ensure the certname is set correctly
    if new_hostname != current_hostname:
        print_important(f"Setting the hostname to {new_hostname}")
        set_hostname(new_hostname)
        # To ensure we get the correct certname we'll set the certname to the new hostname
        # unless the user has specified a custom certname
        if not certname:
            certname = new_hostname

    # Install the OpenVox agent package
    # First check if it's already installed, if it is then we can skip this step
    # We make the decision to still continue with the rest of the bootstrap process
    # if this leads to unforeseen consequences then we can change this behaviour
    # TODO: Fail on version mismatch?
    # TODO: Uninstall and reinstall?
    if check_openvox_app_installed(app):
        log.info(f"{app} is already installed")
        print(f"{app} is already installed - skipping installation")
    else:
        log.info(f"{app} is not installed")
        print_important(f"Installing OpenVox...")
        path = download_openvox_package_archive(app, major_version)
        install_package_archive(app, path)
        install_openvox_app(app, exact_version)

    # Set CSR extension attributes if they have been provided
    if csr_extensions:
        set_certificate_extensions(csr_extensions)

    # Set the puppet.conf options
    main_config_options = {"server": openvox_server, "masterport": args.openvox_server_port}
    if certname:
        main_config_options["certname"] = certname

    agent_config_options = {"environment": environment}

    set_openvox_config_option(main_config_options, section="main")
    set_openvox_config_option(agent_config_options, section="agent")

    # Trigger the initial OpenVox run if the user hasn't skipped it
    # OpenVox will exit with 2 if there are changes to be applied so we'll ignore that
    if not args.skip_initial_run:
        print_important("Performing first OpenVox run...")
        openvox_args = [openvox_bin, "agent", "--test", "--detailed-exitcodes"]
        if args.csr_retry_interval > 0:
            openvox_args.append(f"--waitforcert")
            openvox_args.append(str(args.csr_retry_interval))
            print_important(
                f"Please ensure you sign the certificate for this node on the OpenVox server."
            )
        try:
            subprocess.run(openvox_args, check=True)
        except subprocess.CalledProcessError as e:
            if e.returncode == 2 or e.returncode == 0:
                log.info("OpenVox run completed successfully")
                first_run = True
            else:
                # If we fail then we'll just log the error and continue with the bootstrap process
                print_error(
                    f"The initial run of OpenVox has failed :(\nThe bootstrap process will continue.\nError: {e}"
                )
                first_run = False
    else:
        first_run = False

    # Enable the OpenVox service if the user has requested it
    if args.enable_service:
        enable_openvox_service()

    # Print out a message to the user to let them know what to do next
    final_message = "Bootstrap process complete! :tada:\n"
    if first_run:
        final_message += "The initial OpenVox run has completed successfully and OpenVox should now be managing this node\n"
    else:
        final_message += "The initial OpenVox run has failed :cry: this node is still being managed by OpenVox but you'll need to investigate the failure.\n"

    print_important(final_message)


if __name__ == "__main__":
    main()
