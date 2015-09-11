#!/bin/sh -xe
# Simple integration test. Make sure to activate virtualenv beforehand
# (source venv/bin/activate) and that you are running Boulder test
# instance (see ./boulder-start.sh).
#
# Environment variables:
#   SERVER: Passed as "letsencrypt --server" argument.
#
# Note: this script is called by Boulder integration test suite!

. ./tests/integration/_common.sh
export PATH="/usr/sbin:$PATH"  # /usr/sbin/nginx


common() {
    letsencrypt_test \
        --authenticator standalone \
        --installer null \
        "$@"
}

common --domains le1.wtf auth
common --domains le2.wtf run
common -a manual -d le.wtf auth
common -a manual -d le.wtf --no-simple-http-tls auth

export CSR_PATH="${root}/csr.der" KEY_PATH="${root}/key.pem" \
       OPENSSL_CNF=examples/openssl.cnf
./examples/generate-csr.sh le3.wtf
common auth --csr "$CSR_PATH" \
       --cert-path "${root}/csr/cert.pem" \
       --chain-path "${root}/csr/chain.pem"
openssl x509 -in "${root}/csr/0000_cert.pem" -text
openssl x509 -in "${root}/csr/0000_chain.pem" -text

common --domain le3.wtf install \
       --cert-path "${root}/csr/cert.pem" \
       --key-path "${root}/csr/key.pem"

# the following assumes that Boulder issues certificates for less than
# 10 years, otherwise renewal will not take place
cat <<EOF > "$root/conf/renewer.conf"
renew_before_expiry = 10 years
deploy_before_expiry = 10 years
EOF
letsencrypt-renewer $store_flags
dir="$root/conf/archive/le1.wtf"
for x in cert chain fullchain privkey;
do
    latest="$(ls -1t $dir/ | grep -e "^${x}" | head -n1)"
    live="$(readlink -f "$root/conf/live/le1.wtf/${x}.pem")"
    [ "${dir}/${latest}" = "$live" ]  # renewer fails this test
done


if type nginx;
then
    . ./letsencrypt-nginx/tests/boulder-integration.sh
fi
