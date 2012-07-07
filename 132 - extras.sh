#!/bin/bash
#
# Installing and configuring the nessary servers for the include stack scripts
#
# 2012 - David Peters - dave@daveshow.com
# Creative Commons Attribution-NonCommercial-ShareAlike 3.0 United States (CC BY-NC-SA 3.0) 
#
# Link: https://github.com/daveshow/StackScripts
#
#
function install_ssh {
aptitude -y install openssh-server
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
mkdir -p /root/archive/source
dpkg-scansources source /dev/null | gzip -9c > source/Sources.gz
mkdir -p /root/archive/binary
dpkg-scanpackages binary /dev/null | gzip -9c > binary/Packages.gz
}
function set_timezone {
  # $1 - timezone (zoneinfo file)
  ln -sf "/usr/share/zoneinfo/$1" /etc/localtime
  dpkg-reconfigure --frontend noninteractive tzdata
}
function set_conf_value {
  # $1 - conf file
  # $2 - key
  # $3 - value
  sed -i "s/^\($2[ ]*=[ ]*\).*/\1$3/" $1
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
aptitude install -y lighttpd pound 
#
lighty-enable-mod fastcgi
lighty-enable-mod fastcgi-php
}
function install_secure_php {
aptitude install -y php5-fpm php5-cli php5-curl php5-gd php-pear php5-imap php5-mcrypt php5-memcache php5-ps php5-pspell php5-recode php5-snmp php5-tidy php5-xmlrpc php5-xsl php5-common php5-mysql php-apc
find /etc/php5/ ! -regex ".*[/]\.svn[/]?.*" -type f -name php.ini -exec sed -i'.origs' -e 's/memory_limit = [0-9]\+M/memory_limit = 40M/' -e 's/max_execution_time = [0-9]\+/max_execution_time = 30/' -e 's/upload_max_filesize = [0-9]\+M/upload_max_filesize = 2M/' -e 's/post_max_size = [0-9]\+M/post_max_size = 4M/' -e 's/max_input_time = [0-9]\+/max_input_time = 30/' -e 's/short_open_tag = On/short_open_tag = Off/' -e 's/disable_functions = /disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,dl,/' -e 's/expose_php = On/expose_php = Off/' -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=1/' -e 's/;cgi.force_redirect = 1/cgi.force_redirect = 1/' -e 's/;arg_separator.output/arg_separator.output/' -e 's/;date.timezone =/date.timezone = UTC/' -e 's/session.name = PHPSESSID/session.name = SESSID/' -e 's/allow_url_fopen = On/allow_url_fopen = Off/' -e 's/sql.safe_mode = Off/sql.safe_mode = On/' -e 's@;error_log = syslog@error_log = /var/log/php/error.log@' -e 's@;open_basedir =@;open_basedir =/var/www/@' -e 's@;session.save_path = "/tmp"@session.save_path = "/var/lib/php/session"@' -e 's@;upload_tmp_dir =@upload_tmp_dir ="/var/lib/php/session"@' {} \;
#
sed -i'.origs' -e 's/;listen.owner = www-data/listen.owner = www-data/' -e 's/;listen.group = www-data/listen.group = www-data/' -e 's/;listen.mode = 0666/listen.mode = 0600/' -e 's/pm.max_children = 50/pm.max_children = 12/' -e 's/pm.start_servers = 20/pm.start_servers = 4/' -e 's/pm.min_spare_servers = 5/pm.min_spare_servers = 2/' -e 's/pm.max_spare_servers = 35/pm.max_spare_servers = 4/' -e 's/pm.max_requests = 0/pm.max_requests = 500/' /etc/php5/fpm/pool.d/www.conf
#
sed -i 's/#/;/' /etc/php5/conf.d/mcrypt.ini
#
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
chmod -R 0755 /var/www/
find /var/www/ -type d -print0 | xargs -0 -I {} chmod 0445 {}
}
function install_security {
#install chrootkit rkhunter logwatch
aptitude -y install chkrootkit rkhunter logwatch libsys-cpu-perl 
set +e
echo "yes" | cpan 'Sys::MemInfo'
echo "yes" | cpan 'Sys::MemInfo'
set -e
rkhunter --propupd
}
function configure_chkrootkit {
  CONF=/etc/chkrootkit.conf
  test -f $CONF || exit 0

  set_conf_value $CONF "RUN_DAILY" "\"true\""
  set_conf_value $CONF "RUN_DAILY_OPTS" "-q -e '\/usr\/lib\/jvm\/.java-1.6.0-openjdk.jinfo \/usr\/lib\/byobu\/.constants \/usr\/lib\/byobu\/.dirs \/usr\/lib\/byobu\/.shutil \/usr\/lib\/byobu\/.notify_osd \/usr\/lib\/byobu\/.common \/usr\/lib\/pymodules\/python2.7\/.path'"
}

