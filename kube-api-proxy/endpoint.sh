#!/bin/bash

cat > /etc/nginx/nginx.conf << EOF
worker_processes auto;
error_log  /var/log/nginx/error.log warn;
daemon off;

events {
    worker_connections  1024;
}

stream {
    upstream backend {
        hash \$remote_addr consistent;
        server ${CLUSTER_MASTER_1}:6443        max_fails=3 fail_timeout=30s;
        server ${CLUSTER_MASTER_2}:6443        max_fails=3 fail_timeout=30s;
        server ${CLUSTER_MASTER_3}:6443        max_fails=3 fail_timeout=30s;
    }
    log_format proxy '\$remote_addr - [\$time_local] '
                     '\$protocol \$status \$bytes_sent \$bytes_received '
                     '\$session_time "\$upstream_addr" '
                     '"\$upstream_bytes_sent" "\$upstream_bytes_received" "\$upstream_connect_time" '
                     '\$remote_addr:\$remote_port \$server_addr:\$server_port';

    server {
        listen *:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
        access_log  /var/log/nginx/access.log  proxy;
    }
}
EOF
nginx
