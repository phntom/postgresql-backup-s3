#! /bin/sh

set -e
set -o pipefail

if [ "${AWS_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the AWS_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${AWS_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the AWS_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${PGPASSWORD}" = "**None**" ]; then
  echo "You need to set the PGPASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "${S3_ENDPOINT}" == "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
  P7Z_PASS="-p${ENCRYPTION_PASSWORD}"
else
  P7Z_PASS=""
fi

POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"


DATE_NOW=$(date +"%Y%m%dT%H%M%SZ")
SRC_FILE=${POSTGRES_DATABASE}_${DATE_NOW}.sql
DST_FILE=${SRC_FILE}.7z
REMOTE_PATH=$(date +"%Y-%m/%d/%H")/${DST_FILE}

echo "$DATE_NOW Dumping ${POSTGRES_DATABASE} db ${POSTGRES_HOST} to s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

if [ "${POSTGRES_DATABASE}" == "all" ]; then
  pg_dumpall $POSTGRES_HOST_OPTS \
  | 7z a -si"${SRC_FILE}" "$P7Z_PASS" $DST_FILE
else
  pg_dump $POSTGRES_HOST_OPTS $POSTGRES_DATABASE \
  | 7z a -si"${SRC_FILE}" "$P7Z_PASS" $DST_FILE
fi

aws $AWS_ARGS s3 cp "$DST_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

echo "$(date +"%Y%m%dT%H%M%SZ") Done"
