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

if [ "${PGHOST}" = "**None**" ]; then
  echo "You need to set the PGHOST environment variable."
  exit 1
fi

if [ "${PGUSER}" = "**None**" ]; then
  echo "You need to set the PGUSER environment variable."
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

DATE_NOW=$(date +"%Y%m%dT%H%M%SZ")
SRC_FILE=${POSTGRES_DATABASE}_${DATE_NOW}.sql
DST_FILE=${SRC_FILE}.7z
REMOTE_PATH=$(date +"%Y-%m/%d/%H")/${DST_FILE}

echo "$DATE_NOW Dumping ${POSTGRES_DATABASE} db ${PGHOST} to s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

if [ "${POSTGRES_DATABASE}" == "all" ]; then
  pg_dumpall --no-acl | 7z a -si"${SRC_FILE}" "$P7Z_PASS" "$DST_FILE"
else
  pg_dump "$POSTGRES_DATABASE" | 7z a -si"${SRC_FILE}" "$P7Z_PASS" "$DST_FILE"
fi

pg_dumpall --globals-only \
  | 7z a -si"zzz_globals.sql" "$P7Z_PASS" "$DST_FILE"

pg_dumpall --roles-only \
  | 7z a -si"zzz_roles.sql" "$P7Z_PASS" "$DST_FILE"

aws $AWS_ARGS s3 cp "$DST_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

echo "$(date +"%Y%m%dT%H%M%SZ") Done"
