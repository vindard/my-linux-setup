#!/bin/bash

check_dependency() {
	for cmd in "$@"; do
		if ! command -v $cmd >/dev/null 2>&1; then
			echo "This script requires \"${cmd}\" to be installed"
			return 1
		fi
	done
}

echo_label() {
	echo && echo "Installing $1" && echo "---" && echo
}

get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" | 	# Get latest release from GitHub api
		grep '"tag_name":' |                                            # Get tag line
		sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

install_standard() {
	echo_label "standard tools"

	mkdir -p $HOME/Developer
	touch $$HOME/.commonrc

	sudo apt update && sudo apt install -y \
		htop \
		vim \
		tree \
		jq \
		git \
		vnstat \
		tmux \
		nmap
}

install_snap() {
	echo_label "Snap"

	sudo apt update && sudo apt install -y snapd
	sudo snap install hello-world
}

install_flatpak() {
	echo_label "Flatpak"

	sudo add-apt-repository ppa:alexlarsson/flatpak
	sudo apt update && sudo apt install -y flatpak
}

install_vscode_apt() {
	# Note: on my Pop!OS system when the app updated itself
	#       via the Pop!_Shop it lost the 'code' binary
	#       in the terminal, so I switched to installing
	#       using Snap instead.

	echo_label "VS Code (via apt)"

	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
	rm packages.microsoft.gpg 
	sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

	sudo apt install apt-transport-https
	sudo apt update
	sudo apt install code # or code-insiders
}

install_vscode_snap() {
	echo_label "VS Code (via snap)"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install code --classic
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

install_signal() {
	echo_label "Signal Messenger"

	wget -O- https://updates.signal.org/desktop/apt/keys.asc \
		| sudo apt-key add -

	echo "deb [arch=amd64] https://updates.signal.org/desktop/apt xenial main" \
		| sudo tee -a /etc/apt/sources.list.d/signal-xenial.list

	sudo apt update && sudo apt install -y signal-desktop
}

install_virtualbox() {
	echo_label "Virtualbox"

	# Switch to Method 3 here for latest: https://itsfoss.com/install-virtualbox-ubuntu/
	sudo apt update && sudo apt install -y virtualbox
}

install_vmware() {
	echo_label "VMWare"

	sudo apt update && sudo apt install -y \
		build-essential

	mkdir -p $HOME/Downloads
	pushd $HOME/Downloads
	wget \
		--user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0" \
		https://www.vmware.com/go/getplayer-linux

	chmod +x getplayer-linux
	sudo ./getplayer-linux
	popd

	echo
	echo "Open VMWare and make sure setup is complete in the UI"
	echo "-----"
	echo
}

install_1password() {
	echo_label "1password"

	sudo apt-key --keyring /usr/share/keyrings/1password.gpg adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password.gpg] https://downloads.1password.com/linux/debian edge main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update && sudo apt install -y 1password
}

install_tor_browser() {
	echo_label "Tor Browser"

	# Guide: https://itsfoss.com/install-tar-browser-linux/
	if ! check_dependency flatpak
	then
		install_flatpak
	fi

	flatpak install -y flathub com.github.micahflee.torbrowser-launcher || \
		echo "If download was interrupted run: '$ flatpak repair --user'"

	flatpak run com.github.micahflee.torbrowser-launcher
}

install_obsidian() {
	echo_label "Obsidian"

	if ! check_dependency flatpak
	then
		install_flatpak
	fi

	flatpak install -y flathub md.obsidian.Obsidian || \
		echo "If download was interrupted run: '$ flatpak repair --user'"

	flatpak run md.obsidian.Obsidian
}

install_sensors() {
	echo_label "sensors"

	sudo apt update && sudo apt install -y lm-sensors hddtemp
	sudo sensors-detect

	sudo apt install -y psensor
}

