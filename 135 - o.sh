#!/bin/bash
#
# <UDF name="notify_email" Label="Send email notification to" example="Email address to send notification and system alerts." />

# <UDF name="user_name" label="Unprivileged user account name" example="This is the account that you will be using to log in." />
# <UDF name="user_password" label="Unprivileged user password" />
# <UDF name="user_sshkey" label="Public Key for user" default="" example="Recommended method of authentication. It is more secure than password log in." />
# <UDF name="sshd_passwordauth" label="Use SSH password authentication" oneof="Yes,No" default="No" example="Turn off password authentication if you have added a Public Key." />
# <UDF name="sshd_permitrootlogin" label="Permit SSH root login" oneof="No,Yes" default="No" example="Root account should not be exposed." />
# <UDF name="user_shell" label="Shell" oneof="/bin/zsh,/bin/bash" default="/bin/bash" />
# <UDF name="sys_hostname" label="System hostname" default="myvps" example="Name of your server, i.e. linode1." />
# <UDF name="sys_private_ip" Label="Private IP" default="" example="Configure network card to listen on this Private IP (if enabled in Linode/Remote Access settings tab). See http://library.linode.com/networking/configuring-static-ip-interfaces" />
# <UDF name="setup_monit" label="Install Monit system monitoring?" oneof="Yes,No" default="Yes" />
set -e
set -u

USER_GROUPS=sudo

exec &> /root/stackscript.log

source <ssinclude StackScriptID="1"> # StackScript Bash Library
system_update

source <ssinclude StackScriptID="124"> # lib-system
system_install_mercurial
system_start_etc_dir_versioning #start recording changes of /etc config files

# Configure system
source <ssinclude StackScriptID="123"> # lib-system-ubuntu
system_update_hostname "$SYS_HOSTNAME"
system_record_etc_dir_changes "Updated hostname" # SS124
source <ssinclude StackScriptID="132"> # extras

# Create user account
system_add_user "$USER_NAME" "$USER_PASSWORD" "$USER_GROUPS" "$USER_SHELL"
if [ "$USER_SSHKEY" ]; then
    system_user_add_ssh_key "$USER_NAME" "$USER_SSHKEY"
fi
system_record_etc_dir_changes "Added unprivileged user account" # SS124

# Configure sshd
system_sshd_permitrootlogin "$SSHD_PERMITROOTLOGIN"
system_sshd_passwordauthentication "$SSHD_PASSWORDAUTH"
touch /tmp/restart-ssh
system_record_etc_dir_changes "Configured sshd" # SS124


lock_users #SS132

# Install Postfix
postfix_install_loopback_only # SS1
system_record_etc_dir_changes "Installed postfix loopback" # SS124

# Setup logcheck
system_security_logcheck
system_record_etc_dir_changes "Installed logcheck" # SS124

# Setup fail2ban
system_security_fail2ban
system_record_etc_dir_changes "Installed fail2ban" # SS124

# Setup firewall
system_security_ufw_configure_basic
system_record_etc_dir_changes "Configured UFW" # SS124

source <ssinclude StackScriptID="126"> # lib-python
python_install
system_record_etc_dir_changes "Installed python" # SS124

# lib-system - SS124
system_install_utils
system_install_build
system_install_subversion
system_install_git
system_record_etc_dir_changes "Installed common utils"

function system_install_lighttpd {

aptitude install -y lighttpd pound php5-fpm php5-cli php5-curl php5-gd php-pear php5-imap php5-mcrypt php5-memcache php5-ps php5-pspell php5-recode php5-snmp php5-tidy php5-xmlrpc php5-xsl php5-common php5-mysql php-apc

find /etc/php5/ ! -regex ".*[/]\.svn[/]?.*" -type f -name php.ini -exec sed -i'.origs' -e 's/memory_limit = [0-9]\+M/memory_limit = 40M/' -e 's/max_execution_time = [0-9]\+/max_execution_time = 30/' -e 's/upload_max_filesize = [0-9]\+M/upload_max_filesize = 2M/' -e 's/post_max_size = [0-9]\+M/post_max_size = 4M/' -e 's/max_input_time = [0-9]\+/max_input_time = 30/' -e 's/short_open_tag = On/short_open_tag = Off/' -e 's/disable_functions = /disable_functions = exec,passthru,shell_exec,system,proc_open,popen,curl_exec,curl_multi_exec,parse_ini_file,show_source,dl,/' -e 's/expose_php = On/expose_php = Off/' -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=1/' -e 's/;cgi.force_redirect = 1/cgi.force_redirect = 1/' -e 's/;arg_separator.output/arg_separator.output/' -e 's/;date.timezone =/date.timezone = UTC/' -e 's/session.name = PHPSESSID/session.name = SESSID/' -e 's/allow_url_fopen = On/allow_url_fopen = Off/' -e's/sql.safe_mode = Off/sql.safe_mode = On/' -e 's@;error_log = syslog@error_log = /var/log/php/error.log@' -e 's@;open_basedir =@;open_basedir =/var/www/@' -e 's@;session.save_path = "/tmp"@session.save_path = "/var/lib/php/session"@' -e 's@;upload_tmp_dir =@upload_tmp_dir ="/var/lib/php/session"@'{} \;

sed -i'.origs' -e 's/;listen.owner = www-data/listen.owner = www-data/' -e 's/;listen.group = www-data/listen.group = www-data/' -e 's/;listen.mode = 0666/listen.mode = 0600/' -e 's/pm.max_children = 50/pm.max_children = 12/' -e 's/pm.start_servers = 20/pm.start_servers = 4/' -e 's/pm.min_spare_servers = 5/pm.min_spare_servers = 2/' -e 's/pm.max_spare_servers = 35/pm.max_spare_servers = 4/' -e 's/pm.max_requests = 0/pm.max_requests = 500/' /etc/php5/fpm/pool.d/www.conf

sed -i 's/#/;/' /etc/php5/conf.d/mcrypt.ini

lighty-enable-mod fastcgi
lighty-enable-mod fastcgi-php
service lighttpd force-reload

echo "<?php phpinfo(); ?>" >> /var/www/info.php

mkdir -p /var/log/php/
chown -R www-data:www-data /var/log/php/
mkdir -p /var/lib/php/session/
chown -R www-data:www-data /var/lib/php/session/

service php5-fpm start
chown -R www-data:www-data /var/www/
chmod -R 0444 /var/www/
find /var/www/ -type d -print0 | xargs -0 -I {} chmod 0445 {}
}




