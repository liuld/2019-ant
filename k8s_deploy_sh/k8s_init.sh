#!/bin/bash

# 获取变量信息（当前通过自定义，后面通过web页面获取)
CLUSTER_DIR="/data/k8s-data"
CLUSTER_SVC_CIDR="192.168.200.0/24"
CLUSTER_POD_CIDR="172.16.0.0/16"
CLUSTER_APISERVER_SVC_IP="192.168.200.1"
CLUSTER_DNS_SVC_IP="192.168.200.2"
CLUSTER_REGISTRY_URL="registry.cqt.com:5000"
CLUSTER_SVC_NODE_PORT_RANGE="30000-32767"
CLUSTER_DNS_DOMAIN="cluster.local"
CLUSTER_MANIFESTS_DIR="${CLUSTER_DIR}/manifests"
CLUSTER_CONFIG_DIR="${CLUSTER_DIR}/config"
CLUSTER_LOGS_DIR="${CLUSTER_DIR}/logs"
CLUSTER_DATA_DIR="${CLUSTER_DIR}/data"
CLUSTER_CERTS_DIR="${CLUSTER_DIR}/certs"
CLUSTER_MASTER_1="192.168.10.110"
CLUSTER_MASTER_2="192.168.10.120"
CLUSTER_MASTER_3="192.168.10.130"
CLUSTER_APISERVER_VIP="https://${CLUSTER_MASTER_1}:8443"
CLUSTER_KUBELET_TOKEN=""
CLUSTER_APISERVER_ENCRYPT_SECRET=$(head -c 32 /dev/urandom | base64)
CLUSTER_DOCKERBINFILE_URL="http://192.168.10.10:8080/docker-19.03.1.tgz"
CLUSTER_KUBELETBINFILE_URL="http://192.168.10.10:8080/kubelet-v1.14.5.tgz"

# 创建所需证书文件
create_cluster_certs(){
    mkdir -p ${CLUSTER_CERTS_DIR}/ca
    cat > ${CLUSTER_CERTS_DIR}/ca/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
    cat > ${CLUSTER_CERTS_DIR}/ca/ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "cqt"
    }
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF
    cfssl gencert -initca ${CLUSTER_CERTS_DIR}/ca/ca-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/ca/ca
    mkdir -p ${CLUSTER_CERTS_DIR}/etcd
    cat > ${CLUSTER_CERTS_DIR}/etcd/etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${CLUSTER_MASTER_1}",
    "${CLUSTER_MASTER_2}",
    "${CLUSTER_MASTER_3}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "cqt"
    }
  ]
}
EOF
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/etcd/etcd-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/etcd/etcd
    mkdir -p ${CLUSTER_CERTS_DIR}/kube-apiserver
    cat > ${CLUSTER_CERTS_DIR}/kube-apiserver/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "${CLUSTER_MASTER_1}",
    "${CLUSTER_MASTER_2}",
    "${CLUSTER_MASTER_3}",
    "${CLUSTER_APISERVER_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local."
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "cqt"
    }
  ]
}
EOF
    cat > ${CLUSTER_CERTS_DIR}/kube-apiserver/proxy-client-csr.json <<EOF
{
  "CN": "aggregator",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "cqt"
    }
  ]
}
EOF
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/kube-apiserver/kubernetes-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/kube-apiserver/kubernetes
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/kube-apiserver/proxy-client-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/kube-apiserver/proxy-client
    mkdir -p ${CLUSTER_CERTS_DIR}/kube-controller-manager
    cat > ${CLUSTER_CERTS_DIR}/kube-controller-manager/kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "${CLUSTER_MASTER_1}",
      "${CLUSTER_MASTER_2}",
      "${CLUSTER_MASTER_3}"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-controller-manager",
        "OU": "cqt"
      }
    ]
}
EOF
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/kube-controller-manager/kube-controller-manager-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/kube-controller-manager/kube-controller-manager
    mkdir -p ${CLUSTER_CERTS_DIR}/kube-scheduler
    cat > ${CLUSTER_CERTS_DIR}/kube-scheduler/kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
      "${CLUSTER_MASTER_1}",
      "${CLUSTER_MASTER_2}",
      "${CLUSTER_MASTER_3}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-scheduler",
        "OU": "cqt"
      }
    ]
}
EOF
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/kube-scheduler/kube-scheduler-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/kube-scheduler/kube-scheduler
    mkdir -p ${CLUSTER_CERTS_DIR}/kube-proxy
    cat > ${CLUSTER_CERTS_DIR}/kube-proxy/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "cqt"
    }
  ]
}
EOF
    cfssl gencert -ca=${CLUSTER_CERTS_DIR}/ca/ca.pem -ca-key=${CLUSTER_CERTS_DIR}/ca/ca-key.pem -config=${CLUSTER_CERTS_DIR}/ca/ca-config.json -profile=kubernetes ${CLUSTER_CERTS_DIR}/kube-proxy/kube-proxy-csr.json | cfssljson -bare ${CLUSTER_CERTS_DIR}/kube-proxy/kube-proxy
}
if [[ ! -e ${CLUSTER_CERTS_DIR}/result.txt ]];then
    create_cluster_certs
    mv ${CLUSTER_CERTS_DIR}/ca/ca-config.json ${CLUSTER_CERTS_DIR}/ca/ca-key.pem ${CLUSTER_CERTS_DIR}/../../
    cp ${CLUSTER_CERTS_DIR}/../../ca-key.pem ${CLUSTER_CERTS_DIR}/ca/ca.pem ${CLUSTER_CERTS_DIR}/kube-controller-manager/
    find ${CLUSTER_CERTS_DIR}/ ! -name "*.pem" -a ! -name "*.sh" -type f -exec rm -rf {} \;
    echo "success" > ${CLUSTER_CERTS_DIR}/result.txt
