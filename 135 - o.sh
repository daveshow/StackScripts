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
# <UDF name="setup_mongodb" label="Install mongodb ?" oneof="Yes,No" default="No" />
set -e
set -u
#
USER_GROUPS=sudo
#
exec &> /root/stackscript.log
#
source <ssinclude StackScriptID="1"> # StackScript Bash Library
source <ssinclude StackScriptID="124"> # lib-system
source <ssinclude StackScriptID="123"> # lib-system-ubuntu
source <ssinclude StackScriptID="132"> # extras
source <ssinclude StackScriptID="126"> # lib-python
system_update
create_sys_backup
#
system_install_mercurial
system_start_etc_dir_versioning #start recording changes of /etc config files
#
# Configure system
system_update_hostname "$SYS_HOSTNAME"
system_record_etc_dir_changes "Updated hostname" # SS124
#
if [ !-f /etc/ssh/sshd_config ];then
install_ssh
system_record_etc_dir_changes "installing openssh if not installed" # SS124
fi
# Create user account
system_add_user "$USER_NAME" "$USER_PASSWORD" "$USER_GROUPS" "$USER_SHELL"
if [ "$USER_SSHKEY" ]; then
    system_user_add_ssh_key "$USER_NAME" "$USER_SSHKEY"
fi
system_record_etc_dir_changes "Added unprivileged user account" # SS124
#
# Configure sshd
system_sshd_permitrootlogin "$SSHD_PERMITROOTLOGIN"
system_sshd_passwordauthentication "$SSHD_PASSWORDAUTH"
touch /tmp/restart-ssh
system_record_etc_dir_changes "Configured sshd" # SS124
if [ "SSHD_PERMITROOTLOGIN" == "No" ]; then
    system_lock_user "root"
    system_record_etc_dir_changes "Locked root account" # SS124
fi
lock_users #SS132
system_record_etc_dir_changes "Locked up users"
#
apache_install
system_record_etc_dir_changes "Installed apache"
#
apache_tune 25
system_record_etc_dir_changes "apache tune 25% of sys mem "
#
apache_virtualhost_from_rdns
system_record_etc_dir_changes "create virtual from rdns "
#
goodstuff
system_record_etc_dir_changes "installing the good stuff "
#
system_install_lighttpd
system_record_etc_dir_changes "Installed lighttpd and php config"
#
install_security
system_record_etc_dir_changes "Installing chkroot and rkhunter and lowatch utils"
#
install_tools
system_record_etc_dir_changes "Installing nessarry tools install vim less logrotate lynx mytop nmap screen sqlite3 cron-apt ntp curl"
#
# Install Postfix
postfix_install_loopback_only # SS1
system_record_etc_dir_changes "Installed postfix loopback" # SS124
#
# Setup logcheck
system_security_logcheck
system_record_etc_dir_changes "Installed logcheck" # SS124
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
#
# lib-system - SS124
system_install_utils
system_install_build
system_install_subversion
system_install_git
system_record_etc_dir_changes "Installed common utils"
restartServices
#