install_docker_compose() {
	echo_label "Docker Compose"

	echo "Checking that Docker dependency is installed..."
	if ! command -v "docker"
	then
		echo "Docker not found, install first and then retry"
		return 1
	fi

	VERSION=$(get_latest_release "docker/compose")
	URL="https://github.com/docker/compose/releases/download/$VERSION/docker-compose-$(uname -s)-$(uname -m)"

	sudo curl -L $URL -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	docker-compose --version
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

	# Setup Docker permissions for local user
	echo
	echo "Setting up local user permissions for Docker..."
	sudo groupadd docker
	sudo usermod -aG docker ${USER}
	su ${USER}
	docker run hello-world

	# Install docker-compose
	install_docker_compose
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

install_thefuck() {
	if pip3 > /dev/null 2>&1
	then
		pip3 install thefuck
	else
		echo "Please install python3 and pip3 before trying to install 'thefuck'"
	fi
}

install_golang() {
	echo_label "GoLang"

	LATEST=$(REGEX=".*(go.*linux.*?gz).*"; curl -s https://golang.org/dl/ | grep -P $REGEX | sed -r "s/$REGEX/\1/" | head -n 1)

	VERSION=1.16
	ARCHITECTURE=linux-amd64
	GO_TARFILE=go$VERSION.$ARCHITECTURE.tar.gz

	echo "Installing '$GO_TARFILE' (latest is '$LATEST')"
	read -p "Continue? (Y/n): " RESP
	if ! [[ $RESP == 'Y' ]] && ! [[ $RESP == 'y' ]]; then
		echo "Skipping GoLang install..."
		return 1
	fi

	# Fetch tarfile
	DOWNLOAD_DIR=$HOME/Downloads
	mkdir -p $DOWNLOAD_DIR
	pushd $DOWNLOAD_DIR > /dev/null
	wget -c https://golang.org/dl/$GO_TARFILE

	SHA256SUM=$(sha256sum $GO_TARFILE)
	echo "Install file sha256sum:"
	echo "$SHA256SUM"
	echo

	# Install tarfile by unpacking
	sudo tar -C /usr/local -xzf $GO_TARFILE
	rm $GO_TARFILE
	popd > /dev/null

	# Add binary to $PATH
	COMMONRC=$HOME/.commonrc
	if [ -f $COMMONRC ]; then
		echo >> $COMMONRC
		echo "# For GoLang" >> $COMMONRC
		echo "export PATH=\$PATH:/usr/local/go/bin" >> $COMMONRC
		echo >> $COMMONRC
	else
		echo "Add the following to your shell profile:"
		echo "	export PATH=\$PATH:/usr/local/go/bin"
		echo
	fi

	echo "Finished installing GoLang v$VERSION"

	# To uninstall, simply delete the created directory '/usr/local/go' and
	# remove the 'go' binary from being added to $PATH
	# Instructions: https://golang.org/doc/manage-install#linux-mac-bsd
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

install_slack() {
	echo_label "Slack"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install slack --classic
}

install_spotify() {
	echo_label "Spotify"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install spotify
}

install_keybase() {
	curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
	sudo apt install -y ./keybase_amd64.deb
	run_keybase

	rm keybase_amd64.deb
}

install_rpi_imager() {
	echo_label "RPi Imager"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install rpi-imager
}

install_vlc() {
	echo_label "VLC Media Player"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install vlc
}

install_qbittorrent() {
	echo_label "qbittorrent"

	sudo apt update && sudo apt install -y qbittorrent
}

install_gparted() {
	echo_label "GParted"

	sudo apt update && sudo apt install -y gparted
}

install_noip() {
	echo_label "No-IP DUC"

	INSTALL_DIR=$HOME/Installs/noip
	TAR_FILE=https://www.noip.com/client/linux/noip-duc-linux.tar.gz
	LOCAL_FILE=noip-duc-linux.tar.gz

	mkdir -p $INSTALL_DIR
	pushd $INSTALL_DIR
	wget -O $LOCAL_FILE $TAR_FILE
	tar xvzf $LOCAL_FILE
	rm $LOCAL_FILE

	pushd $(ls)

	# Make started to give some problems with a 'sprintf overflow'
	# error; skipping seems ok
	# sudo make

	sudo make install

	unset INSTALL_DIR
	unset TAR_FILE
	unset LOCAL_FILE

	# Setup systemd service
	echo "Setting up systemd service for noip duc"
	LOCAL_SERVICE_FILE=/etc/systemd/system/noip2.service
	NOIP_SERVICE_FILE=https://gist.githubusercontent.com/vindard/0205001d13665eff809c30c0fe9cf487/raw/05ef5777b0341337665e39afea22df62dd8c4106/noip2.service
	sudo -O $LOCAL_SERVICE_FILE $NOIP_SERVICE_FILE

	sudo systemctl enable noip2
	sudo systemctl start noip2
}

install_chromium() {
	echo_label "Chromium Browser"

	sudo apt update && sudo apt install -y chromium-browser
}

configure_git() {
	echo_label "git configuration"

	git config --global user.name "vindard"
	git config --global user.email "17693119+vindard@users.noreply.github.com"

	echo
	echo "To import 'hot' signing keys fetch the following file and run:"
	echo "$ gpg --decrypt 8F95D90A-priv_subkeys-GHonly.gpg.asc | gpg --import"
	echo "$ git config --global user.signingkey 1B005D838F95D90A"
	echo "$ git config --global commit.gpgsign true"
}

add_ed25519_ssh_key() {
	echo_label "new ed25519 SSH keypair"

	ssh-keygen -o -a 100 -t ed25519
}


# Run the installs

# install_standard
# install_vscode_apt
# install_vscode_snap
# install_speedtest
# install_fish
# install_zsh
# install_telegram
# install_signal
# install_virtualbox
# install_vmware
# install_1password
# install_tor_browser
# install_obsidian
# install_sensors
# install_docker
# install_pyenv
# install_thefuck
# install_golang
# install_yubikey
# install_slack
# install_spotify
# install_keybase
# install_rpi_imager
# install_vlc
# install_gparted
# install_noip
# install_chromium
# install_qbittorrent
# configure_git
# add_ed25519_ssh_key

# test_lines
