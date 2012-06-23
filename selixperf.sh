#!/usr/bin/env bash
TARGET_HOST="selixperf.dev"
TARGET_SSH_USER="root"
SETUP_SCRIPT="~/selixperf/vhost_setup.sh"
CONFIG=""
VHOSTS=""
FPM_CHILDREN=""
FPM_REQUESTS=""
FPM_STARTPORT=9000
PERF_HOST="localhost"
PERF_PORT="81"
PERF_URI="/phpsqlitecms/"
PERF_CONN="500"
PERF_RATE="80"
ENABLE_SELIX=0
SQL_TMP_PATH="/dev/shm"
DB_USER="root"
DB_PASS="ettore"
DB_DATABASE="php_performance"
DB_TABLE_SA="system_activity"
DB_TABLE_TEST="test"

function usage {
	echo "Usage: $0 [--use-last-session] [--conf <fpm|fpmvm|modselinux>] [--enable-selix] [--vhosts n] [--children n] [--requests n] [--server <hostname>] [--uri </path/>] [--conn n] [--rate n]"
	quit 0
}

function quit {
	cd "$old_cwd"
	if (( $1 > 0 )) ; then echo -e "\n*** Aborted due to previous errors" ; fi
	exit $1
}

function kill_sysstat {
	echo -e "\nKilling sysstat on remote host ..."
	ssh "$TARGET_SSH_USER@$TARGET_HOST" "kill -SIGTERM $sar_pid"	
}

trap "{
	kill_sysstat
	quit 0
}" SIGINT SIGTERM

# Initialize variables
old_cwd=$( pwd )
abspath=$(cd ${0%/*} && echo $PWD/${0##*/})
cwd=$( dirname "$abspath" )
ecwd=$( echo $cwd | sed 's/\//\\\//g' )
perf_session=$( date +%s )
perf_test=$( date +%s )

# Evaluate options
newopts=$( getopt -n"$0" --longoptions "use-last-session,conf:,server:,vhosts:,children:,requests:,uri:,conn:,rate:,enable-selix,help" "h" "$@" ) || usage
set -- $newopts
while (( $# >= 0 ))
do
	case "$1" in
		--use-last-session)	sql="SELECT session,perf_connections,perf_rate FROM $DB_TABLE_TEST ORDER BY session DESC LIMIT 1;"
					row=$( echo "$sql" | mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_DATABASE" | tail -1 )
					last_session=$( echo $row | awk '{print $1}' )
					last_conn=$( echo $row | awk '{print $2}' )
					last_rate=$( echo $row | awk '{print $3}' )
					if [[ "$last_session" != "" ]]
					then
						if [[ $last_session != ${last_session//[^0-9]/} ]]
						then
							echo "*** Unable to retrieve last session id" >&2 && quit 1
						fi
						if [[ $last_conn != ${last_conn//[^0-9]/} ]]
						then
							echo "*** Unable to retrieve last session connection number" >&2 && quit 1
						fi
						if [[ $last_rate != ${last_rate//[^0-9]/} ]]
						then
							echo "*** Unable to retrieve last session connection rate" >&2 && quit 1
						fi
						perf_session="$last_session"
					fi
					shift;;
		--server)	PERF_HOST=$( echo $2 | sed "s/'//g" )
					shift;shift;;
		--conf)		CONFIG=$( echo $2 | sed "s/'//g" )
					shift;shift;;
		--vhosts)	VHOSTS=$( echo $2 | sed "s/'//g" )
					if (( VHOSTS < 1 ))
					then
						echo "*** vhosts argument must be > 0" >&2 && quit 1
					fi
					shift;shift;;
		--children)	FPM_CHILDREN=$( echo $2 | sed "s/'//g" )
					if (( FPM_CHILDREN < 1 ))
					then
						echo "*** children argument must be > 0" >&2 && quit 1
					fi
					shift;shift;;
		--requests)	FPM_REQUESTS=$( echo $2 | sed "s/'//g" )
					if (( FPM_REQUESTS < 0 ))
					then
						echo "*** requests argument must be > -1" >&2 && quit 1
					fi
					shift;shift;;
		--uri)		PERF_URI=$( echo $2 | sed "s/'//g" )
					shift;shift;;
		--conn)		PERF_CONN=$( echo $2 | sed "s/'//g" )
					if (( PERF_CONN < 1 ))
					then
						echo "*** conn argument must be > 1" >&2 && quit 1
					fi
					shift;shift;;
		--rate)		PERF_RATE=$( echo $2 | sed "s/'//g" )
					if (( PERF_RATE < 1 ))
					then
						echo "*** rate argument must be > 1" >&2 && quit 1
					fi
					shift;shift;;
		--enable-selix) ENABLE_SELIX=1;shift;;
		--fpm) 		CONFIG_FPM=1;shift;;
		--modselinux)	CONFIG_MODSELINUX=1;shift;;
		--fpmvm)	CONFIG_FPMVM=1;shift;;
		--help | -h) usage;;
		--) shift;break;;
	esac
