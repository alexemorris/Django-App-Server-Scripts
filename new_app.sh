#!/bin/bash
useradd --system --gid webapps --shell /bin/bash --home /var/www/$1 $1
mkhomedir_helper $1
mkdir -p /var/www/$1/.ssh
cp ~/.ssh/authorized_keys  /var/www/$1/.ssh
chown $1:webapps /var/www/$1/.ssh
chown $1:webapps /var/www/$1/.ssh/authorized_keys

APP_PASSWORD=`openssl rand -base64 8`
echo "$1:$APP_PASSWORD" | chpasswd

su postgres <<_EOF1_
cd /var/lib/postgresql/
echo "CREATE ROLE $1 WITH PASSWORD ""'""$APP_PASSWORD""'"";" | psql -U postgres
createdb --owner=$1 $1
createdb --owner=$1 ${1}_test
_EOF1_

su - $1 <<_EOF1_
echo 'creating Live git repo'
mkdir /var/www/$1/live.git
cd /var/www/$1/live.git
git init --bare

echo 'creating test git repo'
mkdir /var/www/$1/test.git
cd /var/www/$1/test.git
git init --bare

echo 'creating live app directory structure'
mkdir /var/www/$1/live
mkdir /var/www/$1/live/logs
touch  /var/www/$1/live/logs/gunicorn_supervisor.log

cd /var/www/$1/live
virtualenv env
source env/bin/activate
pip install --upgrade pip
pip install gunicorn
pip install psycopg2
pip install celery[redis]
deactivate

echo 'Copying to test'
cp /var/www/$1/live /var/www/$1/test -R

echo 'creating backup directory'
mkdir /var/www/$1/backup

cat <<_EOF2_> /var/www/$1/live.git/hooks/post-receive
#!/bin/sh
echo 'stopping services'
supervisorctl stop $1-live-gunicorn
supervisorctl stop $1-live-celery
supervisorctl stop $1-test-gunicorn
supervisorctl stop $1-test-celery
git --work-tree=/var/www/$1/live --git-dir=/var/www/$1/live.git checkout -f
cd /var/www/$1/live
virtualenv env
source env/bin/activate
echo yes | python manage.py collectstatic
python manage.py makemigrations
python manage.py migrate
deactivate
supervisorctl start $1-live-gunicorn
supervisorctl start $1-live-celery
sudo /etc/init.d/nginx restart
_EOF2_

chmod +x /var/www/$1/live.git/hooks/post-receive

cat <<_EOF2_> /var/www/$1/test.git/hooks/post-receive
#!/bin/sh
supervisorctl stop $1-test-gunicorn
supervisorctl stop $1-test-celery
git --work-tree=/var/www/$1/test --git-dir=/var/www/$1/test.git checkout -f
cd /var/www/$1/test
virtualenv env
source env/bin/activate
echo yes | python manage.py collectstatic
python manage.py makemigrations
python manage.py migrate
deactivate
supervisorctl start $1-test-gunicorn.conf
supervisorctl start $1-test-celery.conf
sudo /etc/init.d/nginx restart
_EOF2_

chmod +x /var/www/$1/test.git/hooks/post-receive

chmod g+w -R /var/www/$1
chmod g-w ~
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
_EOF1_

su - $1 <<_EOF1_

cat <<_EOF2_> /var/www/$1/test/env/bin/gunicorn_start
#!/bin/bash
NAME=$1-live                                # Name of the application
DJANGODIR=/var/www/$1/live/             # Django project directory
SOCKFILE=/var/www/$1/live/env/run/gunicorn.sock  # we will communicte using this unix socket
USER=$1                                        # the user to run as
GROUP=webapps                                     # the group to run as
NUM_WORKERS=3                                     # how many worker processes should Gunicorn spawn
DJANGO_SETTINGS_MODULE=$2.settings             # which settings file should Django use
DJANGO_WSGI_MODULE=$2.wsgi                     # WSGI module name
'echo "Starting $NAME staging as `whoami`"'
cd '$DJANGODIR'
source env/bin/activate
export DJANGO_SETTINGS_MODULE='$DJANGO_SETTINGS_MODULE'
export PYTHONPATH='${DJANGODIR}':'$PYTHONPATH'
RUNDIR='$'(dirname '$SOCKFILE')
test -d '$RUNDIR' || mkdir -p '$RUNDIR'
exec env/bin/gunicorn '${DJANGO_WSGI_MODULE}':application '\'
  --name '$NAME' '\'
  --workers '$NUM_WORKERS' '\'
  --user='$USER' --group=webapps '\'
  --bind=unix:'$SOCKFILE' '\'
  --log-level=debug '\'
  --log-file=-
_EOF2_

chmod u+x /var/www/$1/test/env/bin/gunicorn_start

