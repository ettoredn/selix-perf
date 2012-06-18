#!/usr/bin/env bash
SETUP_APT=""
BUILD_PHP=""
BUILD_SELIX=""
BUILD_SYSSTAT=""
BUILD_MODSELINUX=""
BUILD_POLICY=""
function usage {
	echo "Usage: $0 [--all|-a] [--apt] [--php] [--selix] [--sysstat] [--modselinux] [--policy]"
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
newopts=$( getopt -n"$0" --longoptions "all,apt,php,selix,sysstat,modselinux,policy,help" "ah" "$@" ) || usage
set -- $newopts
while (( $# >= 0 ))
do
	case "$1" in
		--all | -a)		SETUP_APT=1; BUILD_PHP=1; BUILD_SELIX=1; BUILD_SYSSTAT=1; BUILD_MODSELINUX; BUILD_POLICY;shift;;
		--apt)			SETUP_APT=1;shift;;
		--php)			BUILD_PHP=1;shift;;
		--selix)		BUILD_SELIX=1;shift;;
		--sysstat)		BUILD_SYSSTAT=1;shift;;
		--modselinux)	BUILD_MODSELINUX=1;shift;;
		--policy)		BUILD_POLICY=1;shift;;
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

#### APT
if [[ $SETUP_APT != "" ]]
then
	echo '
	# Main
	deb http://ftp.it.debian.org/debian/ squeeze main contrib non-free
	deb-src http://ftp.it.debian.org/debian/ squeeze main contrib non-free

	# Security
	deb http://security.debian.org/ squeeze/updates main contrib non-free
	deb-src http://security.debian.org/ squeeze/updates main contrib non-free

	# Updates
	deb http://ftp.it.debian.org/debian/ squeeze-updates main contrib non-free
	deb-src http://ftp.it.debian.org/debian/ squeeze-updates main contrib non-free

	# Backports
	deb http://backports.debian.org/debian-backports squeeze-backports main contrib non-free

	# DotDeb
	deb http://packages.dotdeb.org squeeze all
	deb-src http://packages.dotdeb.org squeeze all
	' > /etc/apt/sources.list
	apt-key adv --keyserver hkp://keys.gnupg.net --recv-keys 89DF5277
	apt-get update
	apt-get install autoconf automake fakeroot build-essential kernel-package selinux-basics \
			libselinux1-dev selinux-policy-dev gawk re2c pkg-config texinfo libtool \
			libxml2-dev libbz2-dev libgd2-noxpm libjpeg8-dev libcurl4-gnutls-dev \
			libvpx-dev libpng12-dev libxpm-dev libonig-dev libmcrypt-dev git libglib2.0-dev \
			uuid-dev libpopt-dev bison libssl-dev
	apt-get install nginx apache2-mpm-prefork apache2-prefork-dev mysql-server-5.5 libmysqlclient-dev
fi

#### System
echo -e "\nSetting maximum number of open file descriptors to unlimited ..."
echo "
*               soft    nofile          999999
*               hard    nofile          999999
root            soft    nofile          999999
root            hard    nofile          999999
" > /etc/security/limits.d/nofile
echo -e "\nSetting vm.oom_kill_allocating_task=1 ..."
echo "vm.oom_kill_allocating_task = 1" > /etc/sysctl.d/oom_kill.conf
sysctl -w vm.oom_kill_allocating_task=1 &>/dev/null || quit 1
echo -e "\nDisabling swap ..."
swapoff -a || quit 1

#### LTTng
# if [[ ! -d ~/LTTng ]]
# then
# 	mkdir ~/LTTng
# 	git clone git://git.lttng.org/userspace-rcu.git ~/LTTng/userspace-rcu
# 	git clone git://git.lttng.org/lttng-ust.git ~/LTTng/lttng-ust
# 	git clone git://git.lttng.org/lttng-tools.git ~/LTTng/lttng-tools
# 	git clone git://git.efficios.com/babeltrace.git ~/LTTng/babeltrace
# fi
#cd ~/LTTng/userspace-rcu && ./bootstrap && ./configure --prefix=/usr && make && make install
#cd ~/LTTng/lttng-ust && ./bootstrap && ./configure --prefix=/usr && make && make install
#cd ~/LTTng/lttng-tools && ./bootstrap && ./configure --prefix=/usr && make && make install
#cd ~/LTTng/babeltrace && ./bootstrap && ./configure --prefix=/usr && make && make install

