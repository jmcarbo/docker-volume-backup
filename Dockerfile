FROM ubuntu
MAINTAINER Joan Marc Carbo Arnau <jmcarbo@gmail.com>

RUN apt-get update && \
    apt-get install -y mysql-client curl && \
    curl https://dl.minio.io/client/mc/release/linux-amd64/mc > /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc && \ 
    mkdir /backup

ENV CRON_TIME="0 0 * * *" \
    MYSQL_DB="--all-databases"
ADD run.sh /run.sh
VOLUME ["/backup"]

CMD ["/run.sh"]
