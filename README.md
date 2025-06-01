# postgres-backup-s3

Backup PostgresSQL to S3 (supports periodic backups)

## Basic Usage

```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e POSTGRES_DATABASE=dbname -e POSTGRES_USER=user -e POSTGRES_PASSWORD=password -e POSTGRES_HOST=localhost itbm/postgres-backup-s3
```

## Kubernetes Deployment

```
apiVersion: v1
kind: Namespace
metadata:
  name: backup

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: backup
spec:
  selector:
    matchLabels:
      app: postgresql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: itbm/postgresql-backup-s3
        imagePullPolicy: Always
        env:
        - name: POSTGRES_DATABASE
          value: ""
        - name: POSTGRES_HOST
          value: ""
        - name: POSTGRES_PORT
          value: ""
        - name: POSTGRES_PASSWORD
          value: ""
        - name: POSTGRES_USER
          value: ""
        - name: S3_ACCESS_KEY_ID
          value: ""
        - name: S3_SECRET_ACCESS_KEY
          value: ""
        - name: S3_BUCKET
          value: ""
        - name: S3_ENDPOINT
          value: ""
        - name: S3_PREFIX
          value: ""
        - name: SCHEDULE
          value: ""
```

## Environment variables

| Variable             | Default   | Required | Description                                                                                                              |
|----------------------|-----------|----------|--------------------------------------------------------------------------------------------------------------------------|
| POSTGRES_DATABASE    |           | Y        | Database you want to backup or 'all' to backup everything                                                                |
| POSTGRES_HOST        |           | Y        | The PostgreSQL host                                                                                                      |
| POSTGRES_PORT        | 5432      |          | The PostgreSQL port                                                                                                      |
| POSTGRES_USER        |           | Y        | The PostgreSQL user                                                                                                      |
| POSTGRES_PASSWORD    |           | Y        | The PostgreSQL password                                                                                                  |
| POSTGRES_EXTRA_OPTS  |           |          | Extra postgresql options                                                                                                 |
| S3_ACCESS_KEY_ID     |           | Y        | Your AWS access key                                                                                                      |
| S3_SECRET_ACCESS_KEY |           | Y        | Your AWS secret key                                                                                                      |
| S3_BUCKET            |           | Y        | Your AWS S3 bucket path                                                                                                  |
| S3_PREFIX            | backup    |          | Path prefix in your bucket                                                                                               |
| S3_REGION            | us-east-1 |          | The AWS S3 bucket region                                                                                                 |
| S3_ENDPOINT          |           |          | The AWS Endpoint URL, for S3 Compliant APIs such as [minio](https://minio.io)                                            |
| S3_S3V4              | no        |          | Set to `yes` to enable AWS Signature Version 4, required for [minio](https://minio.io) servers                           |
| SCHEDULE             |           |          | Backup schedule time, see explainatons below                                                                             |
| ENCRYPTION_PASSWORD  |           |          | Password to encrypt the backup. See Encryption section for how to decrypt.                                               |
| DELETE_OLDER_THAN    |           |          | If set (e.g., "30 days ago", "1 month ago"), `cleanup.sh` deletes backups older than this duration. See "Delete Old Backups". |

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

### Delete Old Backups

You can additionally set the `DELETE_OLDER_THAN` environment variable (e.g., `-e DELETE_OLDER_THAN="30 days ago"`) to trigger the cleanup process.
If `DELETE_OLDER_THAN` is set, the `cleanup.sh` script will remove backups from the `s3://${S3_BUCKET}/${S3_PREFIX}` path that are older than the specified duration.
If `DELETE_OLDER_THAN` is *not* set or is empty, `cleanup.sh` falls back to its original behavior: it will delete older backups based on a pattern, generally keeping the last 24 hourly backups, last 7 daily backups, last 4 weekly backups, and all monthly backups (these specific numbers might vary based on script's internal logic, designed to keep recent backups more frequently).

**Important**: The cleanup script operates on objects found within the `s3://${S3_BUCKET}/${S3_PREFIX}` path. Ensure that this path is dedicated to these backups if you want to avoid accidental deletion of other data.

### Encryption

If you set the `ENCRYPTION_PASSWORD` variable (e.g., `-e ENCRYPTION_PASSWORD="superstrongpassword"`), the backup file (which is a `.7z` archive) will be encrypted.
To decrypt and extract the backup, you can use the following command:
```sh
7z e -pYOUR_PASSWORD your_backup_file.7z -o./extracted_backup_files
```
Replace `YOUR_PASSWORD` with your actual encryption password and `your_backup_file.7z` with the name of the downloaded backup file. The contents (SQL dumps, TAR files, roles, globals) will be extracted to the `extracted_backup_files` directory.
You will typically find files like `databasename_YYYYMMDDTHHMMSSZ.tar`, `globals_YYYYMMDDTHHMMSSZ.sql`, and `roles_YYYYMMDDTHHMMSSZ.sql` inside the archive.
