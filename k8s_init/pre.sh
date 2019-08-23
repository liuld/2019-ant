#!/bin/bash
# date: 2019-08-07
# author: linchqd
# version: v1.0
# k8s node system init scripts

# requirements pkg
yum install -y epel-release && yum install -y conntrack-tools ntpdate ntp ipvsadm ipset jq iptables curl sysstat libseccomp wget telnet bind-utils

# disable firewalld & selinux

if [[ -z $(grep "SELINUX=disabled" /etc/selinux/config) ]];then
    setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    systemctl stop firewalld && systemctl disable firewalld
    iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat && iptables -P FORWARD ACCEPT
fi

# sync time
timedatectl set-timezone Asia/Shanghai && timedatectl set-local-rtc 0 && systemctl restart rsyslog && systemctl restart crond && ntpdate cn.pool.ntp.org

# shutdown swap
if [[ -z $(grep -E "^#.*?swap" /etc/fstab) ]];then
    swapoff -a && sed -i '/ swap /s/^\(.*\)$/#\1/g' /etc/fstab
fi

#load modules
modprobe ip_vs_rr && modprobe br_netfilter
sysctl -p /etc/sysctl.d/kubernetes.conf

# disabled service
systemctl stop postfix && systemctl disable postfix
systemctl enable rsyslog
systemctl enable crond
systemctl enable systemd-journald && systemctl restart systemd-journald
