#!/bin/bash

CERTS_DIR=/data/k8s-data/docker/certs
PASSWORD="EmED&QxK#QBD2$"
COUNTRY=CN
PROVINCE=Beijing
CITY=Beijing
ORGANIZATION=linchqd
GROUP=linchqd
HOST=linchqd.com
SUBJ="/C=${COUNTRY}/ST=${PROVINCE}/L=${CITY}/O=${ORGANIZATION}/OU=${GROUP}/CN=${HOST}"
IPS=$(ip a | grep inet | awk '{print $2}' | awk -F "/" '{printf "IP:%s,",$1}' | sed 's/.$//')

# create ca certs
create_ca_certs(){
    if [[ ! -e ${CERTS_DIR}/ca-key.pem ]];then
        openssl genrsa -passout pass:${PASSWORD} -aes256 -out ${CERTS_DIR}/ca-key.pem 4096
        openssl req -passin pass:${PASSWORD} -new -x509 -days 365 -key ${CERTS_DIR}/ca-key.pem -sha256 -out ${CERTS_DIR}/ca.pem -subj ${SUBJ}
    else
        echo "the ca file is exists,don't create again!"
    fi
}

# create server certs
create_server_certs(){
    if [[ -e ${CERTS_DIR}/ca-key.pem ]];then
        openssl genrsa -out ${CERTS_DIR}/server-key.pem 4096
        openssl req -subj "/CN=${HOST}" -sha256 -new -key ${CERTS_DIR}/server-key.pem -out ${CERTS_DIR}/server.csr
        echo subjectAltName = DNS:dns.linchqd.com,${IPS} >> ${CERTS_DIR}/extfile.cnf
        echo extendedKeyUsage = serverAuth >> ${CERTS_DIR}/extfile.cnf
        openssl x509 -passin pass:${PASSWORD} -req -days 365 -sha256 -in ${CERTS_DIR}/server.csr -CA ${CERTS_DIR}/ca.pem -CAkey ${CERTS_DIR}/ca-key.pem -CAcreateserial -out ${CERTS_DIR}/server-cert.pem -extfile ${CERTS_DIR}/extfile.cnf
    else
        echo "the ca file is not exists!"
        exit 1
    fi
}

# create client certs
create_client_certs(){
    if [[ -e ${CERTS_DIR}/ca-key.pem ]];then
        openssl genrsa -out ${CERTS_DIR}/client-key.pem 4096
        openssl req -subj '/CN=client' -new -key ${CERTS_DIR}/client-key.pem -out ${CERTS_DIR}/client.csr
        echo extendedKeyUsage = clientAuth > ${CERTS_DIR}/extfile-client.cnf
        openssl x509 -passin pass:${PASSWORD} -req -days 365 -sha256 -in ${CERTS_DIR}/client.csr -CA ${CERTS_DIR}/ca.pem -CAkey ${CERTS_DIR}/ca-key.pem -CAcreateserial -out ${CERTS_DIR}/client-cert.pem -extfile ${CERTS_DIR}/extfile-client.cnf
    else
        echo "the ca file is not exists!"
        exit 1
    fi
}

if [[ $# != 1 ]] ; then
    echo "USAGE: $0 [ca|server|client|all]"
    exit 1;
fi
if [[ ! -d ${CERTS_DIR} ]];then
    mkdir -p ${CERTS_DIR}
fi
case $1 in
    "ca")
    create_ca_certs
    chmod -v 0444 ${CERTS_DIR}/ca.pem
    chmod -v 0400 ${CERTS_DIR}/ca-key.pem
    ;;
    "server")
    create_server_certs
    chmod -v 0444 ${CERTS_DIR}/server-cert.pem
    chmod -v 0400 ${CERTS_DIR}/server-key.pem
    ;;
    "client")
    create_client_certs
    chmod -v 0444 ${CERTS_DIR}/client-cert.pem
    chmod -v 0400 ${CERTS_DIR}/client-key.pem
    ;;
    "all")
    create_ca_certs
    create_server_certs
    create_client_certs
    ;;
    *)
    echo "USAGE: $0 [ca|server|client]"
    ;;
esac
rm -rf ${CERTS_DIR}/*.csr ${CERTS_DIR}/*.cnf ${CERTS_DIR}/*.srl
