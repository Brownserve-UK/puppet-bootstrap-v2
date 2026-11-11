#!/usr/bin/bash
/puppet_bootstrap/bootstrap_openvox-server.py \
    --openvox-server-version "$1" \
    --new-hostname "$2" \
    --bootstrap-environment "production" \
    --bootstrap-hiera "hiera.bootstrap.yaml" \
    --csr-extensions '{"pp_environment":"live","pp_role":"puppet7_server","pp_service":"puppetserver"}' \
    --openvox-server-class "puppetserver" \
    --r10k-repository "https://github.com/Brownserve-UK/puppet_hiera_example.git" \
    --eyaml-privatekey "/vagrant/.vagrant-files/private_key.pkcs7.pem" \
    --eyaml-publickey "/vagrant/.vagrant-files/public_key.pkcs7.pem" \
    --remove-original-keys 'false' \
    --unattended

auto_sign_path='/etc/puppetlabs/puppet/autosign.conf'
auto_sign_content='*.example.com'

echo $auto_sign_content > $auto_sign_path

# Perform a second run to ensure the puppetserver is fully configured
/opt/puppetlabs/bin/puppet agent -t
