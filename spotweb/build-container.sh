#!/usr/bin/env bash
# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=./ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=spotweb-latest-ubuntu-amd64

NL=$'\n'

ACB="acbuild --debug"

if [ ! -e "./$BASE_IMAGE"  ]; then
  wget "$BASE_IMAGE_URL"
fi

read -rd '' FPM_BOOTSTRAP <<EOF
#!/usr/bin/env bash

mkdir -p /run/php/

exec /usr/sbin/php-fpm7.0 -F --fpm-config /etc/php/7.0/fpm/php-fpm.conf
EOF

read -rd '' NGX_BOOTSTRAP <<EOF
#!/usr/bin/env bash

rm -f /spotweb-run/nginx.sock

exec /usr/sbin/nginx -g 'daemon off;'
EOF

read -rd '' SUP_CONFIG <<EOF
[program:nginx]
command=/bin/bash /ngx-bootstrap.sh
autostart=true
autorestart=true
stopsignal=QUIT
user=root
stderr_logfile = /spotweb-logs/nginx-stderr.log
stdout_logfile = /spotweb-logs/nginx-stdout.log
stdout_logfile_maxbytes = 10MB
stderr_logfile_maxbytes = 10MB
stdout_logfile_backups = 10
stderr_logfile_backups = 10

[program:php-fpm]
command=/bin/bash /php-fpm-bootstrap.sh
autostart=true
autorestart=true
stopsignal=QUIT
user=root
stderr_logfile = /spotweb-logs/php-fpm-stderr.log
stdout_logfile = /spotweb-logs/php-fpm-stdout.log
stdout_logfile_maxbytes = 10MB
stderr_logfile_maxbytes = 10MB
stdout_logfile_backups = 10
stderr_logfile_backups = 10


[group:spotweb]
programs=nginx,php-fpm
EOF

read -rd '' NGINX_SITE_CONFIG <<'EOF'
server {
	listen unix:/spotweb-run/nginx.sock;

	root /spotweb;
	index index.php index.html index.htm;

	# Make site accessible from http://localhost/
	server_name _;
	
	# Add stdout logging

	error_log /dev/stdout info;
	access_log /dev/stdout;

	location / {
		try_files $uri $uri/ =404;
	}

	#
	location ~ [^/]\.php(/|$) {
		fastcgi_split_path_info ^(.+?\.php)(/.*)$;
		if (!-f $document_root$fastcgi_script_name) {
			return 404;
		}

		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
		fastcgi_param HTTP_PROXY "";
		fastcgi_param SCRIPT_FILENAME $document_root/$fastcgi_script_name;
		fastcgi_index index.php;
		include fastcgi_params;
	}

        location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
                expires           5d;
        }

	# deny access to . files, for security
	#
	location ~ /\. {
    		log_not_found off; 
    		deny all;
	}

}
EOF

# Begin the build with the base ubuntu image
$ACB begin "$BASE_IMAGE"

# If we exit before completion, clean up
trap "{ export EXT=$?; $ACB end && exit $EXT; }" SIGINT SIGTERM

# Configure the container
$ACB set-name "$IMAGE_NAME"
$ACB mount add config /spotweb-config/
$ACB mount add run /spotweb-run/
$ACB mount add logs /spotweb-logs/
$ACB mount add cache /spotweb-cache/
$ACB mount add my-run /var/run/mysqld
$ACB set-working-directory /spotweb

# Update sources.list
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates universe"

# Install updates and requirements
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install supervisor git php-fpm php-mysql nginx php-gd php-curl php-zip php-xml php-mbstring -y

# Setup nginx 
$ACB run -- tee /etc/nginx/sites-available/default <<< "${NGINX_SITE_CONFIG}"

# Write out supervisor config
$ACB run -- tee /etc/supervisor/conf.d/spotweb.conf <<< "${SUP_CONFIG}"
$ACB run -- tee /php-fpm-bootstrap.sh <<< "${FPM_BOOTSTRAP}"
$ACB run -- chmod +x /php-fpm-bootstrap.sh
$ACB run -- tee /ngx-bootstrap.sh <<< "${NGX_BOOTSTRAP}"
$ACB run -- chmod +x /ngx-bootstrap.sh

# Setup spotweb
$ACB run -- mkdir -p /run/php/
$ACB run -- mkdir /spotweb-config
$ACB run -- mkdir /spotweb-cache
$ACB run -- git clone https://github.com/spotweb/spotweb.git

$ACB run -- rm -rf /var/www/html
$ACB run -- ln -s /spotweb-config/ownsettings.php /spotweb/ownsettings.php
$ACB run -- ln -s /spotweb-cache/ /spotweb/cache

# PHP FPM config
$ACB run -- tee /etc/php/7.0/fpm/php.ini <<< "date.timezone=\"America/Los_Angeles\""

# Set executable
$ACB set-exec -- /usr/bin/supervisord -n

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
