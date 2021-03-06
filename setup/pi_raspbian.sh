#!/bin/bash -x

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

user_groups=("docker")
default_groups=($(groups "${default_user}" | tr -d ":"))
for i in "${default_groups[@]}"; do
	if [[ "${i}" != "${default_user}" ]]; then
		user_groups+=(${i})
	fi
done

echo "Creating user..." # Done first because it's interactive
groupadd "docker"
useradd -G `echo "${user_groups[@]}" | tr -s " " ","` "${user}"
passwd "${user}"

echo "Updating and installing packages..."
apt-get -y update
apt-get -y install \
	dnsutils \
	git \
	zsh \
	vim \
	screen
curl -sSL https://get.docker.com | sh

echo "Configuring raspberry pi..."
raspi-config nonint do_hostname "${hostname}"
raspi-config nonint do_ssh 0

echo "Setting kernel cmdline parameters..."
cmdline="/boot/cmdline.txt"
chmod u+w "${cmdline}"
sed -i -e "s/rootwait/cgroup_memory=1 cgroup_enable=memory rootwait/" "${cmdline}"

echo "Setting up workspace..."
mv "/home/${default_user}/.profile" "${home}/"
mv "/home/${default_user}/.bashrc" "${home}/"
git clone "https://github.com/subtlepseudonym/dotfiles" "${home}/dotfiles"
chown -R "${user}:${user}" "${home}"
/usr/bin/sudo -H -u ${user} ${home}/dotfiles/setup/install --exclude go --exclude macos --exclude nvm
chsh -s /usr/bin/zsh "${user}"

echo "Creating cleanup script..."
cleanup="${home}/cleanup.sh"
echo "#!/bin/bash -x" >> "${cleanup}"
echo "userdel ${default_user}" >> "${cleanup}"
echo "rm -rf /home/${default_user}" >> "${cleanup}"
echo "rm -rf ${home}/dotfiles" >> "${cleanup}"
echo "rm ${home}/dotfile_install.log" >> "${cleanup}"
echo "apt-get autoremove" >> "${cleanup}"
chmod u+x "${cleanup}"

echo "Rebooting in 10 seconds..."
sleep "10s"
reboot
