#!/usr/bin/env sh

# Exit on error and pipe failure
set -e
set -o pipefail

# Check for DEBUG mode
if [ "${DEBUG}" = "yes" ]; then
  set -ex
fi

# Script type argument
SCRIPT_TYPE="${1}"

# --- Common AWS Configuration ---
if [ "${AWS_ACCESS_KEY_ID}" = "**None**" ] || [ -z "${AWS_ACCESS_KEY_ID}" ]; then
  echo "Error: You need to set the AWS_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${AWS_SECRET_ACCESS_KEY}" = "**None**" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
  echo "Error: You need to set the AWS_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ] || [ -z "${S3_BUCKET}" ]; then
  echo "Error: You need to set the S3_BUCKET environment variable."
  exit 1
fi

# Configure AWS arguments for S3 endpoint if specified
if [ "${S3_ENDPOINT}" = "**None**" ] || [ -z "${S3_ENDPOINT}" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi
export AWS_ARGS

# --- Script-Specific Checks ---

# Checks for backup and restore scripts
if [ "${SCRIPT_TYPE}" = "backup" ] || [ "${SCRIPT_TYPE}" = "restore" ]; then
  if [ "${PGHOST}" = "**None**" ] || [ -z "${PGHOST}" ]; then
    echo "Error: You need to set the PGHOST environment variable."
    exit 1
  fi

  if [ "${PGUSER}" = "**None**" ] || [ -z "${PGUSER}" ]; then
    echo "Error: You need to set the PGUSER environment variable."
    exit 1
  fi

  if [ "${PGPASSWORD}" = "**None**" ] || [ -z "${PGPASSWORD}" ]; then
    echo "Error: You need to set the PGPASSWORD environment variable."
    exit 1
  fi

  if [ "${POSTGRES_DATABASE}" = "**None**" ] || [ -z "${POSTGRES_DATABASE}" ]; then
    echo "Error: You need to set the POSTGRES_DATABASE environment variable."
    exit 1
  fi

  # Encryption password for 7zip
  if [ "${ENCRYPTION_PASSWORD}" != "**None**" ] && [ -n "${ENCRYPTION_PASSWORD}" ]; then
    P7Z_PASS="-p${ENCRYPTION_PASSWORD}"
  else
    P7Z_PASS=""
  fi
  export P7Z_PASS
fi

# Add any checks specific to "cleanup" if they arise,
# for now, it only uses the common AWS vars.

if [ "${DEBUG}" = "yes" ]; then
  echo "Common setup for ${SCRIPT_TYPE} completed."
fi
# Make sure the last command exits with 0 if no errors
true
