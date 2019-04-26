#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "This script must be run as root"
	exit 1
fi

if [[ $# -ne 2 ]]; then
	echo "usage: setup.sh HOSTNAME USER"
	exit 1
fi

hostname="$1"
user="$2"

default_user="pi"
home="/home/${user}"
workspace="${home}/workspace"

user_groups=()
default_groups=($(groups "${default_user}" | tr -d ":"))
for i in "${default_groups[@]}"; do
	if [[ "${i}" != "${default_user}" ]]; then
		user_groups+=(${i})
	fi
done

echo "Creating user..." # Done first because it's interactive
groupadd "docker"
useradd -G `echo "${user_groups[@]} docker" | tr -s " " ","` "${user}"
passwd "${user}"

echo "Updating and installing packages..."
apt-get -y update
apt-get -y install \
	git \
	zsh \
	vim
curl -sSL https://get.docker.com | sh

echo "Configuring raspberry pi..."
raspi-config nonint do_hostname "${hostname}"
raspi-config nonint do_ssh 0

echo "Creating workspace..."
mkdir -p "${workspace}/git" "${workspace}/volumes" "${workspace}/scripts"
mv "/home/${default_user}/.profile" "${home}"
mv "/home/${default_user}/.bashrc" "${home}"
chown -R "${user}:${user}" "${home}"

echo "Setting up oh-my-zsh..."
NO_INTERACTIVE=true su -l "${user}" -c "$(curl -fsSL https://raw.githubusercontent.com/subtlepseudonym/oh-my-zsh/feature/install-noninteractive/tools/install.sh)"
chsh -s /usr/bin/zsh "${user}"
git clone "https://github.com/subtlepseudonym/loki-theme.git" "${workspace}/git/loki-theme"
mv `find "${workspace}/git/loki-theme" -name "*\.zsh*"` "${home}/.oh-my-zsh/custom/"
git clone "https://github.com/subtlepseudonym/dotfiles.git" "${workspace}/git/dotfiles"
mv "${workspace}/git/dotfiles/vimrc" "${home}/.vimrc"
mv "${workspace}/git/dotfiles/zsh/zprofile" "${home}/.zprofile"
mv "${workspace}/git/dotfiles/zsh/zshrc" "${home}/.zshrc"
sed -i "s/home\/loki/home\/${user}/g" "${home}/.zshrc"
chown -R "${user}:${user}" "${home}"

echo "Creating cleanup script..."
echo "userdel ${default_user} && \
rm -rf /home/${default_user} && \
rm -rf ${workspace}/git/loki-theme ${workspace}/git/dotfiles && \
apt-get autoremove" >> "${home}/cleanup.sh"
chmod u+x "${home}/cleanup.sh"

echo "Rebooting in 10 seconds..."
sleep "10s"
reboot
