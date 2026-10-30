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

if ! [ -x /usr/bin/sclang ] || ! [ -x /usr/bin/supernova ] || ! command -v jackd > /dev/null; then
    # the Organelle has no battery backed clock, so it boots with a stale date
    # which makes apt reject the repository signatures as "not yet valid"
    status "Syncing clock" "please wait"
    sudo systemctl start systemd-timesyncd
    for i in $(seq 1 30); do
        timedatectl show -p NTPSynchronized --value | grep -q yes && break
        sleep 1
    done

    status "Installing prereq" "SC 3.13 + jackd"
    sudo $FW_DIR/scripts/remount-rw.sh
    echo 'jackd2 jackd/tweak_rt_limits boolean true' | sudo debconf-set-selections
    sudo -E apt-get update || fail "apt update"
    # don't trust apt's exit code: the OS 5.1 image ships with initramfs-tools
    # half-configured, and its trigger fails on every install (harmless, the
    # Organelle doesn't boot from an initramfs). Check for the binaries instead.
    sudo -E apt-get install -y --no-install-recommends \
        jackd2 supercollider-language supercollider-server supercollider-supernova
    sudo $FW_DIR/scripts/remount-ro.sh

    if ! [ -x /usr/bin/sclang ] || ! [ -x /usr/bin/supernova ] || ! command -v jackd > /dev/null; then
        fail "apt install"
    fi
fi

status "Installing prereq" "SC Extensions"
sudo $FW_DIR/scripts/remount-rw.sh
mkdir -p "$SC_EXT_DIR"
cp -f prereqs/extensions/* "$SC_EXT_DIR"
sudo $FW_DIR/scripts/remount-ro.sh

exit 1
