#!/bin/bash
# vim: set ts=8 tw=0 noet :

set -e -o pipefail

# Relocate the PHP code according to the given URI
MantisBTUri=${MANTISBT_URI:-/}
MantisBTUri=${MantisBTUri%/}
MantisBTUri=${MantisBTUri#/}

[[ -n "$MantisBTUri" ]] && mkdir -p /var/www/html/$MantisBTUri
tar -c -f - -C /var/lib/mantisbt . | tar -x -f - -C /var/www/html/$MantisBTUri

cat >/etc/apache2/apache2.conf <<-EOF
	Mutex file:/var/lock/apache2 default
	PidFile /var/run/apache2/apache2.pid
	Timeout 300
	KeepAlive On
	MaxKeepAliveRequests 100
	KeepAliveTimeout 5
	User www-data
	Group www-data
	ErrorLog /proc/self/fd/2
	LogLevel ${LOG_LEVEL:-warn}

	IncludeOptional mods-enabled/*.load
	IncludeOptional mods-enabled/*.conf

	ServerName ${SERVER_NAME:-localhost}
	ServerAdmin ${SERVER_ADMIN:-webmaster@localhost}
	Listen 80
	HostnameLookups Off

	<Directory />
		Options FollowSymLinks
		AllowOverride None
		Require all denied
	</Directory>

	<Directory /var/www/>
		AllowOverride All
		Require all granted
	</Directory>

	DocumentRoot /var/www/html

	AccessFileName .htaccess
	<FilesMatch "^\\.ht">
		Require all denied
	</FilesMatch>

	LogFormat "%h %l %u %t \\"%r\\" %>s %O \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined
	CustomLog /proc/self/fd/1 combined

	<FilesMatch \\.php$>
		SetHandler application/x-httpd-php
	</FilesMatch>

	DirectoryIndex disabled
	DirectoryIndex index.php index.html

	IncludeOptional conf-enabled/*.conf
EOF

# Change ownership to enable online updates
chown -R www-data /var/www/html

# Apache gets grumpy about PID files pre-existing
rm -f /var/run/apache2/apache2.pid

# Setup Apache runtime vars
[[ -s /etc/apache2/envvars ]] && . /etc/apache2/envvars

# Hand over to apache as PID 1
exec apache2 -DFOREGROUND
