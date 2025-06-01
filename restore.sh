#!/usr/bin/env sh

# Exit on error and pipe failure. These are important to set early.
set -e
set -o pipefail

# Source common environment variables and configurations
# shellcheck source=./common.sh
. ./common.sh "restore"

# Specific setup for restore.sh
echo "Fetching latest backup from s3://${S3_BUCKET}..."

LAST_KEY=$(aws s3api $AWS_ARGS list-objects-v2 --bucket "$S3_BUCKET" --query 'sort_by(Contents, &LastModified)[-1].Key' --output=text | tail -n1)

echo "Found $LAST_KEY, Downloading..."

mkdir output || { echo "ERROR: Failed to create output directory"; exit 3; }
cd output

aws $AWS_ARGS s3 cp "s3://${S3_BUCKET}/${LAST_KEY}" . || { echo "ERROR: Failed to download backup from S3"; exit 2; }

FILENAME=$(basename "$LAST_KEY")

echo "Downloaded ${FILENAME}"

ls -lah

echo "7z e -p... $FILENAME"
7z e "$P7Z_PASS" "$FILENAME" || { echo "ERROR: Failed to extract backup"; exit 5; }

rm -v "$FILENAME"

echo "Connecting $PGHOST:$PGPORT..."
touch empty
psql $POSTGRES_EXTRA_OPTS -f empty || { echo "ERROR: Failed to connect to PostgreSQL"; exit 7; }
echo "Connected!"

ls -lah ./*

if [ -f "roles.sql" ]; then
  echo "Creating roles..."
  grep -vE "^(CREATE|ALTER) ROLE ${PGUSER}[; ]" roles.sql > roles1.sql
  grep -vE "^ALTER ROLE " roles1.sql > roles2.sql
  psql $POSTGRES_EXTRA_OPTS -f roles2.sql || { echo "ERROR: Failed to apply roles2.sql"; exit 1; }
fi


for FILENAME_LOOP in ./*_*.sql; do

  [ -f "$FILENAME_LOOP" ] || continue

  echo "Replacing LOCALE with LC_COLLATE for $FILENAME_LOOP"
  sed -i"" "s/ LOCALE = 'en_US.UTF-8';$/ LC_COLLATE = 'en_US.UTF-8';/" "$FILENAME_LOOP"

  echo "Filtering out role creation for $FILENAME_LOOP..."
  grep -vE "^(CREATE|ALTER) ROLE " "$FILENAME_LOOP" > "${FILENAME_LOOP}.1"
  mv -v "${FILENAME_LOOP}.1" "$FILENAME_LOOP"

  psql $POSTGRES_EXTRA_OPTS -f "$FILENAME_LOOP" || { echo "ERROR: Failed to apply $FILENAME_LOOP"; exit 1; }

done

FAIL_ANY=0
for FILENAME_LOOP in ./*_*.tar; do

  [ -f "$FILENAME_LOOP" ] || continue

  for ATTEMPT in 1 2 3; do
    echo "[attempt $ATTEMPT/3] pg_restore --clean --if-exists --create $FILENAME_LOOP -d postgres"
    FAIL=0
    pg_restore --clean --if-exists --create "$FILENAME_LOOP" -d postgres || { echo "ERROR: pg_restore failed for $FILENAME_LOOP"; FAIL=1; }
    if [ $FAIL -eq 0 ]; then
      break
    fi
  done

  if [ $FAIL -eq 1 ]; then
    echo "No more attempts to restore $FILENAME_LOOP will be made :("
    FAIL_ANY="$FILENAME_LOOP"
  fi

done

if [ "$FAIL_ANY" != "0" ]; then # Check if FAIL_ANY is not "0" (meaning a file failed)
  echo "$FAIL_ANY failed to restore, aborting"
  exit 7 # Use a specific exit code for this failure
fi


if [ -f "roles.sql" ]; then
  echo "Altering roles (adding passwords)..."
  grep -vE "^CREATE ROLE " roles1.sql > roles2.sql
  psql $POSTGRES_EXTRA_OPTS -f roles2.sql || { echo "ERROR: Failed to apply roles2.sql for altering roles"; exit 1; }
fi

echo Done!
