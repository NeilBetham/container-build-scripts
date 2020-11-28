#!/usr/bin/env bash

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
