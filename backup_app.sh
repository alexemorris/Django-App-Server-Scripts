#!/bin/bash
BACKUP_NAME=`date | md5`

su - $1 <<_EOF1_
mkdir /var/www/$1/backup/$BACKUP_NAME
mkdir /var/www/$1/backup/$BACKUP_NAME/config
_EOF1_

su - postgres <<_EOF1_
pgdump $1 > ~/$BACKUP_NAME/dump.sql/
_EOF1_


cp /etc/supervisor/conf.d/${1}-live-gunicorn.conf /var/www/$1/backup/$BACKUP_NAME/config
cp /etc/supervisor/conf.d/${1}-live-celery.conf /var/www/$1/backup/$BACKUP_NAME/config
cp /etc/supervisor/conf.d/${1}-live-celery.conf /var/www/$1/backup/$BACKUP_NAME/config
cp /etc/nginx/sites-available/$1-live /var/www/$1/backup/$BACKUP_NAME/config
cp postgres/$BACKUP_NAME/dump.sql /var/www/$1/backup/$BACKUP_NAME


su - postgres <<_EOF1_
rm -rf ~/$BACKUP_NAME/
_EOF1_

su - $1 <<_EOF1_
cp -ar /var/www/$1/live /var/www/$1/backup/$BACKUP_NAME/
_EOF1_

chown -R $1:webapps /var/www/$1/backup/