done

if [[ "$last_conn" != "" ]]; then PERF_CONN="$last_conn"; fi
if [[ "$last_rate" != "" ]]; then PERF_RATE="$last_rate"; fi

# --conf must be defined
if [[ $CONFIG != "fpm" && $CONFIG != "modselinux" && $CONFIG != "fpmvm" ]]
then
	echo "*** configuration option must be fpm, modselinux or fpmvm" >&2 && quit 1
fi

# Check httperf
which httperf &>/dev/null || ( echo "*** Can't locate httperf" >&2 && quit 1 )

if [[ $VHOSTS != "" ]]
then
	VHOSTS="--vhosts=$VHOSTS"
fi
if [[ $FPM_CHILDREN != "" ]]
then
	FPM_CHILDREN="--children=$FPM_CHILDREN"
fi
if [[ $FPM_REQUESTS != "" ]]
then
	FPM_REQUESTS="--requests=$FPM_REQUESTS"
fi
if [[ $ENABLE_SELIX == 1 ]]
then
	ENABLE_SELIX="--enable-selix"
fi

echo -ne "Executing vhosts setup script on remote host $SERVER ...\n\t"
vhost_output=$( ssh "$TARGET_SSH_USER@$TARGET_HOST" "$SETUP_SCRIPT $ENABLE_SELIX $VHOSTS $FPM_CHILDREN $FPM_REQUESTS --conf=$CONFIG" )
if [[ $? != 0 ]]
then
	echo "*** Error executing vhosts setup script" >&2 && quit 1
fi
echo "$vhost_output"
# Assign real values used by the script
seded=$( echo "$vhost_output" | head -1 | sed "s/\([[:digit:]]\+\) vhosts, \([[:digit:]]\+\) children, \([[:digit:]]\+\) requests.*/\1 \2 \3/" )
tokens=( $seded )
VHOSTS="${tokens[0]}"
FPM_CHILDREN="${tokens[1]}"
FPM_REQUESTS="${tokens[2]}"

echo -ne "\nExecuting sysstat on remote host ...\n\t"
ssh "$TARGET_SSH_USER@$TARGET_HOST" "rm perf.sa"
ssh "$TARGET_SSH_USER@$TARGET_HOST" "sar 1 -o perf.sa &>/dev/null &" || quit 1
sar_pid=$( ssh "$TARGET_SSH_USER@$TARGET_HOST" "ps -eF" | egrep 'sar 1 -o perf' | egrep -v 'egrep' | awk '{print $2}' )
echo "PID: $sar_pid"

# Adds "_selix" if selix is enabled
if [[ "$ENABLE_SELIX" == "--enable-selix" ]]
then
	CONFIG="${CONFIG}_selix"
fi

sudo /etc/init.d/nginx stop

echo -ne "\nSetting up nginx ...\n"
if [[ "$CONFIG" == "fpm" ]]
then
	for (( i=0; i<$VHOSTS; i++ ))
	do
		nginx_socks="$nginx_socks        server $TARGET_HOST:$FPM_STARTPORT;
"
		(( FPM_STARTPORT++ ))
	done
	
	# Create Nginx virtual host
	sudo chmod 666 /etc/nginx/sites-enabled/selixperf
	echo "upstream fpms {" > /etc/nginx/sites-available/selixperf
	echo -n "$nginx_socks" >> /etc/nginx/sites-available/selixperf
	echo "}" >> /etc/nginx/sites-available/selixperf
	echo -n "
