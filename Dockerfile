# docker build -t phntom/postgresql-backup-s3:1.0.22 --pull . && docker push phntom/postgresql-backup-s3:1.0.22

#FROM alpine:3.17
# for pg_dump 15.7
# docker buildx build --platform linux/amd64 -t phntom/postgresql-backup-s3:15.7.27 --push .

#FROM alpine:3.19
# for pg_dump 16.3
# docker buildx build --platform linux/amd64 -t phntom/postgresql-backup-s3:16.3.27 --push  .

FROM alpine:3.22
# for pg_dump 17.5
# docker buildx build --platform linux/amd64 -t phntom/postgresql-backup-s3:17.5.27 --push  .


WORKDIR /root

RUN apk update \
	&& apk add --no-cache \
	coreutils \
	postgresql-client \
	curl \
	p7zip \
    aws-cli && \
    curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron \
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
ENV DEBUG=no

COPY --chmod=0755 run.sh backup.sh restore.sh cleanup.sh common.sh /root/

CMD ["sh", "run.sh"]
