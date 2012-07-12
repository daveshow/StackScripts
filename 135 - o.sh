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
# <UDF name="notify_email" Label="Send email notification to" example="Email address to send notification and system alerts." />
# <UDF name="user_name" label="Unprivileged user account name" example="This is the account that you will be using to log in." />
# <UDF name="user_password" label="Unprivileged user password" />
# <UDF name="user_sshkey" label="Public Key for user" default="" example="Recommended method of authentication. It is more secure than password log in." />
# <UDF name="sshd_permitrootlogin" label="Permit SSH root login" oneof="No,Yes" default="No" example="Root account should not be exposed." />
# <udf name="sshd_group" label="SSH Allowed Groups" default="sshusers" example="List of groups seperated by spaces" />
# <UDF name="user_shell" label="Shell" oneof="/bin/zsh,/bin/bash" default="/bin/bash" />
# <UDF name="sys_hostname" label="System hostname" default="myvps" example="Name of your server, i.e. linode1." />
# <UDF name="setup_mysql" label="Configure MySQL and create database?" oneof="Yes,No" default="No" />
# <UDF name="mysql_database_password" label="MySQL root Password" default="" />
# <UDF name="mysql_database" label="MySQL database name" example="MySQL database name, ASCII only." default="" />
# <UDF name="mysql_user" label="MySQL database user" example="MySQL database user name, ASCII only." default="" />
# <UDF name="mysql_password" label="MySQL user password" default="" />
# <UDF name="setup_monit" label="Install Monit system monitoring?" oneof="Yes,No" default="Yes" />
# <UDF name="setup_mongodb" label="Install mongodb ?" oneof="Yes,No" default="No" />
# <UDF name="setup_apache" label="Install apache ?" oneof="Yes,No" default="No" />
# <UDF name="setup_lighttpd" label="Install lighttpd ?" oneof="Yes,No" default="No" />
#
#
set -e
set -u
#
USER_GROUPS=sudo
groupadd -r "$SSHD_GROUP"
#
exec &> /root/stackscript.log
#
source <ssinclude StackScriptID="1"> # StackScript Bash Library
source <ssinclude StackScriptID="123"> # lib-system-ubuntu
source <ssinclude StackScriptID="132"> # extras
source <ssinclude StackScriptID="126"> # lib-python
#
if [ -z $USER_PASSWORD ]; then USER_PASSWORD=$(urandomString); USER_PASSWORD_BLANK="1"; fi
if [ -z $MYSQL_DATABASE_PASSWORD ]; then MYSQL_DATABASE_PASSWORD=$(urandomString); MYSQL_DATABASE_PASSWORD_BLANK="1"; fi
if [ -z $MYSQL_PASSWORD ]; then MYSQL_PASSWORD=$(urandomString); MYSQL_PASSWORD_BLANK="1"; fi
#
system_locale_en_US_UTF_8
set_timezone "America/New_York"
system_update
create_sys_backup
#
system_install_mercurial
system_start_etc_dir_versioning #start recording changes of /etc config files
#
system_ignore_files
system_apt_snapsshot
system_record_etc_dir_changes "adding in apt snapshot for backuping up before installing apt deb files"
#
# Configure system
system_update_hostname "$SYS_HOSTNAME"
system_record_etc_dir_changes "Updated hostname" # SS124
#
if [ ! -f /etc/ssh/sshd_config ];then
install_ssh
system_record_etc_dir_changes "installing openssh if not installed" # SS124
fi
# Create user account
system_add_user "$USER_NAME" "$USER_PASSWORD" "$USER_GROUPS,$SSHD_GROUP" "$USER_SHELL"
if [ "$USER_SSHKEY" ]; then
    system_user_add_ssh_key "$USER_NAME" "$USER_SSHKEY"
fi
system_record_etc_dir_changes "Added unprivileged user account" # SS124
#
# Configure sshd
system_sshd_permitrootlogin "$SSHD_PERMITROOTLOGIN"
system_sshd_edit_bool "UseDNS" "No"
if [ "$USER_SSHKEY" != "" ]; then
system_sshd_passwordauthentication "No"
fi
echo "AllowGroups `echo $SSHD_GROUP | tr '[:upper:]' '[:lower:]'`" >> /etc/ssh/sshd_config
touch /tmp/restart-ssh
system_record_etc_dir_changes "Configured sshd" # SS124
if [ "SSHD_PERMITROOTLOGIN" == "No" ]; then
    system_lock_user "root"
    system_record_etc_dir_changes "Locked root account" # SS124
fi
lock_users #SS132
system_record_etc_dir_changes "Locked up users"
#
# Install Postfix
postfix_install_loopback_only # SS1
system_record_etc_dir_changes "Installed postfix loopback" # SS124
#
if [ "$SETUP_APACHE" == "Yes" ]; then
apache_install
system_record_etc_dir_changes "Installed apache"
#
apache_tune 15
system_record_etc_dir_changes "apache tune 15% of sys mem "
#
if [ -z $(get_rdns_primary_ip) ]; then
apache_virtualhost "$SYS_HOSTNAME"
system_record_etc_dir_changes "create virtual from sysname "
else 
apache_virtualhost_from_rdns
system_record_etc_dir_changes "create virtual from rdns "
fi
#
php_install_with_apache
system_record_etc_dir_changes "Installing PHP for apache"
fi
goodstuff
config_screen
system_record_etc_dir_changes "installing and configuring the good stuff "
#
if [ "$SETUP_LIGHTTPD" == "Yes" ]; then
system_install_lighttpd

