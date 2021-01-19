#!/bin/bash -i
CA_SUBJ="/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=your_store"
SERVER_SUBJ="/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=your_store"
SERVER_NAME="server"
SERVER_DIR=/etc/openvpn/$SERVER_NAME
SERVER_IP1=""
SERVER_IP2=""
KEY_USAGE_CLIENT="clientAuth"
KEY_USAGE_SERVER="serverAuth"
RAND=".rnd"
KEYS=$SERVER_DIR/keys
CRL=$SERVER_DIR/crl
CCD=$SERVER_DIR/ccd
CONF=$SERVER_DIR/configs
source lib.sh   # lib with function (subroutins)

v3_extFileCreate $KEY_USAGE_CLIENT
v3_extFileCreate $KEY_USAGE_SERVER

configOpensslCreate

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    pki)
    createPKI
    shift # past argument
    ;;
    -c|--client)
    createClient $2
    shift # past argument
    shift # past value
    ;;
    -f|--file)
    file="$2"
    createClientsFromFile $file
    shift # past argument
    shift # past value
    ;;
    -r|--revoke)
    cert="$2"
    revokeCert $2
    shift # past argument
    shift # past value
    ;;
    -m|--makeconfig)
      shift
      confServerCreate
    ;;
    *)    # unknown option
    help
    shift # past argument
    ;;
esac
done

rm -rf v3.$KEY_USAGE_CLIENT v3.KEY_USAGE_SERVER cfg
