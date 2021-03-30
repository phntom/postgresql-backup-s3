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

FILENAME=$(ls '*_*.sql')

echo "Replacing LOCALE en_US.UTF-8 with en_US.utf8 in $FILENAME"

sed -i"" "s/ LOCALE = 'en_US.UTF-8'/en_US.utf8/" $FILENAME

echo "Connecting $PGHOST:$PGPORT..."

touch empty
psql $POSTGRES_EXTRA_OPTS -f empty

echo "Extracted $FILENAME, Restoring..."

psql $POSTGRES_EXTRA_OPTS -f $FILENAME || sleep 9999

if [ -f "zzz_roles.sql" ]; then
  echo "Restoring roles..."
  psql $POSTGRES_EXTRA_OPTS -f zzz_roles.sql
fi

echo Done!
