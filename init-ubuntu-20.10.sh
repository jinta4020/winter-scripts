#!/bin/bash -eu

<<COMMENT
Ubuntu 20.10 init script
Jinta
COMMENT

function ask_yes_no {
  while true; do
    echo -n "$* [y/n]: "
    read ANS
    case $ANS in
      [Yy]*)
        return 0
        ;;  
      [Nn]*)
        return 1
        ;;
      *)
        echo "Enter y/n ."
        ;;
    esac
  done
}

echo "Running built-winter Ubuntu 20.10 ..."

apt=$(ps aux | grep apt | grep -v 'grep')
if [ $apt ]; then
  exit 1
fi

read -p "Enter your username [worker]: " username
username=${username:-worker}
read -p "Enter your SSH port [22]: " port
port=${port:-22}

password=$(more /dev/urandom | tr -d -c '[:alnum:]' | fold -w 12 | head -1)
echo "Save your password."
echo "${password}"
read Wait

echo "Updating packages in Ubuntu ..."
apt-get -y update
apt-get -y upgrade

adduser -q --gecos "" --disabled-login "${username}"
echo "${username}:${password}" | chpasswd
gpasswd -a "${username}" sudo

# sshdの設定
sed -i -e "s|#Port 22|Port ${port}|" /etc/ssh/sshd_config
sed -i -e "s|PermitRootLogin yes|PermitRootLogin no|" /etc/ssh/sshd_config
sed -i -e "s|#PasswordAuthentication yes|PasswordAuthentication no|" /etc/ssh/sshd_config
sed -i -e "s|UsePAM yes|UsePAM no|" /etc/ssh/sshd_config

# ファイアウォールの設定
apt-get install ufw
sed -i -e "s|IPV6=yes|IPV6=no|" /etc/default/ufw
ufw allow "${port}"
ufw default deny

# 秘密鍵の生成
if ask_yes_no "Set passphrase to the key?"; then
  passphrase=$(more /dev/urandom | tr -d -c '[:alnum:]' | fold -w 12 | head -1)
  sudo -u "${username}" ssh-keygen -b 4096 -t rsa -f /home/"${username}"/.ssh/id_rsa -q -N "" -C "${username}-key" -N "${passphrase}"
  echo "Save your passphrase."
  echo "${passphrase}"
  read Wait
else
  sudo -u "${username}" ssh-keygen -b 4096 -t rsa -f /home/"${username}"/.ssh/id_rsa -q -N "" -C "${username}-key"
fi

echo "Save your public key."
sudo -u "${username}" cat /home/"${username}"/.ssh/id_rsa.pub
read Wait

echo "Save your secret key."
sudo -u "${username}" cat /home/"${username}"/.ssh/id_rsa
read Wait
sudo -u "${username}" rm /home/"${username}"/.ssh/id_rsa

sudo -u "${username}" mv -f /home/"${username}"/.ssh/id_rsa.pub /home/"${username}"/.ssh/authorized_keys
sudo -u "${username}" chmod 600 /home/"${username}"/.ssh/authorized_keys
sudo -u "${username}" chmod 700 /home/"${username}"/.ssh

echo "Restarting bash ..."
service ssh restart
echo "y" | ufw enable
reboot
