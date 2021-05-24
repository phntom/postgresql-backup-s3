# docker build -t phntom/postgresql-backup-s3:1.0.14 --pull . && docker push phntom/postgresql-backup-s3:1.0.14

FROM alpine:3.10

WORKDIR /root

RUN apk update \
	&& apk add --no-cache \
	coreutils \
	postgresql-client=~11.11-r0 \
	python3 py3-pip \
	curl \
	p7zip

RUN pip3 install --upgrade pip
RUN pip3 install awscli
RUN curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron \
	&& chmod u+x /usr/local/bin/go-cron

ENV POSTGRES_DATABASE **None**
ENV PGHOST **None**
ENV PGPORT 5432
ENV PGUSER **None**
ENV PGPASSWORD **None**
ENV POSTGRES_EXTRA_OPTS ''
ENV AWS_ACCESS_KEY_ID **None**
ENV AWS_SECRET_ACCESS_KEY **None**
ENV AWS_DEFAULT_REGION us-east-1
ENV S3_BUCKET **None**
ENV S3_PREFIX 'backup'
ENV S3_ENDPOINT **None**
ENV S3_S3V4 no
ENV SCHEDULE **None**
ENV ENCRYPTION_PASSWORD **None**
ENV DELETE_OLDER_THAN **None**
ENV PATH=/root:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY run.sh backup.sh restore.sh /root/

CMD ["sh", "run.sh"]