system_record_etc_dir_changes "Installed lighttpd and pound"
fi
install_secure_php
system_record_etc_dir_changes "Installed php config"
#
#
install_security
system_record_etc_dir_changes "Installing chkroot and rkhunter and logwatch utils"
configure_chkrootkit
system_record_etc_dir_changes "Configured chkrootkit"
configure_rkhunter
system_record_etc_dir_changes "Configured rkhunter"
copy_logwatch
configure_logwatch
system_record_etc_dir_changes "Configured logwatch"
#
install_tools
system_record_etc_dir_changes "Installing nessarry tools install vim less logrotate lynx mytop nmap screen sqlite3 cron-apt ntp curl"
configure_cronapt
system_record_etc_dir_changes "Configured cronapt"
#
# Setup logcheck
system_security_logcheck
system_record_etc_dir_changes "Installed logcheck" # SS124
configure_logcheck
system_record_etc_dir_changes "Updated logcheck config" # SS124
#
# Setup fail2ban
system_security_fail2ban
system_record_etc_dir_changes "Installed fail2ban" # SS124
#
# Setup firewall
system_security_ufw_configure_basic
system_record_etc_dir_changes "Configured UFW" # SS124
#
python_install
system_record_etc_dir_changes "Installed python" # SS124
if [ "$SETUP_MYSQL" == "Yes" ]; then
    set +u # ignore undefined variables in Linode's SS1
    mysql_install "$MYSQL_DATABASE_PASSWORD" && mysql_tune 20
    mysql_create_database "$MYSQL_DATABASE_PASSWORD" "$MYSQL_DATABASE"
    mysql_create_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_PASSWORD"
    mysql_grant_user "$MYSQL_DATABASE_PASSWORD" "$MYSQL_USER" "$MYSQL_DATABASE"
    set -u
    system_record_etc_dir_changes "Configured MySQL"
fi
# Install MongoDB
if [ "$SETUP_MONGODB" == "Yes" ]; then
    source <ssinclude StackScriptID="128"> # lib-mongodb
    mongodb_install
    system_record_etc_dir_changes "Installed MongoDB"
fi
#
system_install_node
system_record_etc_dir_changes "Installing remote monitoring tools" # SS124
# lib-system - SS124
system_install_utils
system_install_build
system_install_subversion
system_install_git
system_record_etc_dir_changes "Installed common utils"

#
if [ "$SETUP_MONIT" == "Yes" ]; then
    source <ssinclude StackScriptID="129"> # lib-monit
    monit_install
    system_record_etc_dir_changes "Installed Monit"
#
    monit_configure_email "$NOTIFY_EMAIL"
    monit_configure_web $(system_primary_ip)
    system_record_etc_dir_changes "Configured Monit interfaces"
#
    monit_def_system "$SYS_HOSTNAME"
    monit_def_rootfs
    monit_def_cron
    monit_def_postfix
    monit_def_ping_google
	monit_def_sshd
    if [ "$SETUP_MONGODB" == "Yes" ]; then monit_def_mongodb; fi
    if [ "$SETUP_APACHE" == "Yes" ]; then monit_def_apache; fi
    if [ "$SETUP_MYSQL" == "Yes" ]; then monit_def_mysql; fi
	if [ "$SETUP_LIGHTTPD" == "Yes" ]; then monit_def_lighttpd; fi
    system_record_etc_dir_changes "Created Monit rules for installed services"
    monit reload
fi
#
restartServices
#
cat > ~/setup_message <<EOD
Hi,

Your Server configuration is completed.

EOD
if [ "$SETUP_MONIT" == "Yes" ]; then
    cat >> ~/setup_message <<EOD
Monit web interface is at http://$SYS_HOSTNAME:2812/ (use your system username/password).

EOD
fi
cat >> ~/setup_message <<EOD
To access your server ssh to $USER_NAME@$SYS_HOSTNAME

EOD
if [ "$USER_PASSWORD_BLANK" == "1" ]; then
cat >> ~/setup_message <<EOD
The user $USER_NAME password was not set so here your random password $USER_PASSWORD

EOD
if [ "$MYSQL_DATABASE_PASSWORD_BLANK" == "1" ]; then
cat >> ~/setup_message <<EOD
The Mysql password was not set so here your random admin password $MYSQL_DATABASE_PASSWORD

EOD
if [ "$MYSQL_PASSWORD_BLANK" == "1" ]; then
cat >> ~/setup_message <<EOD
The Mysql user password was not set so here your random password $MYSQL_PASSWORD

EOD
mail -s "Your Server is ready" "$NOTIFY_EMAIL" < ~/setup_message