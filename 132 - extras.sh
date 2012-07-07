#!/bin/bash
#
function install_ssh {
aptitude -y install openssh
}
function create_sys_backup {
mkdir -p /root/archive
cd /root/archive
for FILE_NAME in `ls /var/cache/apt/archives/*.deb`; do 
  BASE_NAME=`basename $FILE_NAME`
  if ! grep -s $BASE_NAME exclude.txt >/dev/null 2>&1;  then 
    cp -v -u -p $FILE_NAME .
    echo $BASE_NAME >>exclude.txt 
  fi
done
rename -v 's/%3a/:/' *%3a*
aptitude -y install dpkg-dev
dpkg-scansources source /dev/null | gzip -9c > source/Sources.gz
dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz
}
function lock_users {
# Lock user account if not used for login
system_lock_user "irc" 
system_lock_user "games" 
system_lock_user "news" 
system_lock_user "uucp" 
system_lock_user "proxy" 
system_lock_user "list" 
system_lock_user "gnats" 
}
function system_install_lighttpd {
#
aptitude install -y lighttpd pound php5-fpm php5-cli php5-curl php5-gd php-pear php5-imap php5-mcrypt php5-memcache php5-ps php5-pspell php5-recode php5-snmp php5-tidy php5-xmlrpc php5-xsl php5-common php5-mysql php-apc
#
find /etc/php5/ ! -regex ".*[/]\.svn[/]?.*" -type f -name php.ini -exec sed -i'.origs' -e 's/memory_limit = [0-9]\+M/memory_limit = 40M/' -e 's/max_execution_time = [0-9]\+/max_execution_time = 30/' -e 's/upload_max_filesize = [0-9]\+M/upload_max_filesize = 2M/' -e 's/post_max_size = [0-9]\+M/post_max_size = 4M/' -e 's/max_input_time = [0-9]\+/max_input_time = 30/' -e 's/short_open_tag = On/short_open_tag = Off/' -e 's/disable_functions = /disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,dl,/' -e 's/expose_php = On/expose_php = Off/' -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=1/' -e 's/;cgi.force_redirect = 1/cgi.force_redirect = 1/' -e 's/;arg_separator.output/arg_separator.output/' -e 's/;date.timezone =/date.timezone = UTC/' -e 's/session.name = PHPSESSID/session.name = SESSID/' -e 's/allow_url_fopen = On/allow_url_fopen = Off/' -e's/sql.safe_mode = Off/sql.safe_mode = On/' -e 's@;error_log = syslog@error_log = /var/log/php/error.log@' -e 's@;open_basedir =@;open_basedir =/var/www/@' -e 's@;session.save_path = "/tmp"@session.save_path = "/var/lib/php/session"@' -e 's@;upload_tmp_dir =@upload_tmp_dir ="/var/lib/php/session"@'{} \;
#
sed -i'.origs' -e 's/;listen.owner = www-data/listen.owner = www-data/' -e 's/;listen.group = www-data/listen.group = www-data/' -e 's/;listen.mode = 0666/listen.mode = 0600/' -e 's/pm.max_children = 50/pm.max_children = 12/' -e 's/pm.start_servers = 20/pm.start_servers = 4/' -e 's/pm.min_spare_servers = 5/pm.min_spare_servers = 2/' -e 's/pm.max_spare_servers = 35/pm.max_spare_servers = 4/' -e 's/pm.max_requests = 0/pm.max_requests = 500/' /etc/php5/fpm/pool.d/www.conf
#
sed -i 's/#/;/' /etc/php5/conf.d/mcrypt.ini
#
lighty-enable-mod fastcgi
lighty-enable-mod fastcgi-php
#
echo "<?php phpinfo(); ?>" >> /var/www/info.php
#
mkdir -p /var/log/php/
chown -R www-data:www-data /var/log/php/
mkdir -p /var/lib/php/session/
chown -R www-data:www-data /var/lib/php/session/
#
service php5-fpm start
chown -R www-data:www-data /var/www/
chmod -R 0444 /var/www/
find /var/www/ -type d -print0 | xargs -0 -I {} chmod 0445 {}
}
function install_security {
#install chrootkit rkhunter logwatch
aptitude -y install chkrootkit rkhunter logwatch libsys-cpu-perl 
set +e
echo "yes" | cpan 'Sys::MemInfo'
echo "yes" | cpan 'Sys::MemInfo'
set -e
sed -i 's/#ALLOWHIDDENDIR=\/dev\/.initramfs/ALLOWHIDDENDIR=\/dev\/.initramfs/' /etc/rkhunter.conf
sed -i 's/#ALLOWHIDDENDIR=\/dev\/.udev/ALLOWHIDDENDIR=\/dev\/.udev/' /etc/rkhunter.conf
sed -i 's/DISABLE_TESTS="suspscan hidden_procs deleted_files packet_cap_apps apps"/DISABLE_TESTS="suspscan hidden_procs deleted_files packet_cap_apps apps os_specific"/' /etc/rkhunter.conf
rkhunter --propupd
sed -i 's/--output mail/--output mail --detail 10 --service All/' /etc/cron.daily/00logwatch
}

function install_tools {
aptitude -y install vim less logrotate lynx mytop nmap screen sqlite3 cron-apt ntp curl
sed -i 's/# EXITON="error"/EXITON=""/' /etc/cron-apt/config
sed -i 's/# SYSLOGON="upgrade"/SYSLOGON=""/' /etc/cron-apt/config
sed -i 's/# MAILON="error"/MAILON=""/' /etc/cron-apt/config
}