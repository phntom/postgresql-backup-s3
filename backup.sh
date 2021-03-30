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
DST_FILE=${DATE_NOW}.7z
REMOTE_PATH=$(date +"%Y-%m/%d/%H")/${DST_FILE}

echo "$DATE_NOW Dumping ${POSTGRES_DATABASE} db ${PGHOST} to s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

if [ "${POSTGRES_DATABASE}" == "all" ]; then
  SRC_FILE=all_${DATE_NOW}.sql
  pg_dumpall --clean --no-acl | 7z a -si"${SRC_FILE}" "$P7Z_PASS" "$DST_FILE"
else
  for DB_NAME in $POSTGRES_DATABASE; do
    SRC_FILE=${DB_NAME}_${DATE_NOW}.sql
    pg_dump --clean "$DB_NAME" | 7z a -si"${SRC_FILE}" "$P7Z_PASS" "$DST_FILE"
  done
fi

pg_dumpall --globals-only \
  | 7z a -si"globals.sql" "$P7Z_PASS" "$DST_FILE"

pg_dumpall --roles-only \
  | 7z a -si"roles.sql" "$P7Z_PASS" "$DST_FILE"

aws $AWS_ARGS s3 cp "$DST_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

echo "$(date +"%Y%m%dT%H%M%SZ") Done"