function configure_rkhunter {
  CONF=/etc/rkhunter.conf
  test -f $CONF || exit 0

  set_conf_value $CONF "MAIL-ON-WARNING" "\"root\""
  sed -i "/ALLOWHIDDENDIR=\/dev\/.initramfs$/ s/^#//" $CONF
  sed -i "/ALLOWHIDDENDIR=\/dev\/.udev$/ s/^#//" $CONF
  # Disabling tests for kernel modules, Linode kernel doens't have any modules loaded
  sed -i "/^DISABLE_TESTS=.*/ s/\"$/ os_specific\"/" $CONF
}
function copy_logwatch {
cp /usr/share/logwatch/default.conf/logwatch.conf /etc/logwatch/conf/logwatch.conf
}
function configure_logwatch {
  CONF=/etc/logwatch/conf/logwatch.conf
  test -f $CONF || exit 0

  set_conf_value $CONF "Output" "mail"
  set_conf_value $CONF "Format" "html"
  set_conf_value $CONF "Detail" "High"
}
function install_tools {
aptitude -y install vim less logrotate lynx mytop nmap screen sqlite3 cron-apt ntp curl
}
function configure_cronapt {
  CONF=/etc/cron-apt/config
  test -f $CONF || exit 0

  sed -i "s/^# \(MAILON=\).*/\1\"changes\"/" $CONF
}
function config_screen {
#
cat <<EOT >/root/.screenrc
  altscreen         on  # default: off  enable "alternate screen" support
  autodetach        on  # default: on   automatically detach on hangup
  crlf              off # default: off  no crlf for end-of-lines
  deflogin          off # default: on   default setting for login
  defsilence        off # default: off  default setting for silence
  hardcopy_append   on  # default: off  append hardcopies to hardcopy files
  ignorecase        on  # default: off  ignore case in searches
  startup_message   off # default: on   NO startup_message - thankyou!
  vbell             off # default: ???  be silent on bells
  termcapinfo xterm     ti@:te@
  termcapinfo linux "ve=\E[?25h\E[?17;0;64c"
  termcapinfo rxvt-cygwin-native ti@:te@
  defscrollback         1000  # default: 100
  nonblock              23    # default: ???  unblock display after N secs of refusing output
  silencewait           15    # default: 30
  hardcopydir   $HOME/.screen
  shell         bash
  #caption always "%?%-Lw%?%n*%f %t%?(%u)%?%?%+Lw%?"
  caption always "%{ck}%?%-Lw%?%{Yk}%n*%f %t%?(%u)%?%{ck}%?%+Lw%?"
  #caption always "%{kG}%?%-Lw%?%{bw}%n*%f %t%?(%u)%?%{kG}%?%+Lw%?"
  #caption always '%{= wb}%50=%n%f %t%{= wb}'
  #hardstatus alwayslastline "%Y-%m-%d %c %H %l"
  #hardstatus alwayslastline "%{= Gb}%Y-%m-%d %c %{= RY}%H %{= BW}%l"
  hardstatus alwayslastline "%{kr}%l %{kg}%c %{ky}%M%d"
  #hardstatus alwayslastline "%{Gb}%Y-%m-%d %c %{= RY}%H %{BW}%l%{Gb} %="
  #hardstatus alwayslastline "%{rw}%H%{wk}|%c|%M%d|%?%-Lw%?%{bw}%n*%f %t%?(%u)%?%{wk}%?%+Lw%?"
  sorendition    kG # black  on bold green
  activity              "%C -> %n%f %t activity!"
  bell_msg         "Bell in window %n"
  pow_detach_msg   "BYE"
  vbell_msg        " *beep* "
  bind .
  bind ^\
  bind \\
  bind j focus down
  bind k focus up
  bind o only
           time "%H %Y-%m-%d %c:%s"
  bind t   time
  bind + resize +1
  bind - resize -1
  bind " " select 0
  bind R colon "source $HOME/.screenrc"
  markkeys "$=^E"
  markkeys "@=d=f=i=N"
  bind @ windowlist -m
  windowlist title  "Num Title"
  windowlist string "%3n %t"
  windowlist title  "Flag Num Title"
  windowlist string "%f%04= %3n %t"
EOT
}
function system_install_node {
#install munin
aptitude -y install munin munin-node libcache-cache-perl libdbd-mysql-perl
sed -i 's/host \*/host 127.0.0.1/' /etc/munin/munin-node.conf
sed -i "s/localhost.localdomain/`hostname -f`/" /etc/munin/munin.conf
echo "munin: root" >> /etc/aliases
sed -i "s#\[mysql\*\]#[mysql*]\nenv.mysqladmin /usr/bin/mysqladmin#" /etc/munin/plugin-conf.d/munin-node
if [ -x /usr/bin/newaliases ]
then
/usr/bin/newaliases
fi
}
function configure_logcheck {
  # Ignore the message flood about UFW blocking TCP SYN and UDP packets
  UFW_SYN_BLOCK_REGEX="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ kernel: \[UFW BLOCK\] IN=[[:alnum:]]+ OUT= MAC=[:[:xdigit:]]+ SRC=[.[:digit:]]{7,15} DST=[.[:digit:]]{7,15} LEN=[[:digit:]]+ TOS=0x[[:xdigit:]]+ PREC=0x[[:xdigit:]]+ TTL=[[:digit:]]+ ID=[[:digit:]]+ (DF )?PROTO=TCP SPT=[[:digit:]]+ DPT=[[:digit:]]+ WINDOW=[[:digit:]]+ RES=0x[[:xdigit:]]+ SYN URGP=[[:digit:]]+$"
  UFW_UDP_BLOCK_REGEX="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ kernel: \[UFW BLOCK\] IN=[[:alnum:]]+ OUT= MAC=[:[:xdigit:]]+ SRC=[.[:digit:]]{7,15} DST=[.[:digit:]]{7,15} LEN=[[:digit:]]+ TOS=0x[[:xdigit:]]+ PREC=0x[[:xdigit:]]+ TTL=[[:digit:]]+ ID=[[:digit:]]+ (DF )?PROTO=UDP SPT=[[:digit:]]+ DPT=[[:digit:]]+ LEN=[[:digit:]]+$"
  echo "# UFW BLOCK messages" >> /etc/logcheck/ignore.d.server/local
  echo $UFW_SYN_BLOCK_REGEX >> /etc/logcheck/ignore.d.server/local
  echo $UFW_UDP_BLOCK_REGEX >> /etc/logcheck/ignore.d.server/local

  # Ignore dhcpcd messages
  DHCPCD_RENEWING="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ dhcpcd\[[[:digit:]]+\]: [[:alnum:]]+: renewing lease of [.[:digit:]]{7,15}$"
  DHCPCD_LEASED="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ dhcpcd\[[[:digit:]]+\]: [[:alnum:]]+: leased [.[:digit:]]{7,15} for [[:digit:]]+ seconds$"
  DHCPCD_ADDING_IP="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ dhcpcd\[[[:digit:]]+\]: [[:alnum:]]+: adding IP address [.[:digit:]]{7,15}/[[:digit:]]+$"
  DHCPCD_ADDING_DEFAULT_ROUTE="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ dhcpcd\[[[:digit:]]+\]: [[:alnum:]]+: adding default route via [.[:digit:]]{7,15} metric [0-9]+$"
  DHCPCD_INTERFACE_CONFIGURED="^\w{3} [ :[:digit:]]{11} [._[:alnum:]-]+ dhcpcd\.sh: interface [[:alnum:]]+ has been configured with old IP=[.[:digit:]]{7,15}$"
  # Ignore ntpd messages
  NTPD_VALIDATING_PEER="^\w{3} [ :0-9]{11} [._[:alnum:]-]+ ntpd\[[0-9]+\]: peer [.[:digit:]]{7,15} now (in)?valid$"
  echo "# DHCPCD messages" >> /etc/logcheck/ignore.d.server/local
  echo $DHCPCD_RENEWING >> /etc/logcheck/ignore.d.server/local
  echo $DHCPCD_LEASED >> /etc/logcheck/ignore.d.server/local
  echo $DHCPCD_ADDING_IP >> /etc/logcheck/ignore.d.server/local
  echo $DHCPCD_ADDING_DEFAULT_ROUTE >> /etc/logcheck/ignore.d.server/local
  echo $DHCPCD_INTERFACE_CONFIGURED >> /etc/logcheck/ignore.d.server/local
  echo "# NTPD messages" >> /etc/logcheck/ignore.d.server/local
  echo $NTPD_VALIDATING_PEER >> /etc/logcheck/ignore.d.server/local
}