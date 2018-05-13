#! /bin/bash

# disable SELinux
setenforce 0

# package update
yum -y update || exit 1
WILL_NOT_REBOOT=@@@noreboot@@@

if [ -z ${WILL_NOT_REBOOT} ]; then
    WILL_NOT_REBOOT="0"
fi

if [ ${WILL_NOT_REBOOT} != "1" ];then
  echo "rebooting..."
  sh -c 'sleep 10; reboot' &
fi

# allow only members of the wheel group to use 'su'
cp /etc/pam.d/su /etc/pam.d/su.bak
## uncomment 'auth required pam_wheel.so use_uid'
tac /etc/pam.d/su > /etc/pam.d/su.tmp
cat << EOS >> /etc/pam.d/su.tmp 2>&1
auth required pam_wheel.so use_uid
EOS
tac /etc/pam.d/su.tmp > /etc/pam.d/su
rm -rf /etc/pam.d/su.tmp

## restrict the use of 'su' command
cp /etc/login.defs /etc/login.defs.bak
cat << EOS >> /etc/login.defs
SU_WHEEL_ONLY yes
EOS

## 'sudo' command without password
cp /etc/sudoers /etc/sudoers.bak
cat << EOS >> /etc/sudoers 2>&1
%wheel ALL=(ALL) NOPASSWD: ALL
EOS

# disallow SSH login and add public_key
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat << EOS >> /etc/ssh/sshd_config 2>&1
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
AuthorizedKeysFile .ssh/authorized_keys
EOS

# sshd service restart
systemctl restart sshd

# make skel directories
mkdir /etc/skel/.ssh
mkdir /etc/skel/public_html

# setup zshrc
chsh /bin/zsh
mv zshrc ../.zshrc
source ~/.zshrc
cp ~/.zshrc /etc/skel/.zshrc

# Change useradd options
useradd -D -s /bin/zsh

#Install httpd,mariadb,php7
echo "Install httpd,mariadb,php7"
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm || exit 1

yum -y install httpd mariadb mariadb-server expect || exit 1
yum -y install --enablerepo=remi,remi-php70 php php-devel php-mbstring php-pdo php-gd php-mysql || exit 1

#firewall
firewall-cmd --add-service=http --permanent --zone=public
firewall-cmd --add-service=https --permanent --zone=public
firewall-cmd --reload


#Start services
systemctl enable mariadb.service || exit 1
systemctl start mariadb.service || exit 1

systemctl enable httpd.service || exit 1
systemctl start httpd.service || exit 1

# setup ruby
echo "setup ruby"
yum install -y openssl-devel  >/dev/null 2>&1
yum install -y zlib-devel     >/dev/null 2>&1
yum install -y readline-devel >/dev/null 2>&1
yum install -y libyaml-devel  >/dev/null 2>&1
yum install -y libffi-devel   >/dev/null 2>&1

git clone https://github.com/sstephenson/rbenv.git      /etc/skel/.rbenv                    >/dev/null 2>&1
git clone https://github.com/sstephenson/ruby-build.git /etc/skel/.rbenv/plugins/ruby-build >/dev/null 2>&1


# reboot
echo "rebooting..."
sh -c 'sleep 10; reboot' &

echo "startup script finish"

exit 0
