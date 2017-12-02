#!/bin/bash

cat <<_EOF2_> /etc/nginx/sites-available/$1-live
upstream ${1}_live_app_server {
  server unix:/var/www/$1/live/env/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name  www.$2;
    client_max_body_size 4G;

    access_log /var/www/$1/live/logs/nginx-access.log;
    error_log /var/www/$1/live/logs/nginx-error.log;

    location /static/ {
        alias   /var/www/$1/live/static/;
        expires 365d;
    }

    location /media/ {
        alias   /var/www/$1/live/media/;
        expires 365d;
    }

    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        if (!-f '$request_filename') {
          proxy_pass http://${1}_live_app_server;
            break;
        }
    }

}

server {
    listen       80;
    server_name  $2;
    return       301 http://www.$3$request_uri;
}
_EOF2_

ln -s /etc/nginx/sites-available/$1-live /etc/nginx/sites-enabled/$1-live

cat <<_EOF2_> /etc/nginx/sites-available/$1-testing
upstream ${1}_test_app_server {
  server unix:/var/www/$1/test/env/run/gunicorn.sock fail_timeout=0;
}

server {
    listen 80;
    server_name  staging.$2;
    client_max_body_size 4G;

    access_log /var/www/$1/test/logs/nginx-access.log;
    error_log /var/www/$1/test/logs/nginx-error.log;

    location /static/ {
        alias   /var/www/$1/test/static/;
        expires 365d;
    }

    location /media/ {
        alias   /var/www/$1/live/media/;
        expires 365d;
    }

    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        if (!-f '$request_filename') {
          proxy_pass http://${1}_test_app_server;
            break;
        }
    }

}
_EOF2_

ln -s /etc/nginx/sites-available/$1-testing /etc/nginx/sites-enabled/$1-testing

/etc/init.d/nginx restart

echo "Set domain for app $1 to $2"
