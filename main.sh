#!/bin/sh

utilver="v0.1"

# URLs, you probably do not need to change these since they automatically fetch the latest release
url_stable="https://looking-glass.io/artifact/stable/source"
url_rc="https://looking-glass.io/artifact/rc/source"
url_bleeding="https://looking-glass.io/artifact/bleeding/source"

echo "=============================================================="
echo " _                _    _                ____ _                "
echo "| |    ___   ___ | | _(_)_ __   __ _   / ___| | __ _ ___ ___  "
echo "| |   / _ \ / _ \| |/ / | '_ \ / _  | | |  _| |/ _  / __/ __| "
echo "| |__| (_) | (_) |   <| | | | | (_| | | |_| | | (_| \__ \__ \ "
echo "|_____\___/ \___/|_|\_\_|_| |_|\__, |  \____|_|\__,_|___/___/ "
echo "                               |___/                          "
echo "               _   _      _                                   "
echo "              | | | | ___| |_ __   ___ _ __                   "
echo "              | |_| |/ _ \ | '_ \ / _ \ '__|                  "
echo "              |  _  |  __/ | |_) |  __/ |                     "
echo "              |_| |_|\___|_| .__/ \___|_|                     "
echo "                           |_|            $utilver            "
echo "=============================================================="
echo "Welcome to Looking Glass Helper!                              "
echo "This is a new version of the original by pavolelsig.          "
echo -n "Would you like to continue? Y/N: > " && read confirm01

if [ "$(whoami)" = "root" ]; then
	echo "Running as root, good job!"
else
	echo "Please run me as root (sudo/doas)" ; exit 1
fi

if [ "$confirm01" = "Y" ]; then
	echo "Checking system!"
else
	echo "Quitting." ; exit 0
fi

echo -n "Which user will be using Looking Glass? > " && read user

test /home/anon || echo "$user is not valid." ; exit 1
echo "$user is valid."

# Check distro based on package manager
if [ -e "/usr/bin/apt" ]; then
	echo "Found distro: Debian" ; distro="debian" && installcommand="apt-get install binutils-dev cmake fonts-freefont-ttf libsdl2-dev libsdl2-ttf-dev libspice-protocol-dev libfontconfig1-dev libx11-dev nettle-dev  wayland-protocols -y"
elif [ -e "/usr/bin/pacman" ]; then
	echo "Found distro: Arch" ; distro="arch" && installcommand="pacman -Syu binutils sdl2 sdl2_ttf libx11 nettle fontconfig cmake spice-protocol make pkg-config gcc gnu-free-fonts"
elif [ -e "/usr/bin/dnf" ]; then
	echo "Found distro: Fedora" ; distro="fedora" && installcommand="dnf install make cmake binutils-devel SDL2-devel SDL2_ttf-devel nettle-devel spice-protocol fontconfig-devel libX11-devel"
elif [ -e "/usr/bin/emerge" ]; then
	echo "Found distro: Gentoo" ; distro="gentoo" && installcommand="emerge --noreplace --verbose sys-devel/binutils dev-util/cmake media-fonts/freefonts media-libs/sdl2-ttf app-emulation/spice-protocol dev-libs/nettle media-libs/fontconfig"
fi

# Check init system
if [ -e "/lib/systemd/systemd" ]; then
	init="systemd"
elif [ -e "/sbin/openrc" ]; then
	init="openrc"
fi

# If init is not set, stop
if [ "$init" = "" ]; then
	echo "Your init system is not compatible. Sorry. If you want, you can contribute with support for more."  && exit 1
fi

# If distro is not set, stop
if [ "$distro" = "" ]; then
	echo "Your distro is not compatible with this script. Please use either Debian, Arch, Fedora or Gentoo based distributions."
	echo "If you would like to contribute, please submit a patch for another unsupported distribution."
	exit 1
fi

echo -n "What version of Looking Glass would you like to set up? This must be the same as your Windows VM: Available: 'stable', 'rc', 'bleeding': > " && read lgver

if [ "$lgver" = "stable" ]; then
	lgver=$url_stable
elif [ "$lgver" = "rc" ]; then
	lgver=$url_rc
elif [ "$lgver" = "bleeding" ]; then
	lgver=$url_bleeding
fi

echo "Using $lgver"

echo -n "Are you sure you wanna set up Looking Glass? 'Y/N': > " && read confirm02

if [ "$confirm02" = "Y" ]; then
	echo "Alright, setting up LG"
else
	echo "Exiting." ; exit 1
fi

if [ "$distro" = "gentoo" ]; then
	echo "WARNING: You are running a Gentoo based distribution. Expect compile times to potentially be high."
        
	# Write necessary USE changes
	echo "media-libs/freetype-2.11.1 harfbuzz" > /etc/portage/package.use/freetype || echo "media-libs/freetype-2.11.1 harfbuzz" >> /etc/portage/package.use
fi

$installcommand || echo "Failed to install. Exiting." ; exit 1

# Download Looking Glass
if [ -e "/usr/bin/wget" ]; then
	wget $lgver && echo "Downloaded Looking Glass source code"
else
	curl -O $lgver && echo "Downloaded Looking Glass source code"
fi

# Check if a tarball exists and extract it
test -f *.tar.gz && tar xpvf *.tar.gz && echo "Extracted Looking Glass source code"

# Create services
if [ "$init" = "systemd" ]; then
	curl -o /etc/systemd/system/lg_start.service https://raw.githubusercontent.com/speediegamer/looking-glass-helper/services/lg_start.service && chmod 644 /etc/systemd/system/lg_start.service && echo "Created Systemd service"
else
	curl -o /etc/init.d/lg_start.service https://raw.githubusercontent.com/speediegamer/looking-glass-helper/services/lg_start && chmod 644 /etc/init.d/lg_start.service && echo "Created OpenRC service"
fi

echo "touch /dev/shm/looking-glass && chown $user:kvm /dev/shm/looking-glass && chmod 660 /dev/shm/looking-glass" > /usr/bin/lg_start.sh && echo "Created script"
chmod +x /usr/bin/lg_start.sh

# Service stuff for OpenRC
if [ "$init" = "openrc" ]; then
    	chmod +x /etc/init.d/lg_start.service
	rc-update add /etc/init.d/lg_start.service default
    	rc-service /etc/init.d/lg_start.service start
fi

# Service stuff for systemd
if [ "$init" = "systemd" ]; then
    	chmod +x /etc/systemd/system/lg_start.service
	systemctl enable lg_start.service
	systemctl start lg_start.service
fi

# Compile Looking Glass
cd looking*
mkdir client/build
cd client/build
cmake ../
make
chown $user:looking-glass-client

if [ "$distro" = "fedora" ]; then
	# Snippet by pavolelsig. 
	ausearch -c 'qemu-system-x86' --raw | audit2allow -M my-qemusystemx86
	semodule -X 300 -i my-qemusystemx86.pp
	setsebool -P domain_can_mmap_files 1
else
   	echo "  /dev/shm/looking-glass rw," >> /etc/apparmor.d/abstractions/libvirt-qemu
fi

clear && echo "Complete! Thank you for using this tool!" && exit 0
