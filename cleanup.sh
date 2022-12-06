#!/usr/bin/env sh

set -ex
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

### ---- ###

if [ "${S3_ENDPOINT}" = "**None**" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

DATE_TODAY=$(date +"%Y-%m/%d/")
DATE_THIS_MONTH=$(date +"%Y-%m/")
DATE_ONLY_YEAR=$(date +"%Y")
AWS_COMMAND=aws
if [ "x${DRY_RUN}" != "x" ]; then
  AWS_COMMAND="echo aws"
fi

### ---- ###

echo "remove old backups..."
for path in `aws $AWS_ARGS s3 ls --recursive $S3_BUCKET --summarize --human-readable | \
  grep -vE "${DATE_ONLY_YEAR}....T..0[0-4]" | \
  grep -v "${DATE_THIS_MONTH}" | \
  grep -oE "${S3_PREFIX}.*"`
do
	$AWS_COMMAND $AWS_ARGS s3 rm s3://${S3_BUCKET}/${path}
done

echo "remove backups from this month..."
for path in `aws $AWS_ARGS s3 ls --recursive $S3_BUCKET --summarize --human-readable | \
  grep -vE "${DATE_ONLY_YEAR}....T...[0-4]" | \
  grep -v "${DATE_TODAY}" | \
  grep -oE "${S3_PREFIX}.*"`
do
	$AWS_COMMAND $AWS_ARGS s3 rm s3://${S3_BUCKET}/${path}
done

echo "done"
