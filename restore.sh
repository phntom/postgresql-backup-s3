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

echo "Connecting $PGHOST:$PGPORT..."
touch empty
psql $POSTGRES_EXTRA_OPTS -f empty || exit 7
echo "Connected!"

ls -lah ./*

for FILENAME in ./*_*.sql; do

  [ -f "$FILENAME" ] || continue

  echo "Replacing LOCALE with LC_COLLATE for $FILENAME"
  sed -i"" "s/ LOCALE = 'en_US.UTF-8';$/ LC_COLLATE = 'en_US.UTF-8';/" $FILENAME

  echo "Filtering out role creation for $FILENAME..."
  grep -vE "^(CREATE|ALTER) ROLE " "$FILENAME" > "${FILENAME}.1"
  mv -v "${FILENAME}.1" "$FILENAME"

  psql $POSTGRES_EXTRA_OPTS -f "$FILENAME" || sleep 999

done

FAIL_ANY=0
for FILENAME in ./*_*.tar; do

  [ -f "$FILENAME" ] || continue

  for ATTEMPT in 1 2 3; do
    echo "[attempt $ATTEMPT/3] pg_restore --clean --if-exists --create $FILENAME -d postgres"
    FAIL=0
    pg_restore --clean --if-exists --create "$FILENAME" -d postgres && break
    FAIL=1
  done

  if [ $FAIL -eq 1 ]; then
    echo "no more attempts to restore $FILENAME will be made :("
    FAIL_ANY="$FILENAME"
  fi

done

if [ -z "$FAIL_ANY" ]; then
  echo "$FILENAME failed to restore, aborting"
  sleep 30
  exit 7
fi


if [ -f "roles.sql" ]; then
  echo "Filtering out ${PGUSER} role creation..."
  grep -vE "^(CREATE|ALTER) ROLE ${PGUSER}[; ]" roles.sql > roles1.sql
  mv -v roles1.sql roles.sql

  echo "Restoring roles..."
  psql $POSTGRES_EXTRA_OPTS -f roles.sql || sleep 9999
fi

echo Done!
