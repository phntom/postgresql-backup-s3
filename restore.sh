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

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
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

echo "Fetching latest backup from s3://${S3_BUCKET}..."

LAST_KEY=$(aws s3api $AWS_ARGS list-objects-v2 --bucket "$S3_BUCKET" --query 'sort_by(Contents, &LastModified)[-1].Key' --output=text)

echo "Found $LAST_KEY, Downloading..."

mkdir output || exit 3
cd output

aws $AWS_ARGS s3 cp "s3://${S3_BUCKET}/${LAST_KEY}" . || exit 2

FILENAME=$(ls)

echo "Downloaded ${FILENAME}"

ls -lah

echo "7z e -p... $FILENAME"
7z e "$P7Z_PASS" "$FILENAME" || exit 5

rm -v "$FILENAME"

FILENAME=$(ls)

echo "Extracted $FILENAME, Restoring..."

psql $POSTGRES_HOST_OPTS -f $FILENAME || exit 6

echo "SQL restore finished"

sleep 9999
