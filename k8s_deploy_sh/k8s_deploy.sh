#!/bin/bash
# time: 2019/08/26
# author: liuld
# description: kubernetes deploy script

# 获取变量信息（当前通过自定义，后面通过web页面获取)
CLUSTER_DIR="{{salt['config.get']('CLUSTER_DIR')}}"
CLUSTER_SVC_CIDR="{{salt['config.get']('CLUSTER_SVC_CIDR')}}"
CLUSTER_POD_CIDR="{{salt['config.get']('CLUSTER_POD_CIDR')}}"
CLUSTER_APISERVER_SVC_IP="{{salt['config.get']('CLUSTER_APISERVER_SVC_IP')}}"
CLUSTER_DNS_SVC_IP="{{salt['config.get']('CLUSTER_DNS_SVC_IP')}}"
CLUSTER_REGISTRY_URL="{{salt['config.get']('CLUSTER_REGISTRY_URL')}}"
CLUSTER_APISERVER_VIP="{{salt['config.get']('CLUSTER_APISERVER_VIP')}}"
CLUSTER_SVC_NODE_PORT_RANGE="{{salt['config.get']('CLUSTER_SVC_NODE_PORT_RANGE')}}"
CLUSTER_DNS_DOMAIN="{{salt['config.get']('CLUSTER_DNS_DOMAIN')}}"
CLUSTER_MANIFESTS_DIR="{{salt['config.get']('CLUSTER_MANIFESTS_DIR')}}"
CLUSTER_CONFIG_DIR="{{salt['config.get']('CLUSTER_CONFIG_DIR')}}"
CLUSTER_LOGS_DIR="{{salt['config.get']('CLUSTER_LOGS_DIR')}}"
CLUSTER_DATA_DIR="{{salt['config.get']('CLUSTER_DATA_DIR')}}"
CLUSTER_CERTS_DIR="{{salt['config.get']('CLUSTER_CERTS_DIR')}}"
CLUSTER_MASTER_1="{{salt['config.get']('CLUSTER_MASTER_1')}}"
CLUSTER_MASTER_2="{{salt['config.get']('CLUSTER_MASTER_2')}}"
CLUSTER_MASTER_3="{{salt['config.get']('CLUSTER_MASTER_3')}}"
CLUSTER_KUBELET_TOKEN="{{salt['config.get']('CLUSTER_KUBELET_TOKEN')}}"
CLUSTER_APISERVER_ENCRYPT_SECRET="{{salt['config.get']('CLUSTER_APISERVER_ENCRYPT_SECRET')}}"
CLUSTER_DOCKERBINFILE_URL="{{salt['config.get']('CLUSTER_DOCKERBINFILE_URL')}}"
CLUSTER_KUBELETBINFILE_URL="{{salt['config.get']('CLUSTER_KUBELETBINFILE_URL')}}"

