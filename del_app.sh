#!/bin/bash
echo "Stopping services"
supervisorctl stop $1-live-gunicorn
supervisorctl stop $1-live-celery
supervisorctl stop $1-test-gunicorn
supervisorctl stop $1-test-celery

echo "Deleting user account"
deluser --remove-home $1
rm -rf /var/www/$1
rm /etc/supervisor/conf.d/$1-test-celery.conf
rm /etc/supervisor/conf.d/$1-live-celery.conf
rm /etc/supervisor/conf.d/$1-live-gunicorn.conf
rm /etc/supervisor/conf.d/$1-test-gunicorn.conf
rm /etc/nginx/sites-available/$1-live
rm /etc/nginx/sites-available/$1-testing
unlink /etc/nginx/sites-enabled/$1-live
unlink /etc/nginx/sites-enabled/$1-testing

echo "Removing databses"
su - postgres <<_EOF1_
dropdb $1
dropdb ${1}_test
dropuser $1
_EOF1_

echo "Reloading supervisor"
supervisorctl reread
supervisorctl reload

echo "Restarting nginx"
/etc/init.d/nginx restart
