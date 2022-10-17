#!/bin/bash
# Script to install openssl and creeate a ca and client certificate

# Wrorking directory
WORKDIR=/root/ssl
timestamp=$(date +%Y%m%d%H%M%S)

# function to create the paths
function create_paths {
    mkdir -p $WORKDIR/{ca,client}
}

# function to install openssl
function install_openssl() {
    # check if dnf is installed or apt-get
    if [ -x "$(command -v dnf)" ]; then
        sudo dnf install openssl
    elif [ -x "$(command -v apt-get)" ]; then
        sudo apt-get install openssl
    else
        echo "No package manager found"
        exit 1
    fi
}

# generate ca cnf file
function generate_ca_cnf() {
    echo "[req]" > ${WORKDIR}/ca/ca.cnf
    echo "" >> ${WORKDIR}/ca/ca.cnf
    echo "prompt=no" >> ${WORKDIR}/ca/ca.cnf
    echo "distinguished_name=req_dn" >> ${WORKDIR}/ca/ca.cnf
    echo "req_extensions=req_ext" >> ${WORKDIR}/ca/ca.cnf
    echo "default_bits=4096    " >> ${WORKDIR}/ca/ca.cnf
    echo "default_md=SHA256" >> ${WORKDIR}/ca/ca.cnf
    echo "default_keyfile=\"ca.key\"" >> ${WORKDIR}/ca/ca.cnf
    echo "" >> ${WORKDIR}/ca/ca.cnf
    echo "[req_dn]" >> ${WORKDIR}/ca/ca.cnf
    echo "CN=${HOSTNAME}" >> ${WORKDIR}/ca/ca.cnf
    echo "O=<Organization>" >> ${WORKDIR}/ca/ca.cnf
    echo "OU=<Organizational Unit>" >> ${WORKDIR}/ca/ca.cnf
    echo "C=<Country>" >> ${WORKDIR}/ca/ca.cnf
    echo "L=<Locality>" >> ${WORKDIR}/ca/ca.cnf
    echo "" >> ${WORKDIR}/ca/ca.cnf
    echo "[req_ext]" >> ${WORKDIR}/ca/ca.cnf
    echo "keyUsage=digitalSignature, nonRepudiation, dataEncipherment" >> ${WORKDIR}/ca/ca.cnf
    echo "subjectAltName=@SANs" >> ${WORKDIR}/ca/ca.cnf
    echo "" >> ${WORKDIR}/ca/ca.cnf
    echo "[SANs]" >> ${WORKDIR}/ca/ca.cnf
    echo "DNS.1=${HOSTNAME}" >> ${WORKDIR}/ca/ca.cnf
    echo "Now edit the file ${WORKDIR}/ca/ca.cnf and add the correct values"
}

# generate server cnf file
function generate_client_cnf() {
    client=$1
    mkdir -p ${WORKDIR}/client/${client}
    echo "[req]" > ${WORKDIR}/client/${client}/${client}.cnf
    echo "" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "prompt=no" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "distinguished_name=req_dn" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "req_extensions=req_ext" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "default_bits=4096    " >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "default_md=SHA256" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "default_keyfile=\"server.key\"" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "[req_dn]" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "CN=${client}" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "O=<Organization>" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "OU=<Organizational Unit>" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "C=<Country>" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "L=<Locality>" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "[req_ext]" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "keyUsage=digitalSignature, nonRepudiation, dataEncipherment" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "subjectAltName=@SANs" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "[SANs]" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "DNS.1=${client}" >> ${WORKDIR}/client/${client}/${client}.cnf
    echo "Now edit the file ${WORKDIR}/client/${client}/${client}.cnf and add the correct values"
}

# create ca certificate
function create_ca() {
    if [ -f ${WORKDIR}/ca/ca.cnf ]; then
        mkdir -p ${WORKDIR}/ca/${timestamp}/
        openssl genrsa -aes128 -out ${WORKDIR}/ca/${timestamp}/ca.key 2048
        openssl req -new -config ${WORKDIR}/ca/ca.cnf -x509 -days 1825 -key ${WORKDIR}/ca/${timestamp}/ca.key -out ${WORKDIR}/ca/${timestamp}/ca.crt
        cp ${WORKDIR}/ca/${timestamp}/ca.crt ${WORKDIR}/ca/ca.crt
        cp ${WORKDIR}/ca/${timestamp}/ca.key ${WORKDIR}/ca/ca.key
        if [[ -f ${WORKDIR}/ca/${timestamp}/ca.key && -f ${WORKDIR}/ca/${timestamp}/ca.crt ]]; then
            echo "CA created"
        else
            echo "CA creation failed"
            exit 1
        fi
    else
        echo "CA config file not found. Run generate ca option first"
        exit 2
    fi
}

# create client certificate
function create_client() {
    client=$1
    if [ -f ${WORKDIR}/client/${client}/${client}.cnf ]; then
        mkdir -p ${WORKDIR}/client/${client}/${timestamp}/
        openssl req -new -config ${WORKDIR}/client/${client}/${client}.cnf -out ${WORKDIR}/client/${client}/${timestamp}/${client}.csr -keyout ${WORKDIR}/client/${client}/${timestamp}/${client}.key
        openssl x509 -req -in ${WORKDIR}/client/${client}/${timestamp}/${client}.csr -CA ${WORKDIR}/ca/ca.crt -CAkey ${WORKDIR}/ca/ca.key -CAcreateserial -out ${WORKDIR}/client/${client}/${timestamp}/${client}.crt -days 365
        if [[ -f ${WORKDIR}/client/${client}/${timestamp}/${client}.key && -f ${WORKDIR}/client/${client}/${timestamp}/${client}.crt ]]; then
            echo "Client certificate created"
        else
            echo "Client certificate creation failed"
            exit 1
        fi
    else
        echo "Client config file not found. Run generate client option first"
        exit 2
    fi
}

create_paths
case $1 in
    install_openssl)
        install_openssl
        ;;    
    ca)
        create_ca
        ;;
    client)
        create_client $2
        ;;
    generate)
        case $2 in
            ca)
                generate_ca_cnf
                ;;
            client)
                if [[ $# -eq 3 ]]; then
                    generate_client_cnf $3
                else
                    echo "Usage: $0 generate ca"
                    echo "or"
                    echo "Usage: $0 generate client <client name>"
                fi
                ;;
            *)
                echo "Usage: $0 generate ca"
                echo "or"
                echo "Usage: $0 generate client <client name>"
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 ca"
        echo "or"
        echo "Usage: $0 client <client name>"
        echo "or"
        echo "Usage: $0 generate ca"
        echo "or"
        echo "Usage: $0 generate client <client name>"
        ;;
esac
