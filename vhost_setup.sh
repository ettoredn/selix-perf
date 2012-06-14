#!/usr/bin/env bash
VHOSTS=10
FPM_CHILDREN=5
FPM_REQUESTS=0
ENABLE_SELIX=0
APPEND_HOSTNAME=".selixperf.dev"
TEMPLATE_FPM='[{NAME}]
listen = /var/run/php-fpm/{SOCK_NAME}.sock
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

function usage {
	echo "Usage: $0 [--vhosts n] [--children n] [--requests n] [--enable-selix]"
	quit 1
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
newopts=$( getopt -n"$0" --longoptions "vhosts:,children:,requests:,enable-selix,help" "h" "$@" ) || usage
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

if [[ $ENABLE_SELIX == 1 ]]
then
	$( selinuxenabled )
	if (( $? != 0 ))
	then
		echo "*** You cannot load selix extension if SELinux is not enabled on the system." >&2 && quit 1
	fi
	echo "zend_extension=/usr/lib/php/20100525-debug/selix.so
	auto_globals_jit = Off" > /etc/php/conf.d/selix.ini || quit 1
	
	# Force only 1 vhost with an equivalent number of children
	FPM_CHILDREN=$(( VHOSTS * FPM_CHILDREN ))
	VHOSTS=1
else
	rm "/etc/php/conf.d/selix.ini" &>/dev/null
fi

echo "$VHOSTS vhosts, $FPM_CHILDREN children, $FPM_REQUESTS requests, \
$(( $VHOSTS * $FPM_CHILDREN )) processes"

# Remove all active FPM pools
rm /etc/php/fpm-pool.d/*.conf
for (( i=1; i<=$VHOSTS; i++ ))
do
	vhost_name="wp$i"
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
	pool_conf=$( echo "$pool_conf" | sed 's/{SOCK_NAME}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{USER}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{GROUP}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{CHILDREN}/'"$FPM_CHILDREN"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{REQUESTS}/'"$FPM_REQUESTS"'/g' )
	echo "$pool_conf" > "/etc/php/fpm-pool.d/$vhost_name.conf" || quit 1
	
	nginx_socks="$nginx_socks        server unix:/var/run/php-fpm/$vhost_name.sock;
"
done
killall php-fpm
php-fpm --fpm-config /etc/php/fpm.conf

# Create Nginx virtual host
echo "upstream fpms {" > /etc/nginx/sites-available/selixperf
echo -n "$nginx_socks" >> /etc/nginx/sites-available/selixperf
echo "}" >> /etc/nginx/sites-available/selixperf
echo -n "
server {
        listen   80;
        server_name selixperf.dev;
        root \"/root/webroot\";

        location / {
                autoindex on;
                index index.php;
        }

        location ~ ^/wordpress/.+\.php$ {
                fastcgi_pass fpms;
                include fastcgi_params;
				fastcgi_param SELINUX_DOMAIN			\"sephp_php_t\";
				fastcgi_param SELINUX_RANGE				\"s0\";
				fastcgi_param SELINUX_COMPILE_DOMAIN	\"sephp_compile_php_t\";
				fastcgi_param SELINUX_COMPILE_RANGE		\"s0\";
        }
}
" >> /etc/nginx/sites-available/selixperf
ln -s "/etc/nginx/sites-available/selixperf" "/etc/nginx/sites-enabled/selixperf" 2>/dev/null
# Reload server configuration
/etc/init.d/nginx reload >/dev/null || quit 1

quit 0
