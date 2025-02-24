#!/usr/bin/bash
/puppet_bootstrap/bootstrap_puppet-linux.py \
    --agent-version "$1" \
    --puppet-server "puppetserver.example.com" \
    --environment "production" \
    --csr-extensions '{"pp_environment":"live","pp_role":"example_node","pp_service":"example_node"}' \
    --new-hostname "$2" \
    --unattended