fi
# 生成docker ca证书
#/usr/local/bin/mk-docker-certs.sh ca
# 生成salt roster/pillar文件
mkdir /data/salt /data/pillar -p
cat > /data/roster <<EOF
${CLUSTER_MASTER_1}:
  host: ${CLUSTER_MASTER_1}
${CLUSTER_MASTER_2}:
  host: ${CLUSTER_MASTER_2}
${CLUSTER_MASTER_3}:
  host: ${CLUSTER_MASTER_3}
EOF

cat > /data/pillar/top.sls <<EOF
base:
  '*':
    - cluster-config
  '${CLUSTER_MASTER_1}':
    - CLUSTER_MASTER_1
  '${CLUSTER_MASTER_2}':
    - CLUSTER_MASTER_2
  '${CLUSTER_MASTER_3}':
    - CLUSTER_MASTER_3
EOF

cat > /data/pillar/cluster-config.sls <<EOF
CLUSTER_DIR: "${CLUSTER_DIR}"
CLUSTER_SVC_CIDR: "${CLUSTER_SVC_CIDR}"
CLUSTER_POD_CIDR: "${CLUSTER_POD_CIDR}"
CLUSTER_APISERVER_SVC_IP: "${CLUSTER_APISERVER_SVC_IP}"
CLUSTER_DNS_SVC_IP: "${CLUSTER_DNS_SVC_IP}"
CLUSTER_REGISTRY_URL: "${CLUSTER_REGISTRY_URL}"
CLUSTER_APISERVER_VIP: "${CLUSTER_APISERVER_VIP}"
CLUSTER_SVC_NODE_PORT_RANGE: "${CLUSTER_SVC_NODE_PORT_RANGE}"
CLUSTER_DNS_DOMAIN: "${CLUSTER_DNS_DOMAIN}"
CLUSTER_MANIFESTS_DIR: "${CLUSTER_MANIFESTS_DIR}"
CLUSTER_CONFIG_DIR: "${CLUSTER_CONFIG_DIR}"
CLUSTER_LOGS_DIR: "${CLUSTER_LOGS_DIR}"
CLUSTER_DATA_DIR: "${CLUSTER_DATA_DIR}"
CLUSTER_CERTS_DIR: "${CLUSTER_CERTS_DIR}"
CLUSTER_MASTER_1: "${CLUSTER_MASTER_1}"
CLUSTER_MASTER_2: "${CLUSTER_MASTER_2}"
CLUSTER_MASTER_3: "${CLUSTER_MASTER_3}"
CLUSTER_KUBELET_TOKEN: "${CLUSTER_KUBELET_TOKEN}"
CLUSTER_APISERVER_ENCRYPT_SECRET: "${CLUSTER_APISERVER_ENCRYPT_SECRET}"
CLUSTER_DOCKERBINFILE_URL: "${CLUSTER_DOCKERBINFILE_URL}"
CLUSTER_KUBELETBINFILE_URL: "${CLUSTER_KUBELETBINFILE_URL}"
EOF

cat > /data/pillar/CLUSTER_MASTER_1.sls <<EOF
ROLES: "CLUSTER_MASTER_1"
IP: "${CLUSTER_MASTER_1}"
EOF

cat > /data/pillar/CLUSTER_MASTER_2.sls <<EOF
ROLES: "CLUSTER_MASTER_2"
IP: "${CLUSTER_MASTER_2}"
EOF

cat > /data/pillar/CLUSTER_MASTER_3.sls <<EOF
ROLES: "CLUSTER_MASTER_3"
IP: "${CLUSTER_MASTER_3}"
EOF

# 通过salt分发脚本和证书文件
cat > /data/salt/deploy_node.sls <<EOF
${CLUSTER_CERTS_DIR}/kube-proxy:
  file.recurse:
    - source: salt://files/certs/kube-proxy
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True
    - backup: minion
    - template: jinja
${CLUSTER_CERTS_DIR}/ca:
  file.recurse:
    - source: salt://files/certs/ca
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True
    - backup: minion
    - template: jinja
deploy_node:
  cmd.run:
    - name: chmod +x ${CLUSTER_DIR}/k8s_deploy.sh && ${CLUSTER_DIR}/k8s_deploy.sh node
    - require:
      - file: ${CLUSTER_CERTS_DIR}/ca
      - file: ${CLUSTER_CERTS_DIR}/kube-proxy
    - unless: systemctl status kubelet
EOF
cat > /data/salt/deploy_master.sls <<EOF
${CLUSTER_DIR}:
  file.recurse:
    - source: salt://files
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True
    - backup: minion
    - template: jinja
deploy_master:
  cmd.run:
    - name: chmod +x ${CLUSTER_DIR}/k8s_deploy.sh && ${CLUSTER_DIR}/k8s_deploy.sh master
    - require:
      - file: ${CLUSTER_DIR}
    - unless: systemctl status kubelet
EOF

# 通过salt执行部署脚本
