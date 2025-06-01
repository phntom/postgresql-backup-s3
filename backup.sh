#!/usr/bin/env sh

# Exit on error and pipe failure. These are important to set early.
set -e
set -o pipefail

# Source common environment variables and configurations
# shellcheck source=./common.sh
. ./common.sh "backup"

# Specific setup for backup.sh
DATE_NOW=$(date +"%Y%m%dT%H%M%SZ")
DST_FILE=${DATE_NOW}.7z
REMOTE_PATH=$(date +"%Y-%m/%d/%H")/${DST_FILE}

echo "$DATE_NOW Dumping ${POSTGRES_DATABASE} db ${PGHOST} to s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

if [ "${POSTGRES_DATABASE}" = "all" ]; then
  echo "Dumping all databases..."
  SRC_FILE_NAME_IN_ARCHIVE="all_databases_${DATE_NOW}.sql"
  pg_dumpall --clean --no-acl | 7z a -si"${SRC_FILE_NAME_IN_ARCHIVE}" "$P7Z_PASS" "$DST_FILE"
else
  echo "Dumping specified databases: ${POSTGRES_DATABASE}"
  # Use read to split POSTGRES_DATABASE into an array, using a comma as the delimiter
  IFS=',' read -r -a DB_ARRAY <<< "$POSTGRES_DATABASE"

  for DB_NAME in "${DB_ARRAY[@]}"; do
    # Remove leading/trailing whitespace from DB_NAME, just in case
    DB_NAME_TRIMMED=$(echo "$DB_NAME" | xargs)
    if [ -z "$DB_NAME_TRIMMED" ]; then
      continue # Skip empty names if any result from splitting
    fi

    echo "Dumping database: '${DB_NAME_TRIMMED}'"
    # Define how the dump of this specific DB will be named inside the archive
    SRC_FILE_NAME_IN_ARCHIVE="${DB_NAME_TRIMMED}_${DATE_NOW}.tar"

    # pg_dump command for individual database
    # Using -Ft for tar format, which is suitable for individual database dumps
    # The output of pg_dump is piped to 7z
    pg_dump -Ft --encoding=UTF-8 --serializable-deferrable --clean "$DB_NAME_TRIMMED" | \
      7z a -si"${SRC_FILE_NAME_IN_ARCHIVE}" "$P7Z_PASS" "$DST_FILE"
  done
fi

# Add global objects and roles to the same archive
# It's important that these are added after the main database dumps
# The `|| true` is to prevent script failure if pg_dumpall has minor issues or empty output for these specific dumps
echo "Dumping global objects..."
pg_dumpall --globals-only | 7z a -si"globals_${DATE_NOW}.sql" "$P7Z_PASS" "$DST_FILE" || true

echo "Dumping roles..."
pg_dumpall --roles-only | 7z a -si"roles_${DATE_NOW}.sql" "$P7Z_PASS" "$DST_FILE" || true

aws $AWS_ARGS s3 cp "$DST_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_PATH"

echo "$(date +"%Y%m%dT%H%M%SZ") Done"
