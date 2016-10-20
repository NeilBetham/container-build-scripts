#!/usr/bin/env bash
# Build script for a fully self contained pynab instance

# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=./ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=pynab-latest-ubuntu-amd64

NL=$'\n'

ACB="acbuild --debug"

if [ ! -e "./$BASE_IMAGE"  ]; then
  wget "$BASE_IMAGE_URL"
fi

read -rd '' BOOTSTRAP_SCRIPT <<EOF
#!/usr/bin/env bash

supervisord -n
EOF

read -rd '' UWSGI_INI <<EOF
[uwsgi]
socket = /pynab-run/socket
master = true
chdir = /pynab
wsgi-file = api.py
processes = 4
threads = 2
EOF

read -rd '' SUP_CONFIG <<EOF
[program:scan]
command=/usr/bin/python3 /pynab/scan.py update
autostart=true
autorestart=true
stopsignal=QUIT
user=root

[program:postproc]
command=/usr/bin/python3 /pynab/postprocess.py
autostart=true
autorestart=true
stopsignal=QUIT
user=root

[program:prebot]
command=/usr/bin/python3 /pynab/prebot.py start
autostart=true
autorestart=true
stopsignal=QUIT
user=root

[program:stats]
command=/usr/bin/python3 /pynab/scripts/stats.py
autostart=true
autorestart=true
stopsignal=QUIT
user=root

[program:api]
command=/usr/bin/uwsgi --ini /etc/uwsgi/apps-enabled/pynab.ini
autostart=true
autorestart=true
stopsignal=QUIT
user=root

[program:backfill]
command=/usr/bin/python3 /pynab/scan.py backfill
autostart=false
autorestart=true
stopsignal=QUIT
user=root

[program:pubsub]
command=/usr/bin/python3 /pynab/pubsub.py start
autostart=false
autorestart=true
stopsignal=QUIT
user=root

[group:pynab]
programs=scan,postproc,prebot,api,stats,backfill,pubsub
EOF

# Begin the build with the base ubuntu image
$ACB begin "$BASE_IMAGE"

# If we exit before completion, clean up
trap "{ export EXT=$?; $ACB end && exit $EXT; }" SIGINT SIGTERM

# Configure the container
$ACB set-name "$IMAGE_NAME"
$ACB mount add config /pynab-config/
$ACB mount add logs /pynab-logs/
$ACB mount add run /pynab-run/
$ACB mount add pg-run /var/run/postgresql/
$ACB set-working-directory /pynab
$ACB set-user pynab

# Update sources.list
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-backports main restricted"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-backports main restricted"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates multiverse"

# Update and install some deps
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install git python3 python3-setuptools python3-pip libxml2-dev libxslt-dev libyaml-dev postgresql-server-dev-9.5 supervisor unrar -y

# Checkout code
$ACB run -- mkdir /pynab
$ACB run -- mkdir /pynab-config
$ACB run -- git clone https://github.com/NeilBetham/pynab.git /pynab

# Setup app
$ACB run -- ln -s /pynab-config/config.py /pynab/config.py
$ACB run -- pip3 install -r /pynab/requirements.txt
$ACB run -- pip3 install uwsgi
$ACB run -- ln -fs /usr/local/bin/uwsgi /usr/bin/uwsgi

# Write out bootstrap script
$ACB run -- tee /bootstrap-pynab.sh <<< "${BOOTSTRAP_SCRIPT}"
$ACB run -- chmod +x /bootstrap-pynab.sh

# Write out the uWSGI ini
$ACB run -- mkdir -p /etc/uwsgi/apps-enabled/
$ACB run -- tee -a /etc/uwsgi/apps-enabled/pynab.ini <<< "${UWSGI_INI}"

# Write out supervisor config
$ACB run -- tee -a /etc/supervisor/conf.d/pynab.conf <<< "${SUP_CONFIG}"

# Set executable
$ACB set-exec -- /bootstrap-pynab.sh

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
