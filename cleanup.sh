#!/usr/bin/env sh

# Exit on error and pipe failure. These are important to set early.
# set -ex will be handled by common.sh if DEBUG=yes
set -e
set -o pipefail

# Source common environment variables and configurations
# shellcheck source=./common.sh
. ./common.sh "cleanup"

### ---- ###

# AWS_ARGS is now set and exported by common.sh

# Determine actual command or echo for DRY_RUN
AWS_COMMAND_EXEC="aws"
if [ "${DRY_RUN}" = "yes" ]; then
  AWS_COMMAND_EXEC="echo aws"
fi

# Check if DELETE_OLDER_THAN is set
if [ -n "${DELETE_OLDER_THAN}" ]; then
  echo "Deleting backups older than ${DELETE_OLDER_THAN}..."

  # Calculate the cutoff timestamp in ISO8601 format (YYYY-MM-DDTHH:MM:SS)
  # Add error handling for invalid date string
  CUTOFF_TIMESTAMP=$(date -d "${DELETE_OLDER_THAN}" --iso-8601=seconds 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Error: Invalid date string for DELETE_OLDER_THAN: '${DELETE_OLDER_THAN}'"
    echo "Please use a format understandable by 'date -d', e.g., '30 days ago', '1 month ago', '2023-01-01'"
    exit 1
  fi
  echo "Calculated cutoff timestamp: ${CUTOFF_TIMESTAMP}"

  # List objects older than the cutoff timestamp
  # The query filters objects based on LastModified.
  # Note: aws s3api list-objects-v2 returns LastModified in a format compatible with direct string comparison.
  # We need to ensure the S3_PREFIX is handled correctly if present.
  # The Key in the output is the full key, so S3_PREFIX should be part of the key.
  # We will list all objects and then filter client-side if S3_PREFIX is set,
  # as JMESPath filtering on Key prefix and LastModified simultaneously can be complex.

  OBJECT_KEYS_TO_DELETE=$(aws $AWS_ARGS s3api list-objects-v2 \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX:-}" \
    --query "Contents[?LastModified<=\`${CUTOFF_TIMESTAMP}\`][].Key" \
    --output text)

  if [ -z "${OBJECT_KEYS_TO_DELETE}" ]; then
    echo "No backups found older than ${CUTOFF_TIMESTAMP}."
  else
    for KEY in ${OBJECT_KEYS_TO_DELETE}; do
      echo "Preparing to delete: s3://${S3_BUCKET}/${KEY}"
      $AWS_COMMAND_EXEC $AWS_ARGS s3 rm "s3://${S3_BUCKET}/${KEY}"
    done
  fi

else
  # Original logic for deleting backups based on hourly/daily/monthly patterns
  echo "DELETE_OLDER_THAN not set. Using original retention logic."

  DATE_TODAY=$(date +"%Y-%m/%d/")
  DATE_THIS_MONTH=$(date +"%Y-%m/")
  DATE_ONLY_YEAR=$(date +"%Y") # Used to filter backups from previous years, keeping specific hours

  # S3_PREFIX is used to filter objects if provided
  S3_LS_PATH="s3://${S3_BUCKET}/${S3_PREFIX:-}"

  echo "Removing old backups (keeping first 4 hours of each day for previous months)..."
  # This loop aims to remove backups from previous months, but keep backups from 00:00-04:00 UTC.
  # It iterates through all objects, then:
  # 1. `grep -vE "${DATE_ONLY_YEAR}....T..0[0-4]"`: Excludes backups from the current year between 00:00 and 04:00.
  #    This seems intended to KEEP early morning backups of the current year if they are not in the current month.
  #    However, the next grep for DATE_THIS_MONTH makes this specific exclusion less clear.
  #    A clearer approach would be to list all, then exclude what to keep.
  # 2. `grep -v "${DATE_THIS_MONTH}"`: Excludes backups from the current month.
  # 3. `grep -oE "${S3_PREFIX:-}.*"`: Extracts the object key. (Adjusted to handle empty S3_PREFIX)

  # Let's list all relevant objects first
  ALL_OBJECTS=$(aws $AWS_ARGS s3 ls --recursive "${S3_LS_PATH}" | awk '{print $4}')

  for path_key in $ALL_OBJECTS; do
    # Skip if the path doesn't match the S3_PREFIX (this is a double check as s3 ls should handle it)
    if [ -n "${S3_PREFIX}" ] && ! echo "${path_key}" | grep -q "^${S3_PREFIX}"; then
        continue
    fi

    # Check if it's from the current month or an early morning backup from the current year
    # If it IS NOT from the current month AND it IS NOT an early morning backup from current year, then delete.
    # This implies keeping all of current month, and early morning backups of previous months in current year.
    if ! echo "${path_key}" | grep -q "${DATE_THIS_MONTH}" && \
       ! echo "${path_key}" | grep -qE "${DATE_ONLY_YEAR}....T(00|01|02|03|04):"; then
      echo "Old backup to remove: s3://${S3_BUCKET}/${path_key}"
      $AWS_COMMAND_EXEC $AWS_ARGS s3 rm "s3://${S3_BUCKET}/${path_key}"
    fi
  done

  echo "Removing backups from this month (keeping first 4 hours of each day and today's backups)..."
  # This loop aims to remove backups from the current month, excluding today's backups and those from 00:00-04:00 UTC.
  # 1. `grep -vE "${DATE_ONLY_YEAR}....T...[0-4]"`: Excludes backups from current year between 00:00-04:00 (hour pattern is ...[0-4]).
  #    This should be T(00|01|02|03|04) for clarity.
  # 2. `grep -v "${DATE_TODAY}"`: Excludes backups from today.
  # 3. `grep -oE "${S3_PREFIX:-}.*"`: Extracts the object key.

  # Re-list objects as some might have been deleted
  ALL_OBJECTS_THIS_MONTH=$(aws $AWS_ARGS s3 ls --recursive "${S3_LS_PATH}" | awk '{print $4}' | grep "${DATE_THIS_MONTH}")

  for path_key in $ALL_OBJECTS_THIS_MONTH; do
    if [ -n "${S3_PREFIX}" ] && ! echo "${path_key}" | grep -q "^${S3_PREFIX}"; then
        continue
    fi

    # If it IS from current month, AND NOT from today, AND NOT an early morning backup, then delete.
    if ! echo "${path_key}" | grep -q "${DATE_TODAY}" && \
       ! echo "${path_key}" | grep -qE "T(00|01|02|03|04):"; then
      echo "This month backup to remove: s3://${S3_BUCKET}/${path_key}"
      $AWS_COMMAND_EXEC $AWS_ARGS s3 rm "s3://${S3_BUCKET}/${path_key}"
    fi
  done
fi

echo "done"