#### PHP
if [[ ! -d ~/php ]]
then
	git clone -b PHP-5.4 git://github.com/php/php-src.git ~/php || quit 1
fi
cd ~/php
mkdir -p /etc/php/conf.d
if [[ $BUILD_PHP != "" ]]
then
	echo -e "\nBuilding PHP ..."
	# export LIBS="-llttng-ust -lrt -ldl"
	make clean &>/dev/null
	./buildconf
	./configure --prefix=/usr --enable-fpm --enable-cli --with-apxs2=/usr/bin/apxs2 --disable-cgi \
		--with-fpm-user=www-data --with-fpm-group=www-data --with-config-file-path=/etc/php \
		--with-config-file-scan-dir=/etc/php/conf.d --sysconfdir=/etc --localstatedir=/var \
		--mandir=/usr/share/man --with-regex=php --disable-rpath --disable-static \
		--with-pic --with-layout=GNU --with-pear=/usr/share/php --enable-calendar --enable-fileinfo \
		--enable-hash --enable-json --enable-sysvsem --enable-sysvshm --enable-sysvmsg --enable-bcmath \
		--with-bz2 --enable-ctype --without-gdbm --with-iconv --enable-exif --enable-ftp --with-gettext \
		--enable-mbstring --with-onig=/usr --with-pcre-regex --with-mysql=mysqlnd \
		--with-mysql-sock=/var/run/mysqld/mysqld.sock --with-mysqli=mysqlnd --enable-pdo --with-pdo-mysql \
		--with-pdo-pgsql=shared,/usr/bin/pg_config --with-sqlite3 --with-pdo-sqlite --disable-phar \
		--enable-shmop --enable-sockets --enable-simplexml --enable-dom --enable-wddx \
		--with-libxml-dir=/usr --enable-tokenizer --with-zlib --with-kerberos=/usr --with-openssl=/usr \
		--enable-soap --enable-zip --with-mhash=yes --without-mm --without-sybase-ct --without-mssql \
		--with-curl --with-gd --with-mcrypt --without-pear --disable-zip || quit 1
	make && make install
	# export LIBS=""
