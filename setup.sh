#!/bin/bash

echo_label() {
	echo && echo "Installing $1" && echo "---" && echo
}

install_standard() {
	echo_label "standard tools"

	mkdir -p $HOME/Developer
	touch $$HOME/.commonrc

	sudo apt update && sudo apt install -y \
		htop \
		vim \
		# jq \
		git
}

install_vscode() {
	echo_label "VSCode"

	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
	rm packages.microsoft.gpg 
	sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

	sudo apt install apt-transport-https
	sudo apt update
	sudo apt install code # or code-insiders
}

install_speedtest() {
	echo_label "speedtest"

	sudo apt install -y gnupg1 apt-transport-https dirmngr
	export INSTALL_KEY=379CE192D401AB61
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
	echo "deb https://ookla.bintray.com/debian generic main" | sudo tee  /etc/apt/sources.list.d/speedtest.list
	sudo apt update

	# Other non-official binaries will conflict with Speedtest CLI
	# Example how to remove using apt-get
	# sudo apt remove speedtest-cli
	sudo apt install -y speedtest
}

install_fish() {
	echo_label "fish shell"

	sudo apt-add-repository -y ppa:fish-shell/release-3
	sudo apt update && sudo apt install -y fish
	echo && echo "Enter the password for current user '$USER' to change shell to 'fish'"
	chsh -s /usr/bin/fish

	FISH=$HOME/.config/fish
	mkdir -p $FISH
	touch $FISH/config.fish
	touch $HOME/.commonrc

	SOURCE_CMD="/bin/bash -c 'source $HOME/.commonrc'"
	if ! grep -q $SOURCE_CMD $FISH/config.fish; then
		echo $SOURCE_CMD >> $FISH/config.fish
	fi

	unset FISH
}

install_zsh() {
	echo_label "zsh"

	sudo apt update && sudo apt install -y zsh

	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	# echo && echo "Enter the password for current user '$USER' to change shell to 'Zsh'"
	# chsh -s $(which zsh)

	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	sed -i -E "s/(^plugins=.*)\)/\1 zsh-autosuggestions)/g" $HOME/.zshrc
}

install_telegram() {
	echo_label "Telegram"

	sudo apt update && sudo apt install -y telegram-desktop
}

install_virtualbox() {
	echo_label "Virtualbox"

	# Switch to Method 3 here for latest: https://itsfoss.com/install-virtualbox-ubuntu/
	sudo apt update && sudo apt install -y virtualbox
}

install_1password() {
	echo_label "1password"

	sudo apt-key --keyring /usr/share/keyrings/1password.gpg adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian edge main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update && sudo apt install -y 1password
}

install_sensors() {
	echo_label "sensors"

	sudo apt update && sudo apt install -y lm-sensors hddtemp
	sudo sensors-detect

	sudo apt install -y psensor
}

install_docker() {
	# Guide at: https://docs.docker.com/engine/install/ubuntu/
	echo_label "Docker"

	# Remove any earlier versions
	sudo apt remove docker docker-engine docker.io containerd runc

	sudo apt update && sudo apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg-agent \
		software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	# Check for fetched key (https://docs.docker.com/engine/install/ubuntu/)
	sudo apt-key fingerprint 0EBFCD88

	sudo add-apt-repository -y \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) \
		stable"

	sudo apt update && sudo apt install -y \
		docker-ce \
		docker-ce-cli \
		containerd.io

	echo && echo "Finished installing Docker, testing with 'hello world'..."
	sudo docker run hello-world
}

install_pyenv() {
	echo_label "pyenv"

	sudo apt update && sudo apt install -y \
		make build-essential libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev \
		libxml2-dev libxmlsec1-dev
		# libncursesw5-dev python-openssl

	# Log script for manual double-check, optionally break function
	# -> see 'https://github.com/pyenv/pyenv-installer' for script
	SCRIPT="https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer"

	PARENT_SCRIPT="https://pyenv.run"
	echo && echo "Checking \$SCRIPT against parent script..."
	if curl -s $PARENT_SCRIPT | grep -q $SCRIPT; then
		echo "Check passed!"
		echo
	else
		echo "Check failed, re-check and correct in script"
		echo
		echo "Exiting 'pyenv' install..."
		echo
		return 1
	fi

	echo "Fetching install script for check before running from '$SCRIPT'" && echo
	echo
	SEP="================================"
	echo $SEP
	curl -L $SCRIPT
	echo $SEP
	echo
	read -p "Does script look ok to continue? (Y/n): " RESP
	echo
	if [[ $RESP == 'Y' ]] || [[ $RESP == 'y' ]]
	then
		echo "Starting 'pyenv' install"
	else
		echo "Skipping rest of 'pyenv' install"
		echo
		return 1
	fi

	# Proceed with pyenv install
	if ! command -v pyenv >/dev/null 2>&1
	then
		curl -L $SCRIPT | bash && \
		cat << 'EOF' >> $HOME/.commonrc 

# For pyenv
# Comment one of the following blocks

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# if echo $SHELL | grep -q "/fish"
# 	set -x PATH "$HOME/.pyenv/bin" $PATH
# 	status --is-interactive; and . (pyenv init -|psub)
# 	status --is-interactive; and . (pyenv virtualenv-init -|psub)
# end
EOF

		echo "Reset shell to complete:"
		echo "\$ exec \"\$SHELL\""
		echo
	else
		echo "'pyenv' already installed"
	fi

	# Print instructions to install Python
	echo
	echo "Run the following next steps to install Python:"
	echo "$ pyenv install --list | grep \" 3\.\""
	echo "$ pyenv install -v <version>"

	# Add IPython manual fix note, can be removed after new IPython release
	echo
	echo "Note: IPython 7.19.0 has a tab autocompletion bug that is fixed by doing this: https://github.com/ipython/ipython/issues/12745#issuecomment-751892538"
	echo
}

test_lines() {
	cat << 'EOF' >> $HOME/.commonrc 

# For pyenv
# Comment one of the following blocks

# if echo $SHELL | grep -q "/bash"
# then
# 	export PATH="$HOME/.pyenv/bin:$PATH"
# 	eval "$(pyenv init -)"
# 	eval "$(pyenv virtualenv-init -)"
# fi

if echo $SHELL | grep -q "/fish"
	set -x PATH "$HOME/.pyenv/bin" $PATH
	status --is-interactive; and . (pyenv init -|psub)
	status --is-interactive; and . (pyenv virtualenv-init -|psub)
end
EOF

}

install_yubikey() {
	# Followed guide at: https://blog.programster.org/yubikey-link-with-gpg
	echo_label "Yubikey dependencies"

	sudo apt update && sudo apt install -y \
		pcscd \
		scdaemon \
		gnupg2
		# pcsc-tools
}

configure_git() {
	echo_label "git configuration"

	git config --global user.name "vindard"
	git config --global user.email "17693119+vindard@users.noreply.github.com"

	echo
	echo "To import 'hot' signing keys fetch the following file and run:"
	echo "$ gpg --decrypt 8F95D90A-priv_subkeys-GHonly.gpg.asc | gpg --import"
	echo "$ git config --global user.signingkey 1B005D838F95D90A"
}

add_ed25519_ssh_key() {
	echo_label "new ed25519 SSH keypair"

	ssh-keygen -o -a 100 -t ed25519
}


# Run the installs

# install_standard
# install_vscode
# install_speedtest
# install_fish
# install_zsh
# install_telegram
# install_virtualbox
# install_1password
# install_sensors
# install_docker
# install_pyenv
# install_yubikey
# configure_git
# add_ed25519_ssh_key

# test_lines
