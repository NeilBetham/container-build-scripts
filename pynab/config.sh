#!/usr/bin/env bash

read -rd '' BOOTSTRAP_SCRIPT <<EOF
#!/usr/bin/env bash

supervisord -n
EOF

read -rd '' UWSGI_INI <<EOF
[uwsgi]
socket = /pynab-run/socket
chmod-socket = 666
vacuum = true
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