fi
echo -e "\nConfiguring PHP ..."
mkdir -p /etc/php/conf.d
mkdir -p /etc/php/fpm-pool.d
touch /etc/php/php.ini
#### FPM configuration
echo '
pid = /var/run/php-fpm.pid
error_log = /var/log/php-fpm.log
log_level = notice
daemonize = yes
include=/etc/php/fpm-pool.d/*.conf
' > /etc/php/fpm.conf
#### PHP configuration
echo '
[PHP]
max_execution_time = 300
max_input_time = 60
memory_limit = 512M
auto_globals_jit = Off
post_max_size = 8M
disable_functions = eval
engine = On
short_open_tag = Off
asp_tags = Off
precision = 14
y2k_compliance = On
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 17
allow_call_time_pass_reference = Off
safe_mode = Off
expose_php = On
error_reporting = E_ALL | E_STRICT
display_errors = On
display_startup_errors = On
log_errors = On
report_memleaks = On
track_errors = Off
html_errors = Off
error_log = /var/log/php_errors.log
variables_order = "GPCS"
request_order = "GP"
register_globals = Off
register_long_arrays = Off
register_argc_argv = Off
magic_quotes_gpc = Off
magic_quotes_runtime = Off
magic_quotes_sybase = Off
default_mimetype = "text/html"
enable_dl = Off
file_uploads = On
upload_max_filesize = 2M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = On
default_socket_timeout = 60

[Date]
date.timezone = "Europe/Rome"

[Pdo_mysql]
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=

[Syslog]
define_syslog_variables  = Off

[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = On

[SQL]
sql.safe_mode = Off

[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.connect_timeout = 60
mysql.trace_mode = Off

[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = Off
mysqlnd.collect_memory_statistics = Off

[PostgresSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[Session]
session.save_handler = files
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.bug_compat_42 = Off
session.bug_compat_warn = Off
session.referer_check =
session.entropy_length = 0
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"

[Tidy]
tidy.clean_output = Off

[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5
' > /etc/php/php.ini
# Apache configuration
echo "LoadModule php5_module    /usr/lib/apache2/modules/libphp5.so" > /etc/apache2/mods-available/php5.load
a2enmod php5 &>/dev/null || quit 1
a2enmod rewrite &>/dev/null || quit 1

#### SELIX
if [[ ! -d ~/selix ]]
then
	git clone git://github.com/ettoredn/selix.git ~/selix || quit 1
fi
if [[ $BUILD_SELIX != "" ]]
then
	cd ~/selix && phpize --clean && phpize && ./configure && make && make install
fi

#### SYSSTAT
if [[ ! -d ~/sysstat-10.0.5 ]]
then
	cd ~ && wget http://pagesperso-orange.fr/sebastien.godard/sysstat-10.0.5.tar.bz2 && tar xjf sysstat-10.0.5.tar.bz2
fi
if [[ $BUILD_SYSSTAT != "" ]]
then
	cd ~/sysstat-10.0.5 && ./configure --prefix=/usr && make && make install
fi

#### APACHE
echo -e "\nSetting Apache listen port to 81 ..."
echo '
NameVirtualHost *:81
Listen 81
' > /etc/apache2/ports.conf

#### mod_selinux
if [[ ! -d "$cwd/mod_selinux" ]]
then
	echo "*** mod_selinux source is missing." >&2 && quit 1
fi
if [[ $BUILD_MODSELINUX != "" ]]
then
	echo -e "\nBuilding mod_selinux ..."
	cp -R "$cwd/mod_selinux" ~/mod_selinux && cd ~/mod_selinux
	make clean || quit 1
	make || quit 1
	make install || quit 1
fi

#### NGINX
echo -e "\nSetting up nxing ..."
rm -f /etc/nginx/sites-enabled/default

#### WEBROOT
if [[ $( mount | egrep webroot ) == "" ]]
then
	echo -e "\nRebinding webroot to /dev/shm/webroot ..."
	rm -rf ~/webroot
	rm -rf /dev/shm/webroot
	mkdir ~/webroot || quit 1
	mkdir /dev/shm/webroot || quit 1
	touch ~/webroot/this.is.the.old.one
	mount --bind /dev/shm/webroot ~/webroot || quit 1
	echo -e "\nCopying phpSQLiteCMS into webroot ..."
	cp -R "$cwd/app_phpsqlitecms" ~/webroot/phpsqlitecms
fi

# SELinux policy
$( selinuxenabled )
if [[ $? == 0 && $BUILD_POLICY != "" ]]
then
	# SELinux enabled, load apache policy
	echo -e "\nBuilding policy modules for mod_selinux PHP-FPM and virtualhosts ..."
	cd "$cwd/policy" || quit 1
	buildfail=0

	if (( buildfail == 0 )) ; then
		echo -e "\tExecuting make ..."
		make clean >/dev/null || buildfail=1
		make >/dev/null || buildfail=1
	fi

	if (( buildfail != 0 ))
	then
		echo "*** Build of policy modules failed." >&2 && quit 1
	fi
	
	# Remove policy modules (if present)
	semodule -r virtualhosts &>/dev/null
	semodule -r php-fpm &>/dev/null
	semodule -r mod_selinux &>/dev/null

	echo -e "\tLoading mod_selinux policy module ..."
	semodule -i mod_selinux.pp >/dev/null || quit 1
	echo -e "\tLoading PHP-FPM policy module ..."
	semodule -i php-fpm.pp >/dev/null || quit 1
	echo -e "\tLoading virtualhosts policy module ..."
	semodule -i virtualhosts.pp >/dev/null || quit 1
	echo -e "\tRestoring contexts ..."
	restorecon -r /usr/sbin/php-fpm || quit 1
	restorecon -r /usr/bin/php || quit 1
	restorecon -r /usr/lib/php || quit 1
	restorecon -r /etc/php || quit 1
	restorecon -r /var/log/php-fpm.log || quit 1
	
	# Relabel webroot
	echo -e "\tRelabeling webroot ..."
	cd ~/webroot || quit 1
	find -print0 | xargs -0 chcon -t httpd_sephp_content_t
	find -type f -name "*.php" -print0 | xargs -0 chcon -t php_sephp_script_t
	find -type f -name ".htaccess" -print0 | xargs -0 chcon -t httpd_sephp_htaccess_t &>/dev/null
	chcon -t httpd_sephp_content_t . || quit 1
	
	cd $cwd
fi

quit 0