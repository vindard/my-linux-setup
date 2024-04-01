#!/bin/bash

check_dependency() {
	for cmd in "$@"; do
		if ! command -v $cmd >/dev/null 2>&1; then
			echo "This script requires \"${cmd}\" to be installed"
			return 1
		fi
	done
}

check_flatpak() {
	if ! check_dependency flatpak; then
		install_flatpak || return 1
	fi
}

echo_label() {
	echo && echo "Installing $1" && echo "---" && echo
}

append_to_file() {
	if [[ -e $FILE ]]; then
		for line in "$@"; do
			if [[ -z $line ]] || ! cat $FILE | grep -q "$line"; then
				echo "$line" | tee -a $FILE > /dev/null
			fi
		done

		# Delete all trailing blank lines at end of file
		# (https://unix.stackexchange.com/a/81687)
		sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FILE
		echo | tee -a $FILE > /dev/null
	else
		echo "Cannot append to '$FILE', file does not exist"
	fi
}

su_append_to_file() {
	if [[ -e $FILE ]]; then
		for line in "$@"; do
			if [[ -z $line ]] || ! sudo cat $FILE | grep -q "$line"; then
				echo "$line" | sudo tee -a $FILE > /dev/null
			fi
		done

		# Delete all trailing blank lines at end of file
		# (https://unix.stackexchange.com/a/81687)
		sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FILE
		echo | sudo tee -a $FILE > /dev/null
	else
		echo "Cannot append to '$FILE', file does not exist"
	fi
}

append_to_sources_list() {
	FILE="/etc/apt/sources.list"
	su_append_to_file "$@"
}

append_to_torrc() {
	FILE="/etc/tor/torrc"
	su_append_to_file "$@"
}

append_to_bash_aliases() {
	FILE="$HOME/.bash_aliases"
	append_to_file "$@"
}

append_to_commonrc() {
	FILE="$HOME/.commonrc"
	append_to_file "$@"
}

uncomment_torrc() {
	FILE="/etc/tor/torrc"

	for string in "$@"; do
		sudo sed -i \
			"s/#\s\?\($string\)/\1/g" \
			$FILE
	done
}

get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" | 	# Get latest release from GitHub api
		grep '"tag_name":' |                                            # Get tag line
		sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

install_standard() {
	echo_label "standard tools"

	mkdir -p $HOME/Developer
	touch $HOME/.commonrc

	sudo apt update && sudo apt install -y \
		htop \
		vim \
		tree \
		jq \
		git \
		vnstat \
		tmux \
		nmap \
		curl
}

