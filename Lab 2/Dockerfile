FROM alpine:3.20

COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

VOLUME /shared

CMD ["/usr/local/bin/script.sh"]
