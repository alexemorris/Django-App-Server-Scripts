mkdir /var/www
useradd --system --shell /bin/bash --home /var/webapps
mkhomedir_helper webapps
APP_PASSWORD=`openssl rand -base64 8`
echo "webapps:$APP_PASSWORD" | chpasswd

cp ~/.ssh/authorized_keys  /var/webapps/.ssh
chown webapps:webapps /var/webapps/.ssh
chown webapps:webapps /var/webapps/authorized_keys

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow 5432

echo "y" | ufw enable

apt update
apt upgrade
apt install redis-server edis-tools python virtualenv supervisor python-dev libpq-dev nginx libmagickwand-dev postgresql postgresql-contrib ufw
