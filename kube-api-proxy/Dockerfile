FROM registry.cqt.com:5000/nginx:1.17.2

COPY endpoint.sh /usr/bin/

RUN chmod +x /usr/bin/endpoint.sh

CMD ["/usr/bin/endpoint.sh"]
