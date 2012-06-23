#!/usr/bin/env bash
CONFIG=""
VHOSTS=10
FPM_CHILDREN=5
FPM_REQUESTS=0
FPM_STARTPORT=9000
ENABLE_SELIX=0
APPEND_HOSTNAME=".selixperf.dev"
TEMPLATE_FPM='[{NAME}]
listen = 0.0.0.0:{PORT}
listen.backlog = -1
listen.mode = 0666

user = {USER}
group = {GROUP}
pm = static
pm.max_children = {CHILDREN}
pm.max_requests = {REQUESTS}
;pm.start_servers = 5
;pm.min_spare_servers = 5
;pm.max_spare_servers = 5
;pm.status_path = /status'
TEMPLATE_APACHE='
<VirtualHost *:81>
	ServerName {SERVERNAME}
	DocumentRoot "/root/webroot"
	<Directory "/root/webroot">
		Options Indexes FollowSymLinks MultiViews
		AllowOverride All
		Order allow,deny
		allow from all
	</Directory>
	
	<FilesMatch \.php$>
	    SetHandler application/x-httpd-php
	</FilesMatch>
	
	# mod_selinux parameters
	selinuxDomainVal	sephp_httpd_t
</VirtualHost>'

function usage {
	echo "Usage: $0 [--vhosts n] [--children n] [--requests n] [--enable-selix] [--conf <fpm|fpmvm|modselinux>]"
	quit 0
}

function quit {
	cd "$old_cwd"
	if (( $1 > 0 )) ; then echo -e "\n*** Aborted due to previous errors" ; fi
	exit $1
}

# Initialize variables
old_cwd=$( pwd )
abspath=$(cd ${0%/*} && echo $PWD/${0##*/})
cwd=$( dirname "$abspath" )
ecwd=$( echo $cwd | sed 's/\//\\\//g' )

# Evaluate options
newopts=$( getopt -n"$0" --longoptions "vhosts:,children:,requests:,conf:,enable-selix,help" "h" "$@" ) || usage
set -- $newopts
while (( $# >= 0 ))
do
	case "$1" in
		--vhosts)		VHOSTS=$( echo $2 | sed "s/'//g" )
						if (( VHOSTS < 1 ))
						then
							echo "*** vhosts argument must be > 0" >&2 && quit 1
						fi
						shift;shift;;
		--children)		FPM_CHILDREN=$( echo $2 | sed "s/'//g" )
						if (( FPM_CHILDREN < 1 ))
						then
							echo "*** children argument must be > 0" >&2 && quit 1
						fi
						shift;shift;;
		--requests)		FPM_REQUESTS=$( echo $2 | sed "s/'//g" )
						if (( FPM_REQUESTS < 0 ))
						then
							echo "*** requests argument must be > -1" >&2 && quit 1
						fi
						shift;shift;;
		--conf)			CONFIG=$( echo $2 | sed "s/'//g" )
						shift;shift;;
		--enable-selix) ENABLE_SELIX=1;shift;;
		--help | -h) usage;;
		--) shift;break;;
	esac
done

# Change to script directory
cd "$cwd"

# Script must be run as root
if [[ $( whoami ) != "root" ]]
then
	echo "*** This script must be run as root" >&2 && quit 1
fi

# --conf must be defined
if [[ $CONFIG != "fpm" && $CONFIG != "modselinux" && $CONFIG != "fpmvm" ]]
then
	echo "*** configuration option must be fpm, modselinux or fpmvm" >&2 && quit 1
fi

if [[ $ENABLE_SELIX == 1 ]]
then
	$( selinuxenabled )
	if (( $? != 0 ))
	then
		echo "*** You cannot load selix extension if SELinux is not enabled on the system." >&2 && quit 1
	fi
	echo "zend_extension=/usr/lib/php/20100525/selix.so
	auto_globals_jit = Off" > /etc/php/conf.d/selix.ini || quit 1
	
	# Force only 1 vhost with an equivalent number of children
	FPM_CHILDREN=$(( VHOSTS * FPM_CHILDREN ))
	VHOSTS=1
