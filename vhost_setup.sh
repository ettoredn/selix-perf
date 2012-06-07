#!/usr/bin/env bash
VHOSTS=10
APPEND_HOSTNAME=".selixperf.dev"
TEMPLATE_FPM='[{NAME}]
listen = /var/run/php-fpm/{SOCK_NAME}.sock
listen.backlog = -1
listen.mode = 0666

user = {USER}
group = {GROUP}
pm = dynamic
pm.max_children = 1000
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 5
pm.max_requests = 1
;pm.status_path = /status'
TEMPLATE_NGINX='upstream fpms {
{SOCKS}
}

server {
        listen   80;
        server_name selixperf.dev;
        root "/root/webroot";

        location / {
                autoindex on;
                index index.php;
        }

        location ~ ^/wordpress/.+\.php$ {
                fastcgi_pass fpms;
                include fastcgi_params;
        }
}
'

function usage {
	echo "Usage: $0 [--count=N]"
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
newopts=$( getopt -n"$0" --longoptions "count:,help" "h" "$@" ) || usage
set -- $newopts
while (( $# >= 0 ))
do
	case "$1" in
		--count)	VHOSTS=$( echo $2 | sed "s/'//g" )
					if (( VHOSTS < 1 ))
					then
						echo "*** count argument must be > 0" >&2 && quit 1
					fi
					shift;shift;;
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

# Remove all present pools
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
		adduser --no-create-home --disabled-password --gecos dummy "$vhost_name" || quit 1
	fi

	# Create FPM pool
	mkdir -p /var/run/php-fpm/  || quit 1
	pool_conf=$( echo "$TEMPLATE_FPM" | sed 's/{NAME}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{SOCK_NAME}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{USER}/'"$vhost_name"'/g' )
	pool_conf=$( echo "$pool_conf" | sed 's/{GROUP}/'"$vhost_name"'/g' )
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
        root "/root/webroot";

        location / {
                autoindex on;
                index index.php;
        }

        location ~ ^/wordpress/.+\.php$ {
                fastcgi_pass fpms;
                include fastcgi_params;
        }
}
" >> /etc/nginx/sites-available/selixperf
ln -s "/etc/nginx/sites-available/selixperf" "/etc/nginx/sites-enabled/selixperf" 2>/dev/null
# Reload server configuration
/etc/init.d/nginx reload >/dev/null || quit 1

quit 0
