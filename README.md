# docker-volume-backup

This image backups docker volumes to minio server

## Usage:

    docker-compose up 

## Parameters

    CRON_TIME       the interval of cron job to run mysqldump. `0 0 * * *` by default, which is every day at 00:00
    MAX_BACKUPS     the number of backups to keep. When reaching the limit, the old backup will be discarded. No limit by default
    INIT_BACKUP     if set, create a backup when the container starts
    INIT_RESTORE_LATEST if set, restores latest backup

    INIT_RESTORE_URL restore from minio url ex: myminio/bla/file.sql 
    MINIO_HOST name of minio host ex: myminio
    MINIO_HOST_URL ex: https://myminio.my.io
    MINIO_ACCESS_KEY minio access key
    MINIO_SECRET_KEY minio secret key

## Restore from a backup

See the list of backups, you can run:

    docker exec jmcarbo/docker-volume-backup mc ls myminio/minio-bucket/

To restore database from a certain backup, simply run:

    docker exec jmcarbo/docker-volume-backup /restore.sh myminio/minio-bucket/2015.08.06.171901
