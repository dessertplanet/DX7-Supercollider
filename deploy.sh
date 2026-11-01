#!/bin/sh

# Installer for Organelle OS 5.x (Raspberry Pi OS bookworm, CM3/CM4 based Organelle M/S/S2).
# Run by install_package.sh when the .zop is installed, or manually from the patch directory.

export USER_DIR=${USER_DIR:="/usbdrive"}
export FW_DIR=${FW_DIR:="$HOME/fw_dir"}
export DEBIAN_FRONTEND=noninteractive

SC_EXT_DIR="$HOME/.local/share/SuperCollider/Extensions/DX7-Supercollider"

status() {
    oscsend localhost 4001 /oled/aux/line/1 s "$1"
    oscsend localhost 4001 /oled/aux/line/2 s "$2"
    echo "$1 $2"
}

fail() {
    status "install failed" "$1"
    sudo $FW_DIR/scripts/remount-ro.sh
    cd ..
    rm -rf "$PATCH_INSTALL_DIR"
    exit 128
}

PATCH_INSTALL_DIR="$1"

grep -q 'ID=archarm' /etc/os-release

if [ $? -eq 0 ]; then
    status "not valid for" "organelle-1"
    cd ..
    rm -rf "$PATCH_INSTALL_DIR"
    exit 128
fi

# packages to install from the internet if the bundle doesn't fit this OS image
ONLINE_PKGS="jackd2 supercollider-language supercollider-server supercollider-supernova"

have_prereqs() {
    [ -x /usr/bin/sclang ] && [ -x /usr/bin/supernova ] && command -v jackd > /dev/null
}

if ! have_prereqs; then
    status "Installing prereq" "SC 3.13 + jackd"

    # prereqs/debs holds every package a stock OS 5.1 image is missing (or has
    # too old) for SC 3.13 + jackd2. Check offline, before touching anything,
    # that it covers this image: a dry run must resolve and want nothing else.
    bundled=$(for f in prereqs/debs/*.deb; do dpkg-deb -f "$f" Package; done)
    sim=$(apt-get install -s --no-install-recommends ./prereqs/debs/*.deb 2>/dev/null)
    simrc=$?
    extra=$(echo "$sim" | awk '/^Inst /{print $2}' | grep -vxF "$bundled")

    sudo $FW_DIR/scripts/remount-rw.sh
    echo 'jackd2 jackd/tweak_rt_limits boolean true' | sudo debconf-set-selections

    # don't trust dpkg/apt exit codes: the OS 5.1 image ships with initramfs-tools
    # half-configured, and its trigger fails on every install (harmless, the
    # Organelle doesn't boot from an initramfs). Check for the binaries instead.
    if [ $simrc -eq 0 ] && [ -z "$extra" ]; then
        # use dpkg, not apt: apt prefers the repo copy of a package over an
        # identical local .deb and then tries to download it.
        # Only pass dpkg the debs not already installed.
        debs=""
        for f in prereqs/debs/*.deb; do
            pkg=$(dpkg-deb -f "$f" Package)
            ver=$(dpkg-deb -f "$f" Version)
            if [ "$(dpkg-query -W -f='${Status} ${Version}' "$pkg" 2>/dev/null)" != "install ok installed $ver" ]; then
                debs="$debs $f"
            fi
        done
        [ -n "$debs" ] && sudo -E dpkg -i $debs
    else
        echo "bundled debs don't fit this OS image (missing: $(echo $extra)), trying online"
        # the Organelle has no battery backed clock, so it boots with a stale date
        # which makes apt reject the repository signatures as "not yet valid"
        status "Syncing clock" "needs internet"
        sudo systemctl start systemd-timesyncd
        for i in $(seq 1 30); do
            timedatectl show -p NTPSynchronized --value | grep -q yes && break
            sleep 1
        done
        status "Downloading prereq" "SC 3.13 + jackd"
        # apt downloads everything before installing anything, so without
        # internet this fails without changing the system
        sudo -E apt-get update
        sudo -E apt-get install -y --no-install-recommends $ONLINE_PKGS
    fi
    sudo $FW_DIR/scripts/remount-ro.sh

    if ! have_prereqs; then
        if [ $simrc -eq 0 ] && [ -z "$extra" ]; then
            fail "dpkg install"
        else
            fail "need internet"
        fi
    fi
fi

status "Installing prereq" "SC Extensions"
sudo $FW_DIR/scripts/remount-rw.sh
mkdir -p "$SC_EXT_DIR"
cp -f prereqs/extensions/* "$SC_EXT_DIR"
# sclang creates its user data dir on first launch, which fails when / is
# read-only (the normal state), so run it once now while / is writable
echo "0.exit;" > /tmp/sc-firstrun.scd
QT_QPA_PLATFORM=offscreen timeout 120 /usr/bin/sclang /tmp/sc-firstrun.scd < /dev/null
sudo $FW_DIR/scripts/remount-ro.sh

exit 1
