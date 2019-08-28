FROM 192.168.10.20:5000/centos7.6.1810

MAINTAINER liuldgm@gmail.com

RUN yum clean all && \
    yum install -y https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm && \
    yum clean expire-cache && \
    yum install -y salt-master salt-ssh salt-api && \
    yum install -y openssh-clients && \
    yum clean all

CMD ["/usr/sbin/init"]
