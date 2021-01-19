# Block 1. Create configuration files for creation pki: v3_ext_client, v3_ext_srv, cfg(=openssl.cfg)
function v3_extFileCreate()
{
key_usage=$1
cat > v3.$1 << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = $key_usage
subjectAltName = @alt_names
[alt_names]
DNS.1=localhost
DNS.2=hostname
EOF
}

function configOpensslCreate()
{
cat > cfg << EOL
[ req ]
default_bits            = 2048
#attributes              = req_attributes
x509_extensions = v3_ca 
distinguished_name = req_distinguished_name

[req_distinguished_name]
# empty.

[ ca ]
default_ca      = CA_default            # The default ca section

####################################################################
[ CA_default ]
certs           = $SERVER_DIR/keys           # Where the issued certs are kept
crl_dir         = $SERVER_DIR/crl              # Where the issued crl are kept
database        = $SERVER_DIR/keys/index.txt        # database index file.
#unique_subject = no                    # Set to 'no' to allow creation of
                                        # several certs with same subject.
new_certs_dir   = $SERVER_DIR/keys         # default place for new certs.

certificate     = $SERVER_DIR/keys/ca.cert       # The CA certificate
#serial          = $SERVER_DIR/serial           # The current serial number
crlnumber       = $SERVER_DIR/crl/crlnumber        # the current crl number
                                        # must be commented out to leave a V1 CRL
crl             = $SERVER_DIR/crl/crl.pem          # The current CRL
private_key     = $SERVER_DIR/keys/ca.key # The private key

x509_extensions = usr_cert               # The extensions to add to the cert
#name_opt        = ca_default            # Subject Name options
#cert_opt        = ca_default            # Certificate field options
default_days    = 3650                   # how long to certify for
default_crl_days= 3650                    # how long before next CRL
default_md      = sha256               # use public key default MD
preserve        = no
policy          = policy_any
rand_serial     = yes

[ policy_any ]
countryName            = supplied
stateOrProvinceName    = optional
organizationName       = optional
organizationalUnitName = optional
commonName             = supplied
emailAddress           = optional

[ v3_ca ]
# Extensions for a typical CA
# PKIX recommendation.
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true

EOL
}
confServerCreate()
{
config=$CONF/$SERVER_NAME.conf
ca=$KEYS/ca.cert
cert=$KEYS/${SERVER_NAME}.cert
key=$KEYS/${SERVER_NAME}.key
ta=$KEYS/ta.key
dh=$KEYS/dhparams.pem
cat << EOL > $config
local 0.0.0.0
port 52194
proto udp
dev tun
client-config-dir /etc/openvpn/ccd
crl-verify $CRL/crl.pem
ccd-exclusive


verify-client-cert require

tls-server
key-direction 0
tls-version 1.2 or-highest
;tls-auth /etc/openvpn/keys/ta.key 0   ; for server
tls-timeout 120

server 10.11.12.0 255.255.255.0

user nobody
group nobody
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append  /var/log/openvpn/openvpn.log
verb 4
;dh /etc/openvpn/server/keys/dhparams.pem

EOL
echo "<ca>" >> $config
cat $ca >> $config
echo "</ca>" >> $config

echo "<cert>" >> $config
openssl x509 -in $cert >> $config
echo "</cert>" >> $config

echo "<key>" >> $config
cat $key >> $config
echo "</key>" >> $config

echo "<dh>" >> $config
cat $dh >> $config
echo "</dh>" >> $config

echo "<tls-auth>" >> $config
cat $ta >> $config
echo "</tls-auth>" >> $config
}

confClientCreate()
{
client=$1
config=$CONF/$client.conf
ca=$KEYS/ca.cert
cert=$KEYS/${client}.cert
key=$KEYS/${client}.key
ta=$KEYS/ta.key
#dh=$KEYS/dhparams.pem
cat << EOL > $config
remote $SERVER_IP1
remote $SERVER_IP2
port 52194
proto udp
dev tun

tls-client
key-direction 1
tls-version 1.2 or-highest
tls-timeout 120
keepalive 10 120
persist-key
persist-tun
verb 4

EOL
echo "<ca>" >> $config
cat $ca >> $config
echo "</ca>" >> $config

echo "<cert>" >> $config
openssl x509 -in $cert >> $config
echo "</cert>" >> $config

echo "<key>" >> $config
cat $key >> $config
echo "</key>" >> $config

echo "<tls-auth>" >> $config
cat $ta >> $config
echo "</tls-auth>" >> $config
}