cat <<_EOF2_> /var/www/$1/test/env/bin/gunicorn_start
#!/bin/bash
NAME=$1-test                                # Name of the application
DJANGODIR=/var/www/$1/test/             # Django project directory
SOCKFILE=/var/www/$1/test/env/run/gunicorn.sock  # we will communicte using this unix socket
USER=$1                                        # the user to run as
GROUP=webapps                                     # the group to run as
NUM_WORKERS=3                                     # how many worker processes should Gunicorn spawn
DJANGO_SETTINGS_MODULE=$2.settings             # which settings file should Django use
DJANGO_WSGI_MODULE=$2.wsgi                     # WSGI module name
'echo "Starting $NAME staging as `whoami`"'
cd '$DJANGODIR'
source env/bin/activate
export DJANGO_SETTINGS_MODULE='$DJANGO_SETTINGS_MODULE'
export PYTHONPATH='${DJANGODIR}':'$PYTHONPATH'
RUNDIR='$'(dirname '$SOCKFILE')
test -d '$RUNDIR' || mkdir -p '$RUNDIR'
exec env/bin/gunicorn '${DJANGO_WSGI_MODULE}':application '\'
  --name '$NAME' '\'
  --workers '$NUM_WORKERS' '\'
  --user='$USER' --group=webapps '\'
  --bind=unix:'$SOCKFILE' '\'
  --log-level=debug '\'
  --log-file=-
_EOF2_

chmod u+x /var/www/$1/test/env/bin/gunicorn_start

_EOF1_


cat <<_EOF2_> /etc/supervisor/conf.d/${1}-live-gunicorn.conf
[program:${1}-live-gunicorn]
command = /var/www/$1/live/env/bin/gunicorn_start                    ; Command to start app
user=$1                                                      ; User to run as
stdout_logfile=/var/www/$1/live/logs/gunicorn_supervisor.log   ; Where to write log messages
redirect_stderr=true                                                ; Save stderr in the same log
environment=LANG=en_US.UTF-8,LC_ALL=en
_EOF2_

cat <<_EOF2_> /etc/supervisor/conf.d/${1}-test-gunicorn.conf
[program:${1}-test-gunicorn]
command=/var/www/$1/test/env/bin/gunicorn_start                    ; Command to start app
user=$1                                                      ; User to run as
stdout_logfile=/var/www/$1/test/logs/gunicorn_supervisor.log   ; Where to write log messages
redirect_stderr=true                                                ; Save stderr in the same log
environment=LANG=en_US.UTF-8,LC_ALL=en
_EOF2_

cat <<_EOF2_>> /etc/supervisor/conf.d/${1}-live-celery.conf
[program:${1}-live-celery]
command=/var/www/$1/live/env/bin/celery --app=$1.celery:app worker --loglevel=INFO
directory=/var/www/$1/live/
user=$1
numprocs=1
stdout_logfile=/var/www/$1/live/logs/celery-worker.log
stderr_logfile=/var/www/$1/live/logs/celery-worker.log
autostart=true
autorestart=true
startsecs=10
stopwaitsecs = 600
killasgroup=true
priority=998
_EOF2_

cat <<_EOF2_>> /etc/supervisor/conf.d/${1}-test-celery.conf
[program:${1}-test-celery]
command=/var/www/$1/test/env/bin/celery --app=$1.celery:app worker --loglevel=INFO
directory=/var/www/$1/test/
user=$1
numprocs=1
stdout_logfile=/var/www/$1/test/logs/celery-worker.log
stderr_logfile=/var/www/$1/test/logs/celery-worker.log
autostart=true
autorestart=true
startsecs=10
stopwaitsecs = 600
killasgroup=true
priority=998
_EOF2_


cat <<_EOF2_>> /etc/nginx/sites-available/$1-live
upstream ${1}_live_app_server {
  server unix:/var/www/$1/live/env/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name  www.$3 $3;
    client_max_body_size 4G;

    access_log /var/www/$1/live/logs/nginx-access.log;
    error_log /var/www/$1/live/logs/nginx-error.log;

    location /static/ {
        alias   /var/www/$1/live/static/;
    }

    location /media/ {
        alias   /var/www/$1/live/media/;
    }

    location / {
        proxy_set_header X-Forwarded-For '$proxy_add_x_forwarded_for';
        proxy_set_header Host '$http_host';
        proxy_redirect off;
        if (!-f '$request_filename') {
          proxy_pass http://${1}_live_app_server;
            break;
        }
    }
}

server {
    listen       80;
    server_name  $3;
    return       301 http://www.$3$request_uri;
}
_EOF2_

ln -s /etc/nginx/sites-available/$1-live /etc/nginx/sites-enabled/$1-live

cat <<_EOF2_>> /etc/nginx/sites-available/$1-testing
upstream ${1}_test_app_server {
  server unix:/var/www/$1/test/env/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name  staging.$3;
    client_max_body_size 4G;

    access_log /var/www/$1/test/logs/nginx-access.log;
    error_log /var/www/$1/test/logs/nginx-error.log;

    location /static/ {
        alias   /var/www/$1/test/static/;
    }

    location /media/ {
        alias   /var/www/$1/live/media/;
    }

    location / {
        proxy_set_header X-Forwarded-For '$proxy_add_x_forwarded_for';
        proxy_set_header Host '$http_host';
        proxy_redirect off;
        if (!-f '$request_filename') {
          proxy_pass http://${1}_test_app_server;
            break;
        }
    }
}
_EOF2_

ln -s /etc/nginx/sites-available/$1-testing /etc/nginx/sites-enabled/$1-testing

supervisorctl reread
/etc/init.d/nginx restart

echo "App created with password $APP_PASSWORD"
