pre:
  cmd.run:
    - name: . /tmp/pre.sh
    - require:
      - file: /tmp/pre.sh
      - file: /etc/systemd/journald.conf
      - file: /etc/sysctl.d/kubernetes.conf

/tmp/pre.sh:
  file.managed:
    - source: salt://deploy/k8s/pre/pre.sh
    - user: root
    - group: root
    - mode: 655

/etc/systemd/journald.conf:
  file.managed:
    - source: salt://deploy/k8s/pre/journald.conf
    - user: root
    - group: root
    - mode: 644

/etc/sysctl.d/kubernetes.conf:
  file.managed:
    - source: salt://deploy/k8s/pre/kubernetes.conf
    - user: root
    - group: root
    - mode: 644
