#!/bin/bash

MINIO_HOST=${MINIO_HOST:-myminio}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)}
[ -z "${MINIO_HOST_URL}" ] && { echo "=> MINIO_HOST_URL cannot be empty" && exit 1; }
[ -z "${MINIO_ACCESS_KEY}" ] && { echo "=> MINIO_ACCESS_KEY cannot be empty" && exit 1; }
[ -z "${MINIO_SECRET_KEY}" ] && { echo "=> MINIO_SECRET_KEY cannot be empty" && exit 1; }
[ -z "${MINIO_BUCKET}" ] && { echo "=> MINIO_BUCKET cannot be empty" && exit 1; }
[ -z "${BACKUP_DIRS}" ] && { echo "=> BACKUP_DIRS cannot be empty" && exit 1; }

echo $RESTIC_PASSWORD

mkdir -p "$HOME/.mc"
cat <<EOF >"$HOME/.mc/config.json"
{
	"version": "7",
	"hosts": {
	"${MINIO_HOST}": {
	"url": "${MINIO_HOST_URL}",
	"accessKey": "${MINIO_ACCESS_KEY}",
	"secretKey": "${MINIO_SECRET_KEY}",
	"api": "S3v4"
	}
	}
}
EOF
if mc mb "${MINIO_HOST}/${MINIO_BUCKET}"; 
then 
	echo "Bucket ${MINIO_BUCKET} created"; 
	echo "$RESTIC_PASSWORD"	| mc pipe "${MINIO_HOST}/${MINIO_BUCKET}/restic_password.txt"
	if [ -n "${USE_RESTIC}" ]; then
		mc mb "${MINIO_HOST}/${MINIO_BUCKET}restic"
		export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY}
		export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}
		export RESTIC_PASSWORD
		restic -r "s3:${MINIO_HOST_URL}/${MINIO_BUCKET}restic" init
	fi
else 
	echo "Bucket ${MINIO_BUCKET} already exists"; 
	RESTIC_PASSWORD=$(mc cat "${MINIO_HOST}/${MINIO_BUCKET}/restic_password.txt")
fi

echo $RESTIC_PASSWORD
if [ -n "${USE_RESTIC}" ]; then
	BACKUP_CMD="restic -r s3:\${MINIO_HOST_URL}/\${MINIO_BUCKET}restic backup \${BACKUP_DIRS}"
cat <<EOF >>/root/.bashrc
export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}
export RESTIC_PASSWORD=$(mc cat "${MINIO_HOST}/${MINIO_BUCKET}/restic_password.txt")
export RESTIC_REPOSITORY=s3:${MINIO_HOST_URL}/${MINIO_BUCKET}restic
EOF

else
	BACKUP_CMD="mc mirror \${BACKUP_DIRS} \${MINIO_HOST}/\${MINIO_BUCKET}/\${BACKUP_NAME}"
fi

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}

BACKUP_NAME=\$(date +\%Y.\%m.\%d.\%H\%M\%S)

echo "=> Backup started: \${BACKUP_NAME}"

if [ -n "\${USE_RESTIC}" ]; then
	export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY}
	export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}
	export RESTIC_PASSWORD=$(mc cat "${MINIO_HOST}/${MINIO_BUCKET}/restic_password.txt")
	export RESTIC_REPOSITORY=s3:\${MINIO_HOST_URL}/\${MINIO_BUCKET}restic
fi

if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"
else
    echo "   Backup failed"
    #rm -rf /backup/\${BACKUP_NAME}
fi

if [ -z "\${USE_RESTIC}" ]; then
	if [ -n "\${MAX_BACKUPS}" ]; then
	    while [ \$(mc ls "${MINIO_HOST}/${MINIO_BUCKET}/" | wc -l) -gt \${MAX_BACKUPS} ];
	    do
		BACKUP_TO_BE_DELETED=\$( mc ls "${MINIO_HOST}/${MINIO_BUCKET}/" | awk '{print $5;}' | sort | head -n 1)
		echo "   Backup \${BACKUP_TO_BE_DELETED} is deleted"
		mc rm  "${MINIO_HOST}/${MINIO_BUCKET}/${BACKUP_TO_BE_DELETED}"
	    done
	fi
fi
echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
if [ -n "\${USE_RESTIC}" ]; then
	export AWS_ACCESS_KEY_ID=${MINIO_ACCESS_KEY}
	export AWS_SECRET_ACCESS_KEY=${MINIO_SECRET_KEY}
	export RESTIC_PASSWORD=$(mc cat "${MINIO_HOST}/${MINIO_BUCKET}/restic_password.txt")
	export RESTIC_REPOSITORY=s3:\${MINIO_HOST_URL}/\${MINIO_BUCKET}restic
	restic restore -t / \$1
else
	echo "=> Restore database from \$1"
	if mc mirror "${MINIO_HOST}/${MINIO_BUCKET}/\$1" "${BACKUP_DIRS}" ;then
	    echo "   Restore succeeded"
	else
	    echo "   Restore failed"
	fi
fi
echo "=> Done"
EOF
chmod +x /restore.sh

touch /volume_backup.log
tail -F /volume_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
elif [ -n "${INIT_RESTORE_LATEST}" ]; then
    echo "=> Restore latest backup"
	if [ -z "${USE_RESTIC}" ]; then
     		mc ls "${MINIO_HOST}/${MINIO_BUCKET}/" | awk '{print $5;}' | tail -1 | xargs /restore.sh
	fi
elif [ -n "${INIT_RESTORE_URL}" ]; then
	mc mirror "${INIT_RESTORE_URL}" "${BACKUP_DIR}" 	
fi

echo "${CRON_TIME} /backup.sh >> /volume_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
