#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# and Swindles McCoop <swindlesmccoop@waifu.club>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

dotfilesrepo="https://git.cbps.xyz/swindlesmccoop/voidrice-openbsd.git"
progsfile="https://git.cbps.xyz/swindlesmccoop/LARBS-OpenBSD/raw/branch/master/progs.csv"
repobranch="master"

### FUNCTIONS ###

installpkg() {
	pkg_add "$1" >/dev/null 2>&1
}

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	dialog --title "Welcome!" \
		--msgbox "Welcome to Luke's Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured OpenBSD desktop.\\n\\n-Luke" 10 60

	dialog --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "IGNORE MSG" 8 70
}

getuserandpass() {
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		dialog --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. LARBS can install for a user already existing, but it will OVERWRITE any conflicting settings/dotfiles on the user account.\\n\\nLARBS will NOT overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LARBS will change $name's password to the one you just gave." 14 70
}

preinstallmsg() {
	dialog --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /usr/local/bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

suckinstall(){
	cd /usr/ports/mystuff/$1
	make && make install
}

maininstall() {
	# Installs all needed programs from main repo.
	dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	installpkg "$1"
}

pipinstall() {
	dialog --title "LARBS Installation" \
		--infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 9 70
	[ -x "$(command -v "pip")" ] || installpkg py-pip >/dev/null 2>&1
	yes | pip install "$1"
}

installationloop() {
	set -x
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) ||
		curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
	total=$(wc -l </tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"P") pipinstall "$program" "$comment" ;;
		"S") suckinstall "$program" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

vimplugininstall() {
	# Installs vim plugins.
	dialog --infobox "Installing neovim plugins..." 7 60
	mkdir -p "/home/$name/.config/nvim/autoload"
	curl -Ls "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" >  "/home/$name/.config/nvim/autoload/plug.vim"
	chown -R "$name:wheel" "/home/$name/.config/nvim"
	doas -u "$name" nvim -c "PlugInstall|q|q"
}

finalize() {
	dialog --title "All done!" \
		--msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Luke" 13 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on OpenBSD. Install dialog.
pkg_add dialog ||
	error "Are you sure you're running this as the root user, are on OpenBSD and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

for x in curl ca-certificates base-devel git gmake ntp zsh; do
	dialog --title "LARBS Installation" \
		--infobox "Installing \`$x\` which is required to install and configure other programs." 8 70
	installpkg "$x"
done

dialog --title "LARBS Installation" \
	--infobox "Synchronizing system time to ensure successful and secure installation of software..." 8 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

#[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run doas without password. Since ports must be installed
# in a fakeroot environment, this is required for all builds with the ports tree.
printf "permit nopass root\npermit nopass $name\n" > /etc/doas.conf

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.

[ ! -d /usr/ports/ ] && git clone --depth 1 https://github.com/openbsd/ports /usr/ports/
[ ! -d /usr/ports/mystuff ] && git clone --depth 1 https://github.com/swindlesmccoop/openbsd-ports /usr/ports/mystuff/

installationloop

# Install the dotfiles in the user's home directory, but remove .git dir and
# other unnecessary files.
dialog --infobox "Downloading and installing config files..." 7 60
#[ -z "$3" ] && branch="master" || branch="$repobranch"
#[ ! -d "$2" ] && mkdir -p "$2"
#chown "$name":wheel "$dir" "$2"
#doas -u "$name" git -C "$repodir" clone --depth 1 \
#	--single-branch --no-tags -q --recursive -b "$branch" \
#	--recurse-submodules "$1" "$dir"
#doas -u "$name" cp -rfT "$dir" "$2"
cd $repodir
doas -u "$name" git clone --depth 1 --single-branch --recurse-submodules $dotfilesrepo
cd $dotfilesrepo
doas -u "$name" cp -rfT * .* /home/$name/
rm -rf "/home/$name/.git/" "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"

# Install vim plugins if not alread present.
[ ! -f "/home/$name/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# Make zsh the default shell for the user.
chsh -s /usr/local/bin/zsh "$name"
doas -u "$name" mkdir -p "/home/$name/.cache/zsh/"
doas -u "$name" mkdir -p "/home/$name/.config/abook/"
doas -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen >/var/lib/dbus/machine-id

# Enable tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/usr/X11R6/share/X11/xorg.conf.d/40-libinput.conf

# Last message! Install complete!
finalize
#clear