install_extraction_tools() {
	echo_label "extraction tools"

	sudo apt update

	# There are three 7zip packages in Ubuntu: p7zip, p7zip-full and p7zip-rar
	#
	# The difference between p7zip and p7zip-full is that p7zip is a lighter
	# version providing support only for .7z while the full version provides
	# support for more 7z compression algorithms (for audio files etc).
	#
	# The p7zip-rar package provides support for RAR files along with 7z.
	# Source: https://itsfoss.com/use-7zip-ubuntu-linux/
	sudo apt install -y p7zip-full p7zip-rar
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

install_robo3t_snap() {
	echo_label "Robo 3T for MongoDB (via snap)"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install robo3t-snap
}

install_dotnet() {
	echo_label ".NET SDK"

	# From: https://github.com/dotnet/core/issues/7699
	sudo apt update && sudo apt -y install \
		dotnet6

}

install_dotnet_old() {
	echo_label ".NET SDK"

	# From: https://docs.microsoft.com/en-us/dotnet/core/install/linux-ubuntu#2110-
	PACKAGE_NAME="packages-microsoft-prod.deb"
	wget https://packages.microsoft.com/config/ubuntu/21.04/$PACKAGE_NAME -O $PACKAGE_NAME
	sudo dpkg -i $PACKAGE_NAME
	rm $PACKAGE_NAME

	sudo apt-get update; \
		sudo apt-get install -y apt-transport-https && \
		sudo apt-get update && \
		sudo apt-get install -y dotnet-sdk-6.0

	echo_label "ASP.NET Core Runtime"
	sudo apt-get update; \
		sudo apt-get install -y apt-transport-https && \
		sudo apt-get update && \

		# Install one of 'aspnetcore' or 'dotnet'
		sudo apt-get install -y aspnetcore-runtime-6.0
		# sudo apt-get install -y dotnet-runtime-6.0

}

install_android_studio_snap() {
	echo_label "Android Studio (via snap)"

	if ! check_dependency java; then
		echo_label "Java dependency (for Android Studio)"
		sudo apt update && sudo apt install -y \
			openjdk-11-jdk
			# openjdk-8-jdk
	fi

	# Run the following to switch installed android versions:
	# $ sudo update-alternatives --config java

	sudo snap install android-studio --classic
	# Remove with: $ sudo snap remove android-studio
}

install_scrcpy() {
	echo_label "scrcpy (Android device mirroring tool)"

	sudo apt update && sudo apt install -y \
		scrcpy
}

install_speedtest() {
	if ! check_dependency curl
	then
		sudo apt update && sudo apt install -y \
			curl
	fi

	REPO_SETUP_SCRIPT="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
	curl -s $REPO_SETUP_SCRIPT | sudo bash
	sudo apt install speedtest
}

install_magic_wormhole() {
	echo_label "Magic Wormhole"

	sudo apt update && \
		sudo apt install -y \
			magic-wormhole
}

install_plex_server() {
	# Install repo setup dependencies
	sudo apt update && sudo apt install -y \
		apt-transport-https \
		ca-certificates \
		curl

	# Import repo PGP keys
	curl https://downloads.plex.tv/plex-keys/PlexSign.key \
		| sudo apt-key add -

	# Add new repo to sources and update
	echo deb https://downloads.plex.tv/repo/deb public main \
		| sudo tee /etc/apt/sources.list.d/plexmediaserver.list
	sudo apt update

	# Install plex
	sudo apt install -y plexmediaserver

	# Configure firewall rules
	# Steps from: https://gist.github.com/nmaggioni/45dcca7695d37e6109276b1a6ad8c9c9
	PLEX_UFW_RULES=/etc/ufw/applications.d/plexmediaserver
	sudo cp configs/plexmediaserver.ufw $PLEX_UFW_RULES
	sudo chown root: $PLEX_UFW_RULES

	sudo ufw app update plexmediaserver
	sudo ufw allow plexmediaserver-all
}

install_transmission() {
	# INSTALL
	sudo apt update && sudo apt install -y \
        transmission-daemon

    sudo systemctl stop transmission-daemon

	# CONFIGURE
    TORRENT_DIR=/home/$TSM_USER/Downloads/_torrents
    INCOMPLETE_DIR=$TORRENT_DIR/incomplete
    SETTINGS_FILE=/etc/transmission-daemon/settings.json
    SYSTEMD_FILE_1=/etc/systemd/system/multi-user.target.wants/transmission-daemon.service
    SYSTEMD_FILE_2=/lib/systemd/system/transmission-daemon.service

    # Check for Transmission user value
    if [[ -z $TSM_USER ]] ; then
        echo "Please enter value for 'TSM_USER' in '.env' and re-run."
        return 1
    fi

    # Check for Transmission password value
    if [[ -z $TSM_PASS ]] ; then
        echo "Please enter value for 'TSM_PASS' in '.env' and re-run."
        return 1
    fi


    # Check user, and create if not found
    if ! id $TSM_USER > /dev/null 2>&1; then
        sudo adduser $TSM_USER
    fi


    # Create the Transmission torrent dir and allocate to torrent user
    mkdir -p $INCOMPLETE_DIR
    sudo chown -R $TSM_USER:$TSM_USER $TORRENT_DIR

    sudo chown -R $TSM_USER:$TSM_USER /etc/transmission-daemon
    sudo mkdir -p /home/$TSM_USER/.config/transmission-daemon/
    sudo ln -s $SETTINGS_FILE /home/$TSM_USER/.config/transmission-daemon/
    sudo chown -R $TSM_USER:$TSM_USER /home/$TSM_USER/.config/transmission-daemon/

    # Configure Transmission settings
    sudo cp $SETTINGS_FILE $SETTINGS_FILE.bak

    change_json_value $SETTINGS_FILE \
        "download-dir" \
        "$TORRENT_DIR"

    change_json_value $SETTINGS_FILE \
        "incomplete-dir" \
        "$INCOMPLETE_DIR"

    toggle_json_true $SETTINGS_FILE \
        "incomplete-dir-enabled"

    change_json_value $SETTINGS_FILE \
        "rpc-username" \
        "$TSM_USER"

    change_json_value $SETTINGS_FILE \
        "rpc-password" \
        "$TSM_PASS"

    change_json_value $SETTINGS_FILE \
        "rpc-whitelist" \
        "127.0.0.1,192.168.*.*"


    # Configure user in systemd files
    sudo sed -i "s/^User=.*/User=$TSM_USER/g" $SYSTEMD_FILE_1
    sudo sed -i "s/^User=.*/User=$TSM_USER/g" $SYSTEMD_FILE_2


    # 'active' mode requires port 51413 be opened on the router and forwarded to this device
    # sudo ufw allow 51413/tcp \
        # comment 'allow Transmission active mode'


    # Reload and restart daemon
    sudo systemctl daemon-reload
    sudo systemctl enable transmission-daemon
    # May need to delete the existing file at $SYSTEMD_FILE_1 if $SYSTEMD_FILE_2 exists and above errors
    sudo systemctl start transmission-daemon


    # Setup alias
	FILE="/home/$TSM_USER/.bashrc"
	su_append_to_file \
        "" \
        "# Transmission alias" \
        "alias tsm='transmission-remote --auth $TSM_USER:$TSM_PASS'"

	FILE="/home/$TSM_USER/.zshrc"
	su_append_to_file \
        "" \
        "# Transmission alias" \
        "alias tsm='transmission-remote --auth $TSM_USER:$TSM_PASS'"
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

install_cheese() {
	# Linux tool for streaming webcam
	echo_label "Cheese"

	sudo apt update && sudo apt install -y cheese
}
install_vmware() {
	echo_label "VMWare"

	sudo apt update && sudo apt install -y \
		build-essential

	mkdir -p $HOME/Downloads
	pushd $HOME/Downloads > /dev/null
	wget \
		--user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0" \
		https://www.vmware.com/go/getplayer-linux

	chmod +x getplayer-linux
	sudo ./getplayer-linux
	popd > /dev/null

	# On latest Pop!_OS 21.10 I had to manually clone and make the foll:
	# https://communities.vmware.com/t5/VMware-Workstation-Pro/Workstation-16-2-1-vmmon-amp-vmnet-not-compiling-on-Pop-OS-21-10/m-p/2885045/highlight/true#M173190
	echo
	echo "Open VMWare and make sure setup is complete in the UI"
	echo "-----"
	echo
}

install_windows_networking() {
	# Guide at: https://www.howtogeek.com/176471/how-to-share-files-between-windows-and-linux/
	echo_label "Windows Networking"

	sudo apt update && sudo apt install -y \
		cifs-utils

	echo "---"
	echo
	echo "Make a new dir and mount the Windows share to it like this:"
	echo "$ mkdir $HOME/Shared-Documents"
	echo "$ sudo mount.cifs //WindowsPC/Shared-Documents $HOME/Shared-Documents -o user=<Windows user here>"
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
	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
	fi

	flatpak install -y flathub com.github.micahflee.torbrowser-launcher || \
		echo "If download was interrupted run: '$ flatpak repair --user'"

	flatpak run com.github.micahflee.torbrowser-launcher
}

install_tor() {
	echo_label "Tor daemon"

	TOR_URL="https://deb.torproject.org/torproject.org"

	sudo apt update && sudo apt install -y \
		dirmngr \
		apt-transport-https

	append_to_sources_list \
		"deb $TOR_URL buster main" \
		"deb-src $TOR_URL buster main"

	PGP_KEY="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
	curl $TOR_URL/$PGP_KEY.asc | gpg --import
	gpg --export $PGP_KEY | sudo apt-key add -

	sudo apt update && sudo apt install -y \
		tor \
		tor-arm

	echo "Running '$ tor --version':"
	tor --version

	# 'torrc' edits from Raspibolt instructions
	# - https://stadicus.github.io/RaspiBolt/raspibolt_69_tor.html

	# echo "Editing '/etc/tor/torrc' file"
	# uncomment_torrc \
	# 	"ControlPort 9051" \
	# 	"CookieAuthentication 1"
	# append_to_torrc \
	# 	"# Added from Raspibolt instructions" \
	# 	"CookieAuthFileGroupReadable 1"

	# sudo systemctl restart tor
}

install_obsidian() {
	echo_label "Obsidian"

	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
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
	if ! check_dependency docker
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

install_docker_compose_v2() {
	echo_label "Docker Compose v2"

	echo "Checking that Docker dependency is installed..."
	if ! check_dependency docker
	then
		echo "Docker not found, install first and then retry"
		return 1
	fi

	VERSION="v2.23.3"
	URL="https://github.com/docker/compose/releases/download/$VERSION/docker-compose-linux-x86_64"

	mkdir -p $HOME/.docker/cli-plugins/
	sudo curl -SL $URL -o $HOME/.docker/cli-plugins/docker-compose
	sudo chmod +x $HOME/.docker/cli-plugins/docker-compose
	docker compose version
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
	# Note: compose comes with docker now
	# install_docker_compose_v2
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

install_poetry() {
	echo_label "Poetry"

	if ! check_dependency python3; then
		echo "'python3' missing, skipping Poetry install..."
		return 1
	fi

	INSTALL_SCRIPT="/tmp/install-poetry.py"
	curl -sSL https://install.python-poetry.org > "$INSTALL_SCRIPT"
	echo "Downloaded .py install script to '$INSTALL_SCRIPT' via 'curl -sSL https://install.python-poetry.org'."
	echo "Please open in another tab and confirm."
	read -p "Continue? (Y/n): " RESP
	if ! [[ $RESP == 'Y' ]] && ! [[ $RESP == 'y' ]]; then
		echo "Skipping Poetry install..."
		return 1
	fi

	# You can uninstall at any time by executing this script with the --uninstall option, and
	# these changes will be reverted.
	chmod +x "$INSTALL_SCRIPT"
	python3 "$INSTALL_SCRIPT"
	rm "$INSTALL_SCRIPT"

	POETRY_PATH="$HOME/.local/bin"
	if [ -z $(echo $PATH | grep $POETRY_PATH) ]; then
		echo "Note: Need to add $POETRY_PATH to \$PATH in shell configs (.commonrc)"
	fi

	echo "Finished installing Poetry."
}

install_nodenv() {
	echo_label "nodenv"

	NODENV_DIR="$HOME/.nodenv"

	if command -v nodenv >/dev/null 2>&1; then
		echo "'nodenv' already installed, skipping install steps..."
		return 0
	fi


	# Fetch from github & build
	echo "Fetching from github repo..." && echo
	rm -rf $NODENV_DIR
	git clone https://github.com/nodenv/nodenv.git $NODENV_DIR
	pushd $NODENV_DIR > /dev/null
	src/configure && make -C src

	append_to_commonrc \
		"" \
		"# For nodenv" \
		'export PATH="$HOME/.nodenv/bin:$PATH"' \
		'eval "$(nodenv init -)"'


	# PLUGINS
	# -------------
	NODENV_PLUGINS_DIR="$NODENV_DIR/plugins"
	mkdir -p $NODENV_DIR/plugins

	# Plugin: 'node-build'
	# This provides the '$ nodenv install' command that simplifies
	# the process of installing new Node versions
	PLUGIN_NAME="node-build"
	PLUGIN_URL="https://github.com/nodenv/$PLUGIN_NAME.git"
	git clone \
		$PLUGIN_URL \
		"$NODENV_PLUGINS_DIR/$PLUGIN_NAME"

	# Plugin: 'node-package-rehash'
	# This plugin aut rehashes module after install so that they are
	# available from the terminal
	PLUGIN_NAME="nodenv-package-rehash"
	PLUGIN_URL="https://github.com/nodenv/$PLUGIN_NAME.git"
	git clone \
		$PLUGIN_URL \
		"$NODENV_PLUGINS_DIR/$PLUGIN_NAME"


	# VERIFY INSTALL
	# -------------
	NODENV_DOCTOR="$HOME/nodenv-doctor"
	echo
	echo "Install complete"
	echo "====="
	echo "Fetch and run the following script to check to installation:"
	echo '   $ exec "$SHELL"'
	echo "   $ curl -fsSL https://github.com/nodenv/nodenv-installer/raw/master/bin/nodenv-doctor > $NODENV_DOCTOR"
	echo "   $ chmod u+x $NODENV_DOCTOR"
	echo "   $ $NODENV_DOCTOR"
	echo "   $ rm $NODENV_DOCTOR"
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

install_clang() {
	echo_label "clang"

	# Instructions from: https://www.addictivetips.com/ubuntu-linux-tips/clang-on-ubuntu/
	sudo apt update && sudo apt install -y \
		clang
}

install_rust() {
	echo_label "Rust"

	# Instructions from: https://www.rust-lang.org/tools/install
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

	# Uninstall with: `$ rustup self uninstall``
}

install_gitian_bitcoin_deps() {
	echo_label "dependencies for gitian bitcoin builds"

	sudo apt update && sudo apt install -y \
		apt-cacher-ng \
		coreutils \
		ruby

	if ! check_dependency docker; then
		install_docker
	fi
}

install_awscli() {
	echo_label "AWS CLI"

	VIRTUALENV="awscli"
	INSTALL_DIRNAME="aws-cli"
	REPO=https://github.com/aws/$INSTALL_DIRNAME.git

	# Fetch install files
	git clone $REPO
	pushd $INSTALL_DIRNAME > /dev/null
	git checkout v2

	# Check virtualenv dependency
	if check_dependency pyenv; then
		echo "Creating '$VIRTUALENV' virtualenv with pyenv"
		pyenv virtualenv $VIRTUALENV
		pyenv local $VIRTUALENV
		pip install --upgrade pip
	else
		echo
		read -p "No 'pyenv' found, would you like to proceed with system Python? (Y/n): " RESP
		echo
		if [[ $RESP == 'N' ]] || [[ $RESP == 'n' ]]; then
			echo "Skipping rest of awscli install..."
			return 1
		fi
	fi

	# Install awscli
	pip3 install -r requirements.txt
	pip3 install .

	echo
	echo "Checking for 'aws' binary..."
	if aws --version; then
		echo "AWS CLI installed"
		echo
		echo "Configure using the following command:"
		echo "$ aws configure"
	else
		echo "Error: double-check that '$ aws' command works"
		return 1
	fi

	# Cleanup
	popd > /dev/null
	rm -rf $INSTALL_DIRNAME

	# Add to aliases
	if check_dependency pyenv; then
		append_to_bash_aliases \
			"" \
			"# AWS CLI virtualenv" \
			"alias aws=\"$HOME/.pyenv/versions/$VIRTUALENV/bin/aws\""
	fi
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

install_simple_screen_recorder() {
	echo_label "SimpleScreenRecorder"

	sudo apt update && sudo apt install -y simplescreenrecorder
}

install_peek_gif_recorder() {
	echo_label "peek (GIF screen recorder)"

	if ! check_flatpak; then
		echo "Couldn't find/install flatpak, skipping rest of install"
		return 1
	fi

	if flatpak install -y flathub com.uploadedlobster.peek; then
		flatpak run com.uploadedlobster.peek
	else
		echo "If download was interrupted run: '$ flatpak repair --user'"
	fi

}

install_obs() {
	echo_label "OBS"

	# Following from: https://obsproject.com/wiki/install-instructions#ubuntumint-installation
	sudo apt update && sudo apt install -y \
		ffmpeg \
		v4l2loopback-dkms

	sudo add-apt-repository ppa:obsproject/obs-studio
	sudo apt update && sudo apt install -y \
		obs-studio
}

install_dropbox() {
	echo_label "Dropbox"

	cd $HOME && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

	echo "Starting Dropbox"
	echo "---"
	$HOME/.dropbox-dist/dropboxd

	# Add to aliases
	append_to_bash_aliases \
		"" \
		"# Dropbox" \
		"alias dropbox=\"$HOME/.dropbox-dist/dropboxd\""
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
	pushd $INSTALL_DIR > /dev/null
	wget -O $LOCAL_FILE $TAR_FILE
	tar xvzf $LOCAL_FILE
	rm $LOCAL_FILE

	pushd $(ls) > /dev/null

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
	sudo wget -O $LOCAL_SERVICE_FILE $NOIP_SERVICE_FILE

	sudo systemctl enable noip2
	sudo systemctl start noip2
}

install_expressvpn() {
	echo "Follow instructions at https://www.expressvpn.com/support/vpn-setup/app-for-linux/#install"
}

install_wireguard() {
	# Note: use pivpn to configure wireguard! https://www.pivpn.io/

	echo_label "Wireguard"

	sudo apt update && sudo apt install -y wireguard

	WIREGUARD_DIR=/etc/wireguard
	echo
	echo "Generating wireguard keys"
	wg genkey | sudo tee $WIREGUARD_DIR/privatekey | wg pubkey | sudo tee $WIREGUARD_DIR/publickey
	echo "Keys generated at $WIREGUARD_DIR"
	echo
	echo "Finished installing wireguard:"
	echo " > configure the 'wg0.conf' file at $WIREGUARD_DIR to use"
	echo " > double-check the interface for PostUp and PostDown values"
	echo " > Run '$ chmod 600 /etc/wireguard/wg0.conf'"
	echo
	echo "If this is acting as a host receiving connections:"
	echo " > open port 51820"
	echo " > add a ufw/firewall rule for 51820/udp"
	echo "   \$ sudo ufw allow 51820/udp comment \"Allow incoming Wireguard VPN connections\""
	echo " > follow Step 4 here to edit sysctl: https://jianjye.medium.com/how-to-fix-no-internet-issues-in-wireguard-ed8f4bdd0bd1"
	echo
	echo "Check if a connection was made by connecting to this server and using"
	echo "the '\$ sudo wg' command."
	echo
}

install_zbar() {
	echo_label "Zbar tools (bar code reader)"

	sudo apt update && sudo apt install -y \
		zbar-tools
}

install_electrum() {
	echo_label "Electrum"

	# Fetch Thomas' pgp keys
	echo "Fetching Thomas' PGP keys"
	gpg --recv-keys \
		--keyserver pgp.mit.edu \
		6694D8DE7BE8EE5631BED9502BD5824B7F9470E6

	# Fetch install files
	VERSION=4.1.5
	BASE_FILE=Electrum-$VERSION.tar.gz
	wget https://download.electrum.org/$VERSION/$BASE_FILE
	wget https://download.electrum.org/$VERSION/$BASE_FILE.ThomasV.asc
	gpg --verify $BASE_FILE.ThomasV.asc $BASE_FILE

	# Install dependencies
	sudo apt update && sudo apt install -y \
		python3-pyqt5 \
		libsecp256k1-0 \
		python3-cryptography

	# Install python dependencies
	sudo apt install -y \
		python3-setuptools \
		python3-pip

	# Install Electrum from package using pip
	python3 -m pip install --user $BASE_FILE

	rm $BASE_FILE*
	$HOME/.local/bin/electrum version --offline

	echo && "Installing ZBar for QR code scanning from Electrum..."
	install_zbar

	# Add binary to $PATH
	COMMONRC=$HOME/.commonrc
	if [ -f $COMMONRC ]; then
		echo >> $COMMONRC
		echo "# For Electrum" >> $COMMONRC
		echo "export PATH=\$PATH:$HOME/.local/bin" >> $COMMONRC
		echo >> $COMMONRC
	else
		echo "Add the following to your shell profile:"
		echo "	export PATH=\$PATH:$HOME/.local/bin"
		echo
	fi

	echo
	echo "Finished installing Electrum. Restart shell and check with '\$ electrum --version'"
}

install_sparrow_wallet() {
	echo_label "Sparrow Wallet"

	VERSION="1.3.2"
	DOWNLOAD_URL_PRE="https://github.com/sparrowwallet/sparrow/releases/download/$VERSION"

	pushd /tmp
	curl https://keybase.io/craigraw/pgp_keys.asc | gpg --import

	wget $DOWNLOAD_URL_PRE/sparrow_$VERSION-1_amd64.deb
	wget $DOWNLOAD_URL_PRE/sparrow-$VERSION-manifest.txt
	wget $DOWNLOAD_URL_PRE/sparrow-$VERSION-manifest.txt.asc

	echo
	echo "Running gpg sig checks"
	echo "---"
	gpg --verify sparrow-$VERSION-manifest.txt.asc

	echo
	echo "Running sha256 checksum checks"
	echo "---"
	sha256sum --check sparrow-$VERSION-manifest.txt --ignore-missing
	echo
	read -p "Do checks look ok to continue? (Y/n): " RESP
	echo
	if [[ $RESP == 'Y' ]] || [[ $RESP == 'y' ]]
	then
		echo "Starting 'Sparrow' install"
	else
		echo "Skipping rest of 'Sparrow' install"
		echo
		return 1
	fi

	sudo apt install ./sparrow_$VERSION-1_amd64.deb
}

install_udev_deps() {
	sudo apt update && sudo apt install -y \
		libusb-1.0-0-dev \
		libudev-dev

	sudo groupadd plugdev
	sudo usermod -aG plugdev $(whoami)
}

install_trezor_udev() {
	echo_label "Trezor Hardware wallet"
	install_udev_deps

	python3 -m pip install trezor[hidapi]

	cat << 'EOF' | sudo tee /etc/udev/rules.d/51-trezor.rules
# Trezor: The Original Hardware Wallet
# https://trezor.io/
#
# Put this file into /etc/udev/rules.d
#
# If you are creating a distribution package,
# put this into /usr/lib/udev/rules.d or /lib/udev/rules.d
# depending on your distribution

# Trezor
SUBSYSTEM=="usb", ATTR{idVendor}=="534c", ATTR{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="534c", ATTRS{idProduct}=="0001", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"

# Trezor v2
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c0", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl", SYMLINK+="trezor%n"
KERNEL=="hidraw*", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="53c1", MODE="0660", GROUP="plugdev", TAG+="uaccess", TAG+="udev-acl"
EOF

	sudo udevadm control --reload-rules && \
		sudo udevadm trigger
}

install_coldcard_udev() {
	echo_label "Coldcard Hardware wallet"
	install_udev_deps

	python3 -m pip install ckcc-protocol

	cat << 'EOF' | sudo tee /etc/udev/rules.d/51-coinkite.rules
# Linux udev support file.
#
# This is a example udev file for HIDAPI devices which changes the permissions
# to 0666 (world readable/writable) for a specific device on Linux systems.
#
# - Copy this file into /etc/udev/rules.d and unplug and re-plug your Coldcard.
# - Udev does not have to be restarted.
#
# probably not needed:
SUBSYSTEMS=="usb", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666"
# required:
# from <https://github.com/signal11/hidapi/blob/master/udev/99-hid.rules>
KERNEL=="hidraw*", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666"
EOF

	sudo udevadm control --reload-rules && \
		sudo udevadm trigger
}

install_zap_wallet() {
	echo_label "Zap Desktop"


	VERSION="v0.7.2-beta"
	FILE="Zap-linux-x86_64-$VERSION.AppImage"
	INSTALL_DIR="$HOME/Installs"
	URL=https://github.com/LN-Zap/zap-desktop/releases/download/$VERSION/$FILE
	echo "Installing hardcoded version '$VERSION'"

	mkdir -p $INSTALL_DIR
	pushd $INSTALL_DIR > /dev/null
	wget $URL

	sudo chmod +x $FILE
	popd > /dev/null

	# Add to aliases
	append_to_bash_aliases \
		"" \
		"# Zap Wallet" \
		"alias zap=\"$INSTALL_DIR/$FILE && exit\""

	echo "Finished installing, restart shell and run '$ zap' to execute"
}

install_chromium() {
	echo_label "Chromium Browser"

	sudo apt update && sudo apt install -y chromium-browser
}


install_hdparm() {
	echo_label "hdparm"

	sudo apt update && sudo apt install -y \
		hdparm
}

install_direnv() {
	# Needed to run GaloyMoney/galoy repo
	sudo apt update && sudo apt install -y \
		direnv

	append_to_commonrc \
		"" \
		"# For direnv" \
		'eval "$(direnv hook zsh)"'
}

install_gcloud() {
	echo_label "GCloud CLI (via snap)"

	if ! check_dependency snap; then
		install_snap
	fi

	sudo snap install google-cloud-cli --classic
}

install_ruby() {
	echo_label "Ruby"

	sudo apt update && sudo apt install -y \
		ruby-full
}

configure_git() {
	echo_label "git configuration"

	GIT_USER="vindard"
	GIT_EMAIL="17693119+vindard@users.noreply.github.com"
	GLOBAL_GITIGNORE="$HOME/.gitignore"

	git config --global user.name "$GIT_USER"
	git config --global user.email "$GIT_EMAIL"
	echo "Set global git username as '$GIT_USER' and email as '$GIT_EMAIL'"

	if [[ ! -f $GLOBAL_GITIGNORE ]]; then
		cp configs/.gitignore $GLOBAL_GITIGNORE
	fi
	git config --global core.excludesfile $GLOBAL_GITIGNORE
	echo "Set global gitignore at '$GLOBAL_GITIGNORE'"

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
# install_extraction_tools
# install_vscode_apt
# install_vscode_snap
# install_robo3t_snap
# install_dotnet
# install_android_studio_snap
# install_scrcpy
# install_speedtest
# install_magic_wormhole
# install_fish
# install_zsh
# install_telegram
# install_signal
# install_virtualbox
# install_cheese
# install_vmware
# install_windows_networking
# install_1password
# install_tor_browser
# install_tor
# install_obsidian
# install_sensors
# install_docker
# install_pyenv
# install_poetry
# install_nodenv
# install_thefuck
# install_golang
# install_clang
# install_rust
# install_gitian_bitcoin_deps
# install_awscli
# install_yubikey
# install_slack
# install_spotify
# install_keybase
# install_rpi_imager
# install_vlc
# install_gparted
# install_noip
# install_expressvpn
# install_wireguard
# install_zbar
# install_electrum
# install_sparrow_wallet
# install_trezor_udev
# install_zap_wallet
# install_chromium
# install_hdparm
# install_qbittorrent
# install_simple_screen_recorder
# install_peek_gif_recorder
# install_obs
# install_dropbox
# install_direnv
# install_gcloud
# install_ruby
# configure_git
# add_ed25519_ssh_key

# test_lines
