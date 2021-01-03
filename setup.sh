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
	echo "/bin/bash -c 'source $HOME/.commonrc'" >> $FISH/config.fish
	unset FISH
}

install_telegram() {
	echo_label "Telegram"

	sudo apt update && sudo apt install -y telegram-desktop
}

install_virtualbox() {
	# Switch to Method 3 here for latest: https://itsfoss.com/install-virtualbox-ubuntu/
	sudo apt update && sudo apt install -y virtualbox
}

install_1password() {
	sudo apt-key --keyring /usr/share/keyrings/1password.gpg adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian edge main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update && sudo apt install -y 1password
}

install_sensors() {
	sudo apt update && sudo apt install -y lm-sensors hddtemp
	sudo sensors-detect

	sudo apt install -y psensor
}

install_pyenv() {
	sudo apt update && sudo apt install -y \
		make build-essential libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev \
		libxml2-dev libxmlsec1-dev
		# libncursesw5-dev python-openssl

	# Log script for manual double-check, optionally break function
	# -> see 'https://github.com/pyenv/pyenv-installer' for script
	SCRIPT="https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer"
	echo "Fetching install script for check before running from '$SCRIPT'" && echo
	curl -L $SCRIPT
	read -p "Does script look ok to continue? (Y/n): " RESP
	if [[ $RESP == 'Y' ]] || [[ $RESP == 'y' ]]
	then
		echo "Starting 'pyenv' install"
	else
		echo "Skipping rest of 'pyenv' install"
		return 1
	fi

	# Proceed with pyenv install
	if ! command -v pyenv >/dev/null 2>&1
	then
		curl -L $SCRIPT | bash && \
		cat <<- 'EOF' >> $HOME/.commonrc 

		# For pyenv
		export PATH="$HOME/.pyenv/bin:$PATH"
		eval "$(pyenv init -)"
		eval "$(pyenv virtualenv-init -)"

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
	cat <<- 'EOF' >> $HOME/.commonrc 

	# For pyenv
	export PATH="$HOME/.pyenv/bin:$PATH"
	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"

	EOF
}

configure_git() {
	git config --global user.name "vindard"
	git config --global user.email "17693119+vindard@users.noreply.github.com"
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
# install_telegram
# install_virtualbox
# install_1password
# install_sensors
install_pyenv
# configure_git
# add_ed25519_ssh_key

# test_lines