server {
	listen   81;
	server_name sephp.dev;
	root \"/root/webroot\";

	location = /phpsqlitecms/ {
		try_files \$uri \$uri/index.php;
	}

	location ~ ^/phpsqlitecms/.+\.php$ {
		fastcgi_pass fpms;
		include fastcgi_params;
		fastcgi_keep_conn on;
		fastcgi_param SELINUX_DOMAIN			\"sephp_php_t\";
		fastcgi_param SELINUX_RANGE				\"s0\";
		fastcgi_param SELINUX_COMPILE_DOMAIN	\"sephp_compile_php_t\";
		fastcgi_param SELINUX_COMPILE_RANGE		\"s0\";
	}
}
" >> /etc/nginx/sites-available/selixperf
fi

if [[ "$CONFIG" == "modselinux" ]]
then
	for (( i=0; i<$VHOSTS; i++ ))
	do
		nginx_locations="$nginx_locations
        location /phpsqlitecms/${i}/ {
			proxy_pass http://selixperf.dev:81/phpsqlitecms/;
			proxy_set_header Host sp${i}.selixperf.dev;
        }"
		perf_uris="${perf_uris}/phpsqlitecms/${i}/\0"
	done
	# Write urls
	echo -en "$perf_uris" > "$cwd/uris.txt"
	
	# Create Nginx virtual host
	sudo chmod 666 /etc/nginx/sites-enabled/selixperf
	echo -n "
server {
	listen   81;
	server_name sephp.dev;
	root \"/root/webroot\";
	
	$nginx_locations
}
" > /etc/nginx/sites-available/selixperf
fi

sudo /etc/init.d/nginx start
# kill_sysstat && quit 0

sleep 5
# httperf
echo -e "\nExecuting httperf, estimated time $(( PERF_CONN / PERF_RATE ))s ..."
if [[ "$CONFIG" == "modselinux" ]]
then
	httperf --hog --server="$PERF_HOST" --port="$PERF_PORT" --wlog="y,${cwd}/uris.txt" --num-con="$PERF_CONN" --rate="$PERF_RATE" || quit 1
else
	httperf --hog --server="$PERF_HOST" --port="$PERF_PORT" --uri="$PERF_URI" --num-con="$PERF_CONN" --rate="$PERF_RATE" || quit 1
fi
kill_sysstat

echo -e "\nLoading system activity into database ..."
sqltmpfile="$SQL_TMP_PATH/perf_$perf_session.sql"
echo "START TRANSACTION;" > "$sqltmpfile"

secs=0
while read line
do
	if [[ "${line:0:1}" == "#" ]]; then continue; fi
	IFS=';'; tokens=( $line ); IFS=' '
	(( secs++ ))
	cpu_user="${tokens[4]}"
	cpu_system="${tokens[6]}"
	cpu_iowait="${tokens[7]}"
	cpu_idle="${tokens[9]}"
	mem_used_kb="${tokens[11]}"
	mem_used="${tokens[12]}"
	mem_buffers_kb=""${tokens[13]}""
	mem_cached_kb=""${tokens[14]}""
	
	sql="INSERT INTO $DB_TABLE_SA \
		(test, seconds_elapsed, cpu_user, cpu_system, cpu_iowait, cpu_idle, mem_used_kb, mem_used, mem_buffers_kb, mem_cached_kb) \
		VALUES( $perf_test, $secs, $cpu_user, $cpu_system, $cpu_iowait, $cpu_idle, $mem_used_kb, $mem_used, $mem_buffers_kb, $mem_cached_kb );"
	echo $sql >> "$sqltmpfile"
	
	echo "($secs) user $cpu_user%, sys $cpu_system%, idle $cpu_idle%, mem $mem_used_kb, mem $mem_used%"
done <<< "$( ssh "$TARGET_SSH_USER@$TARGET_HOST" "sadf -dht -- -ru perf.sa" )"

echo "INSERT INTO $DB_TABLE_TEST (test, session, configuration, vhosts, children, \
 	  child_requests, perf_connections, perf_rate) \
	VALUES( $perf_test, $perf_session, '$CONFIG', $VHOSTS, $FPM_CHILDREN, $FPM_REQUESTS, $PERF_CONN, $PERF_RATE );" >> "$sqltmpfile"

echo "COMMIT;" >> "$sqltmpfile"
mysql -u "$DB_USER" -p"$DB_PASS" -D "$DB_DATABASE" < "$sqltmpfile" || quit 1
rm "$sqltmpfile"

quit 0