createPKI()
{
  sudo rm -rf ca.cert ta.key server* client* .rnd $SERVER_DIR v3.*
  sudo mkdir -p $SERVER_DIR/{certs,crl,keys,ccd,configs}
  sudo touch $SERVER_DIR/keys/index.txt
  # create random file
  openssl rand 512 > $RAND
  # certificate extension for server and client , used when signing cert request
  v3_extFileCreate $KEY_USAGE_SERVER
  #Create openssl config
  configOpensslCreate
  # Selfsigned certificate creation
  sudo openssl req -nodes -x509 -newkey rsa:4096 -sha256 -days 3650 -rand $RAND -keyout $KEYS/ca.key -out $KEYS/ca.cert -subj $CA_SUBJ
  # DH create
  openssl dhparam -out $KEYS/dhparams.pem 2048
  # ta.key create
  sudo openvpn --genkey --secret $KEYS/ta.key
  # Request for server certificate creation
  sudo openssl req -nodes -newkey rsa:4096 -sha256 -rand $RAND -keyout $KEYS/$SERVER_NAME.key -out $KEYS/$SERVER_NAME.csr -config cfg -subj $SERVER_SUBJ
  # Sign request , need v3.file to create
  sudo openssl ca -days 3650 -extfile v3.$KEY_USAGE_SERVER -cert $KEYS/ca.cert -keyfile $KEYS/ca.key -in $KEYS/$SERVER_NAME.csr -out $KEYS/$SERVER_NAME.cert -config cfg -notext -batch
  # Create config for server $CONF/$SERVER_NAME.conf
  confServerCreate
  # Create crl.pem list
  echo 1000 > $SERVER_DIR/crl/crlnumber
  sudo openssl ca -gencrl -out $SERVER_DIR/crl/crl.pem -config cfg
  rm -rf v3.*
}

# Creation and signing client certificate. client name = cn required.
createClient()
{
  if [ -z $1 ];then echo "client name required"; exit 1;fi
  client=$1
  v3_extFileCreate $KEY_USAGE_CLIENT
  CLIENT_SUBJ="/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=$client"
  # Request to sign for client certificate
  sudo openssl req -nodes -newkey rsa:4096 -sha256 -rand $RAND -keyout $KEYS/$client.key -out $KEYS/$client.csr \
  -subj $CLIENT_SUBJ

  #openssl x509 -req -sha256 -days 3650 -extfile v3.$KEY_USAGE_CLIENT -CA $KEYS/ca.cert -CAkey $KEYS/ca.key -CAcreateserial -in $KEYS/$client.csr -out $KEYS/$client.cert
  sudo openssl ca  -days 3650 -extfile v3.$KEY_USAGE_CLIENT -in $KEYS/$client.csr -out $KEYS/$client.cert -config cfg -notext -batch
  sudo touch $CCD/$client
  confClientCreate $client
  rm -rf v3.*
}

createClientsFromFile()
{
  while read line
  do
    createClient $line
  done < $1
}

revokeCert()
{
  client=$1
  if [ -f $SERVER_DIR/keys/${client}.cert ];then
    sudo openssl ca -revoke $SERVER_DIR/keys/${client}.cert -crl_reason unspecified -config cfg
    sudo openssl ca -gencrl -out $SERVER_DIR/crl/crl.pem -config cfg
    sudo rm -rf $CCD/$client
  else
    echo "file $SERVER_DIR/keys/${client}.cert does not exist!"
    exit 1
  fi
}

help()
{
  cat << EOF
  Usage:
  ./pki_deploy.sh [pki] [-c|--client client_name] [-f|--file filename]  [-r|--revoke client_name]
  file должен содержать номер или имя клиента на одной строчке, дублирование имен не допускается
EOF
}