else
	rm "/etc/php/conf.d/selix.ini" &>/dev/null
fi

echo "$VHOSTS vhosts, $FPM_CHILDREN children, $FPM_REQUESTS requests, \
$(( $VHOSTS * $FPM_CHILDREN )) processes"

# Stop servers
sleep 1
/etc/init.d/nginx stop
/etc/init.d/apache2 stop
killall php-fpm &>/dev/null

# FPM configuration: $VHOSTS pools
if [[ $CONFIG == "fpm" ]]
then
	# Remove all active FPM pools
	rm /etc/php/fpm-pool.d/*.conf
	for (( i=0; i<$VHOSTS; i++ ))
	do
		vhost_name="sp$i"
		# vhost_root="/root/webroot/$vhost_name"
		# vhost_root=$( echo "$vhost_root" | sed 's/\//\\\//g' )
		vhost_hostname="$vhost_name$APPEND_HOSTNAME"

		# Add user
		if [[ $( cat /etc/passwd | egrep "^$vhost_name" ) == "" ]]
		then
			adduser --no-create-home --disabled-password --gecos dummy "$vhost_name" &>/dev/null || quit 1
		fi

		# Create FPM pool
		mkdir -p /var/run/php-fpm/  || quit 1
		pool_conf=$( echo "$TEMPLATE_FPM" | sed 's/{NAME}/'"$vhost_name"'/g' )
		pool_conf=$( echo "$pool_conf" | sed 's/{PORT}/'"$((FPM_STARTPORT + i))"'/g' )
		pool_conf=$( echo "$pool_conf" | sed 's/{USER}/'"$vhost_name"'/g' )
		pool_conf=$( echo "$pool_conf" | sed 's/{GROUP}/'"$vhost_name"'/g' )
		pool_conf=$( echo "$pool_conf" | sed 's/{CHILDREN}/'"$FPM_CHILDREN"'/g' )
		pool_conf=$( echo "$pool_conf" | sed 's/{REQUESTS}/'"$FPM_REQUESTS"'/g' )
		echo "$pool_conf" > "/etc/php/fpm-pool.d/$vhost_name.conf" || quit 1
	done
	php-fpm --fpm-config /etc/php/fpm.conf
fi

# Apache with mod_selinux
if [[ $CONFIG == "modselinux" ]]
then
	# Include mod_selinux configuration	
	a2enmod mod_selinux >/dev/null || quit 1
	
	# Remove all active Apache virtual hosts
	rm /etc/apache2/sites-enabled/* &>/dev/null
	rm /etc/apache2/sites-available/*  &>/dev/null
	
	for (( i=0; i<$VHOSTS; i++ ))
	do
		vhost_hostname="sp$i$APPEND_HOSTNAME"
		vhost_conf=$( echo "$TEMPLATE_APACHE" | sed 's/{SERVERNAME}/'"$vhost_hostname"'/g' )
		vhost_file="$vhost_file$vhost_conf"
		echo "$vhost_file" >> /etc/apache2/sites-available/selixperf || quit 1
	done
	ln -s "/etc/apache2/sites-available/selixperf" "/etc/apache2/sites-enabled/selixperf" 2>/dev/null

	echo "KeepAlive Off
	<IfModule mpm_prefork_module>
	    StartServers          $FPM_CHILDREN
	    MinSpareServers       $FPM_CHILDREN
	    MaxSpareServers       $FPM_CHILDREN
	    MaxClients          256
	    MaxRequestsPerChild   $FPM_REQUESTS
	</IfModule>
	" > /etc/apache2/conf.d/selixperf
		
	# Reload server configuration
	/etc/init.d/apache2 start &>/dev/null || ( echo "Error starting Apache" >&2 && quit 1 )
fi

# Drop caches
sync && echo 3 >/proc/sys/vm/drop_caches

quit 0