mk_node_config(){
    mkdir -p ${CLUSTER_CONFIG_DIR}
    cat > ${CLUSTER_CONFIG_DIR}/kubelet-bootstrap.kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ${CLUSTER_CERTS_DIR}/ca/ca.pem
    server: ${CLUSTER_APISERVER_VIP}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet-bootstrap
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: kubelet-bootstrap
  user:
    token: ${CLUSTER_KUBELET_TOKEN}
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kubelet-config.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "{{salt['config.get']('IP')}}"
staticPodPath: ""
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
staticPodURL: ""
port: 10250
readOnlyPort: 0
rotateCertificates: true
serverTLSBootstrap: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "${CLUSTER_CERTS_DIR}/ca/ca.pem"
authorization:
  mode: Webhook
registryPullQPS: 0
registryBurst: 20
eventRecordQPS: 0
eventBurst: 20
enableDebuggingHandlers: true
enableContentionProfiling: true
healthzPort: 10248
healthzBindAddress: "{{salt['config.get']('IP')}}"
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: ""
systemCgroups: ""
cgroupRoot: ""
cgroupsPerQOS: true
cgroupDriver: cgroupfs
runtimeRequestTimeout: 10m
hairpinMode: promiscuous-bridge
maxPods: 220
podCIDR: "${CLUSTER_POD_CIDR}"
podPidsLimit: -1
resolvConf: /etc/resolv.conf
maxOpenFiles: 1000000
kubeAPIQPS: 1000
kubeAPIBurst: 2000
serializeImagePulls: false
evictionHard:
  memory.available:  "100Mi"
nodefs.available:  "10%"
nodefs.inodesFree: "5%"
imagefs.available: "15%"
evictionSoft: {}
enableControllerAttachDetach: true
failSwapOn: true
containerLogMaxSize: 20Mi
containerLogMaxFiles: 10
systemReserved: {}
kubeReserved: {}
systemReservedCgroup: ""
kubeReservedCgroup: ""
enforceNodeAllocatable: ["pods"]
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --allow-privileged=true \
  --bootstrap-kubeconfig=${CLUSTER_CONFIG_DIR}/kubelet-bootstrap.kubeconfig \
  --kubeconfig=/var/lib/kubelet/kubelet.kubeconfig \
  --config=${CLUSTER_CONFIG_DIR}/kubelet-config.yaml \
  --hostname-override={{salt['config.get']('IP')}} \
  --address={{salt['config.get']('IP')}} \
  --pod-manifest-path=${CLUSTER_MANIFESTS_DIR} \
  --pod-infra-container-image=${CLUSTER_REGISTRY_URL}/pause-amd64:3.1 \
  --image-pull-progress-deadline=15m \
  --logtostderr=true \
  --v=3
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-proxy-config.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  burst: 200
  kubeconfig: "${CLUSTER_CONFIG_DIR}/kube-proxy.kubeconfig"
  qps: 100
bindAddress: {{salt['config.get']('IP')}}
healthzBindAddress: {{salt['config.get']('IP')}}:10256
metricsBindAddress: {{salt['config.get']('IP')}}:10249
enableProfiling: true
clusterCIDR: ${CLUSTER_POD_CIDR}
hostnameOverride: {{salt['config.get']('IP')}}
mode: "ipvs"
portRange: ""
kubeProxyIPTablesConfiguration:
  masqueradeAll: false
kubeProxyIPVSConfiguration:
  scheduler: rr
  excludeCIDRs: []

EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-proxy.kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ${CLUSTER_CERTS_DIR}/ca/ca.pem
    server: ${CLUSTER_APISERVER_VIP}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kube-proxy
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: kube-proxy
  user:
    client-certificate: ${CLUSTER_CERTS_DIR}/kube-proxy/kube-proxy.pem
    client-key: ${CLUSTER_CERTS_DIR}/kube-proxy/kube-proxy-key.pem
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-proxy \
  --config=${CLUSTER_CONFIG_DIR}/kube-proxy-config.yaml \
  --logtostderr=true \
  --v=3
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

mk_master_config(){
    mkdir -p ${CLUSTER_CONFIG_DIR}
    cat > ${CLUSTER_CONFIG_DIR}/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
  # The following requests were manually identified as high-volume and low-risk, so drop them.
  - level: None
    resources:
      - group: ""
        resources:
          - endpoints
          - services
          - services/status
    users:
      - 'system:kube-proxy'
    verbs:
      - watch

  - level: None
    resources:
      - group: ""
        resources:
          - nodes
          - nodes/status
    userGroups:
      - 'system:nodes'
    verbs:
      - get

  - level: None
    namespaces:
      - kube-system
    resources:
      - group: ""
        resources:
          - endpoints
    users:
      - 'system:kube-controller-manager'
      - 'system:kube-scheduler'
      - 'system:serviceaccount:kube-system:endpoint-controller'
    verbs:
      - get
      - update

  - level: None
    resources:
      - group: ""
        resources:
          - namespaces
          - namespaces/status
          - namespaces/finalize
    users:
      - 'system:apiserver'
    verbs:
      - get

  # Don't log HPA fetching metrics.
  - level: None
    resources:
      - group: metrics.k8s.io
    users:
      - 'system:kube-controller-manager'
    verbs:
      - get
      - list

  # Don't log these read-only URLs.
  - level: None
    nonResourceURLs:
      - '/healthz*'
      - /version
      - '/swagger*'

  # Don't log events requests.
  - level: None
    resources:
      - group: ""
        resources:
          - events

  # node and pod status calls from nodes are high-volume and can be large, don't log responses for expected updates from nodes
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    users:
      - kubelet
      - 'system:node-problem-detector'
      - 'system:serviceaccount:kube-system:node-problem-detector'
    verbs:
      - update
      - patch

  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    userGroups:
      - 'system:nodes'
    verbs:
      - update
      - patch

  # deletecollection calls can be large, don't log responses for expected namespace deletions
  - level: Request
    omitStages:
      - RequestReceived
    users:
      - 'system:serviceaccount:kube-system:namespace-controller'
    verbs:
      - deletecollection

  # Secrets, ConfigMaps, and TokenReviews can contain sensitive & binary data,
  # so only log at the Metadata level.
  - level: Metadata
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps
      - group: authentication.k8s.io
        resources:
          - tokenreviews
  # Get repsonses can be large; skip them.
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
    verbs:
      - get
      - list
      - watch

  # Default level for known APIs
  - level: RequestResponse
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io

  # Default level for all other requests.
  - level: Metadata
    omitStages:
      - RequestReceived
EOF
    cat > ${CLUSTER_CONFIG_DIR}/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${CLUSTER_APISERVER_ENCRYPT_SECRET}
      - identity: {}
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-controller-manager.kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/certs/ca.pem
    server: ${CLUSTER_APISERVER_VIP}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: system:kube-controller-manager
current-context: system:kube-controller-manager
kind: Config
preferences: {}
users:
- name: system:kube-controller-manager
  user:
    client-certificate: /etc/kubernetes/certs/kube-controller-manager.pem
    client-key: /etc/kubernetes/certs/kube-controller-manager-key.pem
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-scheduler.kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/ca/ca.pem
    server: ${CLUSTER_APISERVER_VIP}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-scheduler
  name: system:kube-scheduler
current-context: system:kube-scheduler
kind: Config
preferences: {}
users:
- name: system:kube-scheduler
  user:
    client-certificate: /etc/kubernetes/certs/kube-scheduler.pem
    client-key: /etc/kubernetes/certs/kube-scheduler-key.pem
EOF
    cat > ${CLUSTER_CONFIG_DIR}/kube-scheduler.yaml <<EOF
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
bindTimeoutSeconds: 600
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
  qps: 100
enableContentionProfiling: false
enableProfiling: true
hardPodAffinitySymmetricWeight: 1
healthzBindAddress: 127.0.0.1:10251
leaderElection:
  leaderElect: true
metricsBindAddress: 127.0.0.1:10251
EOF
    echo "make master config file done..."
}

mk_master_manifests(){
    mkdir -p ${CLUSTER_MANIFESTS_DIR}
    cat > ${CLUSTER_MANIFESTS_DIR}/kube-etcd.json <<EOF
{
"apiVersion": "v1",
"kind": "Pod",
"metadata": {
  "name":"kube-etcd",
  "namespace": "kube-system",
  "annotations": {
    "scheduler.alpha.kubernetes.io/critical-pod": "",
    "seccomp.security.alpha.kubernetes.io/pod": "docker/default"
  }
},
"spec":{
"hostNetwork": true,
"containers":[
    {
    "name": "kube-etcd",
    "image": "${CLUSTER_REGISTRY_URL}/etcd:v3.3.13",
    "command": [
              "/bin/sh",
              "-c",
              "if [ -e /usr/local/bin/migrate-if-needed.sh ]; then /usr/local/bin/migrate-if-needed.sh 1>>/var/log/kube-etcd.log 2>&1; fi; exec /usr/local/bin/etcd --data-dir=/var/lib/etcd/data --name={{salt['config.get']('ROLES')}} --cert-file=/etc/kubernetes/certs/etcd.pem --key-file=/etc/kubernetes/certs/etcd-key.pem --trusted-ca-file=/etc/kubernetes/ca/ca.pem --peer-cert-file=/etc/kubernetes/certs/etcd.pem --peer-key-file=/etc/kubernetes/certs/etcd-key.pem --peer-trusted-ca-file=/etc/kubernetes/ca/ca.pem --peer-client-cert-auth --client-cert-auth --listen-peer-urls=https://{{salt['config.get']('IP')}}:2380 --initial-advertise-peer-urls=https://{{salt['config.get']('IP')}}:2380 --listen-client-urls=https://{{salt['config.get']('IP')}}:2379,https://127.0.0.1:2379 --advertise-client-urls=https://{{salt['config.get']('IP')}}:2379 --initial-cluster-token=kube-etcd-cluster --initial-cluster=CLUSTER_MASTER_1=https://${CLUSTER_MASTER_1}:2380,CLUSTER_MASTER_2=https://${CLUSTER_MASTER_2}:2380,CLUSTER_MASTER_3=https://${CLUSTER_MASTER_3}:2380 --initial-cluster-state=new --auto-compaction-mode=periodic --auto-compaction-retention=1 --max-request-bytes=33554432 --quota-backend-bytes=6442450944 --heartbeat-interval=250 --election-timeout=2000 --snapshot-count=10000 --max-snapshots=5 --max-wals=5 1>>/var/log/kube-etcd.log 2>&1"
            ],
    "volumeMounts": [
      { "name": "etcd-certs",
        "mountPath": "/etc/kubernetes/certs",
        "readOnly": true
      },
      { "name": "ca-certs",
        "mountPath": "/etc/kubernetes/ca",
        "readOnly": true
      },
      { "name": "etcd-log",
        "mountPath": "/var/log/kube-etcd.log",
        "readOnly": false
      },
      { "name": "etcd-data",
        "mountPath": "/var/lib/etcd/data",
        "readOnly": false
      }
    ]
    }
],
"volumes":[
  { "name": "etcd-certs",
    "hostPath": {
        "path": "${CLUSTER_CERTS_DIR}/etcd"}
  },
  { "name": "ca-certs",
    "hostPath": {
        "path": "${CLUSTER_CERTS_DIR}/ca"}
  },
  { "name": "etcd-log",
    "hostPath": {
        "path": "${CLUSTER_LOGS_DIR}/etcd.log",
        "type": "FileOrCreate"}
  },
  { "name": "etcd-data",
    "hostPath": {
        "path": "${CLUSTER_DATA_DIR}/etcd",
        "type": "DirectoryOrCreate"}
  }
]
}}
EOF
    cat > ${CLUSTER_MANIFESTS_DIR}/kube-apiserver.json <<EOF
{
"apiVersion": "v1",
"kind": "Pod",
"metadata": {
  "name":"kube-apiserver",
  "namespace": "kube-system",
  "annotations": {
    "scheduler.alpha.kubernetes.io/critical-pod": "",
    "seccomp.security.alpha.kubernetes.io/pod": "docker/default"
  },
  "labels": {
    "tier": "control-plane",
    "component": "kube-apiserver"
  }
},
"spec":{
"hostNetwork": true,
"containers":[
    {
    "name": "kube-apiserver",
    "image": "${CLUSTER_REGISTRY_URL}/kube-apiserver:v1.14.5",
    "resources": {
      "requests": {
        "cpu": "250m"
      }
    },
    "command": [
                 "/bin/sh",
                 "-c",
                 "exec /usr/local/bin/kube-apiserver --advertise-address={{salt['config.get']('IP')}} --default-not-ready-toleration-seconds=360 --default-unreachable-toleration-seconds=360 --feature-gates=DynamicAuditing=true --max-mutating-requests-inflight=2000 --max-requests-inflight=4000 --default-watch-cache-size=200 --delete-collection-workers=2 --encryption-provider-config=/etc/kubernetes/encryption-config.yaml --etcd-cafile=/etc/kubernetes/ca/ca.pem --etcd-certfile=/etc/kubernetes/certs/kubernetes.pem --etcd-keyfile=/etc/kubernetes/certs/kubernetes-key.pem --etcd-servers=https://${CLUSTER_MASTER_1}:2379,https://${CLUSTER_MASTER_2}:2379,https://${CLUSTER_MASTER_3}:2379 --bind-address={{salt['config.get']('IP')}} --secure-port=6443 --tls-cert-file=/etc/kubernetes/certs/kubernetes.pem --tls-private-key-file=/etc/kubernetes/certs/kubernetes-key.pem --insecure-port=0 --audit-dynamic-configuration --audit-log-maxage=15 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-truncate-enabled --audit-log-path=/var/log/kube-apiserver-audit.log --audit-policy-file=/etc/kubernetes/audit-policy.yaml --profiling --anonymous-auth=false --client-ca-file=/etc/kubernetes/ca/ca.pem --enable-bootstrap-token-auth --requestheader-allowed-names=\"aggregator\" --requestheader-client-ca-file=/etc/kubernetes/ca/ca.pem --requestheader-extra-headers-prefix=\"X-Remote-Extra-\" --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --service-account-key-file=/etc/kubernetes/ca/ca.pem --authorization-mode=Node,RBAC --runtime-config=api/all=true --enable-admission-plugins=NodeRestriction --allow-privileged=true --apiserver-count=3 --event-ttl=168h --kubelet-certificate-authority=/etc/kubernetes/ca/ca.pem --kubelet-client-certificate=/etc/kubernetes/certs/kubernetes.pem --kubelet-client-key=/etc/kubernetes/certs/kubernetes-key.pem --kubelet-https=true --kubelet-timeout=10s --proxy-client-cert-file=/etc/kubernetes/certs/proxy-client.pem --proxy-client-key-file=/etc/kubernetes/certs/proxy-client-key.pem --service-cluster-ip-range=${CLUSTER_SVC_CIDR} --service-node-port-range=${CLUSTER_SVC_NODE_PORT_RANGE} --logtostderr=true --v=3 1>>/var/log/kube-apiserver.log 2>&1"
               ],
    "volumeMounts": [
        { "name": "encryption-config",
        "mountPath": "/etc/kubernetes/encryption-config.yaml",
        "readOnly": true},
        { "name": "api-server-logfile",
        "mountPath": "/var/log/kube-apiserver.log",
        "readOnly": false},
        { "name": "auditlogfile",
        "mountPath": "/var/log/kube-apiserver-audit.log",
        "readOnly": false},
        { "name": "api-server-certs",
        "mountPath": "/etc/kubernetes/certs",
        "readOnly": true},
        { "name": "ca-cert",
        "mountPath": "/etc/kubernetes/ca",
        "readOnly": true},
        { "name": "audit-policy-config",
        "mountPath": "/etc/kubernetes/audit-policy.yaml",
        "readOnly": true}
      ]
    }
],
"volumes":[
  { "name": "encryption-config",
    "hostPath": {
        "path": "${CLUSTER_CONFIG_DIR}/encryption-config.yaml"}
  },
  { "name": "api-server-logfile",
    "hostPath": {
        "path": "${CLUSTER_LOGS_DIR}/kube-apiserver.log",
        "type": "FileOrCreate"}
  },
  { "name": "auditlogfile",
    "hostPath": {
        "path": "${CLUSTER_LOGS_DIR}/kube-apiserver-audit.log",
        "type": "FileOrCreate"}
  },
  { "name": "api-server-certs",
    "hostPath": {
        "path": "${CLUSTER_CERTS_DIR}/kube-apiserver"}
  },
  { "name": "ca-cert",
    "hostPath": {
        "path": "${CLUSTER_CERTS_DIR}/ca"}
  },
  { "name": "audit-policy-config",
    "hostPath": {
        "path": "${CLUSTER_CONFIG_DIR}/audit-policy.yaml"}
  }
]
}}
EOF
    cat > ${CLUSTER_MANIFESTS_DIR}/kube-controller-manager.json <<EOF
{
"apiVersion": "v1",
"kind": "Pod",
"metadata": {
  "name":"kube-controller-manager",
  "namespace": "kube-system",
  "annotations": {
    "scheduler.alpha.kubernetes.io/critical-pod": "",
    "seccomp.security.alpha.kubernetes.io/pod": "docker/default"
  },
  "labels": {
    "tier": "control-plane",
    "component": "kube-controller-manager"
  }
},
"spec":{
"hostNetwork": true,
"containers":[
    {
    "name": "kube-controller-manager",
    "image": "${CLUSTER_REGISTRY_URL}/kube-controller-manager:v1.14.5",
    "command": [
                 "/bin/sh",
                 "-c",
                 "exec /usr/local/bin/kube-controller-manager --profiling --allocate-node-cidrs=true --cluster-cidr=${CLUSTER_POD_CIDR} --cluster-name=kubernetes --controllers=*,bootstrapsigner,tokencleaner --kube-api-qps=1000 --kube-api-burst=2000 --leader-elect --use-service-account-credentials --concurrent-service-syncs=2 --bind-address={{salt['config.get']('IP')}} --address=127.0.0.1 --secure-port=10252 --tls-cert-file=/etc/kubernetes/certs/kube-controller-manager.pem --tls-private-key-file=/etc/kubernetes/certs/kube-controller-manager-key.pem --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig --client-ca-file=/etc/kubernetes/certs/ca.pem --requestheader-allowed-names=\"\" --requestheader-client-ca-file=/etc/kubernetes/certs/ca.pem --requestheader-extra-headers-prefix=\"X-Remote-Extra-\" --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig --cluster-signing-cert-file=/etc/kubernetes/certs/ca.pem --cluster-signing-key-file=/etc/kubernetes/certs/ca-key.pem --experimental-cluster-signing-duration=876000h --horizontal-pod-autoscaler-sync-period=10s --concurrent-deployment-syncs=10 --concurrent-gc-syncs=30 --node-cidr-mask-size=24 --service-cluster-ip-range=${CLUSTER_SVC_CIDR} --pod-eviction-timeout=6m --terminated-pod-gc-threshold=10000 --root-ca-file=/etc/kubernetes/certs/ca.pem --service-account-private-key-file=/etc/kubernetes/certs/ca-key.pem --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig --v=3 1>>/var/log/kube-controller-manager.log 2>&1"
               ],
    "volumeMounts": [
        { "name": "certs",
        "mountPath": "/etc/kubernetes/certs",
        "readOnly": true},
        { "name": "logfile",
        "mountPath": "/var/log/kube-controller-manager.log",
        "readOnly": false},
        { "name": "config",
        "mountPath": "/etc/kubernetes/kube-controller-manager.kubeconfig",
        "readOnly": true}
      ]
    }
],
"volumes":[
  { "name": "certs",
    "hostPath": {
        "path": "${CLUSTER_CERTS_DIR}/kube-controller-manager"}
  },
  { "name": "logfile",
    "hostPath": {
        "path": "${CLUSTER_LOGS_DIR}/kube-controller-manager.log",
        "type": "FileOrCreate"}
  },
  { "name": "config",
    "hostPath": {
        "path": "${CLUSTER_CONFIG_DIR}/kube-controller-manager.kubeconfig"}
  }
]
}}
EOF
    cat > ${CLUSTER_MANIFESTS_DIR}/kube-scheduler.json <<EOF
{
"apiVersion": "v1",
"kind": "Pod",
"metadata": {
  "name":"kube-scheduler",
  "namespace": "kube-system",
  "annotations": {
    "scheduler.alpha.kubernetes.io/critical-pod": "",
    "seccomp.security.alpha.kubernetes.io/pod": "docker/default"
  },
  "labels": {
    "tier": "control-plane",
    "component": "kube-scheduler"
  }
},
"spec":{
"hostNetwork": true,
"containers":[
    {
    "name": "kube-scheduler",
    "image": "${CLUSTER_REGISTRY_URL}/kube-scheduler:v1.14.5",
    "command": [
                 "/bin/sh",
                 "-c",
                 "exec /usr/local/bin/kube-scheduler --config=/etc/kubernetes/kube-scheduler.yaml --bind-address={{salt['config.get']('IP')}} --secure-port=10259 --port=0 --tls-cert-file=/etc/kubernetes/certs/kube-scheduler.pem --tls-private-key-file=/etc/kubernetes/certs/kube-scheduler-key.pem --authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig --client-ca-file=/etc/kubernetes/ca/ca.pem --requestheader-allowed-names=\"\" --requestheader-client-ca-file=/etc/kubernetes/ca/ca.pem --requestheader-extra-headers-prefix=\"X-Remote-Extra-\" --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig --v=3 1>>/var/log/kube-scheduler.log 2>&1"
               ],
    "livenessProbe": {
      "httpGet": {
        "host": "127.0.0.1",
        "port": 10251,
        "path": "/healthz"
      },
      "initialDelaySeconds": 15,
      "timeoutSeconds": 15
    },
    "volumeMounts": [
        {
          "name": "logfile",
          "mountPath": "/var/log/kube-scheduler.log",
          "readOnly": false
        },
        {
          "name": "certs",
          "mountPath": "/etc/kubernetes/certs",
          "readOnly": true
        },
        {
          "name": "ca-certs",
          "mountPath": "/etc/kubernetes/ca",
          "readOnly": true
        },
        {
          "name": "kubeconfig",
          "mountPath": "/etc/kubernetes/kube-scheduler.kubeconfig",
          "readOnly": true
        },
        {
          "name": "config",
          "mountPath": "/etc/kubernetes/kube-scheduler.yaml",
          "readOnly": true
        }
      ]
    }
],
"volumes":[
  {
    "name": "certs",
    "hostPath": {"path": "${CLUSTER_CERTS_DIR}/kube-scheduler"}
  },
  {
    "name": "ca-certs",
    "hostPath": {"path": "${CLUSTER_CERTS_DIR}/ca"}
  },
  {
    "name": "kubeconfig",
    "hostPath": {"path": "${CLUSTER_CONFIG_DIR}/kube-scheduler.kubeconfig"}
  },
  {
    "name": "config",
    "hostPath": {"path": "${CLUSTER_CONFIG_DIR}/kube-scheduler.yaml"}
  },
  {
    "name": "logfile",
    "hostPath": {"path": "${CLUSTER_LOGS_DIR}/kube-scheduler.log", "type": "FileOrCreate"}
  }
]
}}
EOF
    cat > ${CLUSTER_MANIFESTS_DIR}/kube-api-proxy.json <<EOF
{
"apiVersion": "v1",
"kind": "Pod",
"metadata": {
  "name":"kube-api-proxy",
  "namespace": "kube-system",
  "annotations": {
    "seccomp.security.alpha.kubernetes.io/pod": "docker/default"
  },
  "labels": {
    "tier": "control-plane",
    "component": "kube-api-proxy"
  }
},
"spec":{
"priorityClass": "system-node-critical",
"hostNetwork": true,
"containers":[
    {
    "name": "kube-api-proxy",
    "image": "${CLUSTER_REGISTRY_URL}/kube-api-proxy:v1.14.5",
    "env": [
      {
        "name": "CLUSTER_MASTER_1",
        "value": "${CLUSTER_MASTER_1}"
      },
      {
        "name": "CLUSTER_MASTER_2",
        "value": "${CLUSTER_MASTER_2}"
      },
      {
        "name": "CLUSTER_MASTER_3",
        "value": "${CLUSTER_MASTER_3}"
      }
    ],
    "command": ["/usr/bin/endpoint.sh"],
    "volumeMounts": [
        {
          "name": "logfile",
          "mountPath": "/var/log/nginx",
          "readOnly": false
        }
      ]
    }
],
"volumes":[
  {
    "name": "logfile",
    "hostPath": {"path": "${CLUSTER_LOGS_DIR}/nginx", "type": "DirectoryOrCreate"}
  }
]
}}
EOF
    echo "make master manifests file done..."
}

deploy_docker(){
    if [[ $(systemctl status docker | grep "Active: active" | wc -l) -eq 0 ]];then
        cd /tmp/ && wget ${CLUSTER_DOCKERBINFILE_URL} -O docker.tgz && tar zxf docker.tgz -C /usr/local/bin/
        /usr/local/bin/mk-docker-certs.sh server
        if [[ $? != 0 ]];then
            echo "create docker cert file error"
            exit 1
        fi
        cat > /etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network-online.target

[Service]
Delegate=yes
Type=notify
KillMode=process
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
EnvironmentFile=-/var/flannel/docker
ExecStartPre=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /var/flannel/docker
ExecStart=/usr/local/bin/dockerd --live-restore --insecure-registry ${CLUSTER_REGISTRY_URL} --tlsverify --tlscacert=/data/k8s-data/docker/certs/ca.pem --tlscert=/data/k8s-data/docker/certs/server-cert.pem --tlskey=/data/k8s-data/docker/certs/server-key.pem -H unix:///var/run/docker.sock -H 0.0.0.0:2376 \$DOCKER_NETWORK_OPTIONS
#MountFlags=share
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
#timeoutStartSec=0
ExecReload=/bin/kill -s HUP \$MAINPID

[Install]
WantedBy=multi-user.target

EOF
        systemctl daemon-reload && systemctl enable docker && systemctl start docker
        if [[ $(systemctl status docker | grep "Active: active" | wc -l) -gt 0 ]];then
            echo "docker service is running"
        else
            echo "docker service is not running"
            exit 1
        fi
    else
        echo "the docker service is running"
    fi
}

deploy_kubelet(){
    if [[ -z "$(systemctl status kubelet | grep 'Active: active')" ]];then
        cd /tmp/ && wget ${CLUSTER_KUBELETBINFILE_URL} -O kubelet.tgz && tar -zxf kubelet.tgz -C /usr/local/bin/
        if [[ $? -ne 0 ]];then
            echo "download kubelet bin file error"
            exit 1
        fi
        mk_node_config
        if [[ -e ${CLUSTER_CONFIG_DIR}/kubelet.service ]];then
            \cp -f ${CLUSTER_CONFIG_DIR}/kubelet.service /etc/systemd/system/
            \cp -f ${CLUSTER_CONFIG_DIR}/kube-proxy.service /etc/systemd/system/
            systemctl daemon-reload && systemctl enable kubelet && systemctl enable kube-proxy
            if [[ -e ${CLUSTER_CERTS_DIR}/ca/ca.pem ]];then
                systemctl start kubelet
                systemctl start kube-proxy
                echo "kubelet deploy done..."
            else
                echo "kubelet service is not running!"
                exit 1
            fi
        else
            echo "the file ${CLUSTER_CONFIG_DIR}/kubelet.service is not exist!"
            exit 1
        fi
    else
        echo "kubelet service is running..."
    fi
}

if [[ $# != 1 ]] ; then
    echo "USAGE: $0 [master|node]"
    exit 1;
else
    case $1 in
        "master")
        deploy_docker
        mk_master_config
        mk_master_manifests
        deploy_kubelet
        ;;
        "node")
        deploy_docker
        deploy_kubelet
        ;;
        *)
        echo "USAGE: $0 [master|node]"
        ;;
    esac
fi
