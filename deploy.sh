#!/bin/sh

export USER_DIR=${USER_DIR:="/usbdrive"}
export DEBIAN_FRONTEND=noninteractive

grep -q 'ID=archarm' /etc/os-release

if [ $? -eq 0 ]; then 
    oscsend localhost 4001 /oled/aux/Clear ii 3 1
    oscsend localhost 4001 /oled/aux/line/1 s "not valid for"
    oscsend localhost 4001 /oled/aux/line/2 s "organelle-1"
    cd ..
    rm -rf $1
    exit 128
fi 

if ! [ -f /usr/local/bin/supernova ]; then
    oscsend localhost 4001 /oled/gClear ii 3 1
    oscsend localhost 4001 /oled/aux/line/1 s "Installing prereq"
    oscsend localhost 4001 /oled/aux/line/2 s "Supercollider v3.11.2"

    sudo ~/scripts/remount-rw.sh
    sudo unzip -o sc11.zip  -d /usr/local
    /usr/local/bin/sclang ./firstrun.scd
    sudo ~/scripts/remount-ro.sh
fi



which jackd

if [ ! $? -eq 0 ]; then 
    wget -q --spider http://google.com

    if [ ! $? -eq 0 ]; then
        oscsend localhost 4001 /oled/gClear ii 3 1
        oscsend localhost 4001 /oled/aux/line/1 s "Connect Internet"
        oscsend localhost 4001 /oled/aux/line/2 s "Then try again"
        cd ..
        rm -rf $1
        exit 128
    fi   
    
    oscsend localhost 4001 /oled/gClear ii 3 1
    oscsend localhost 4001 /oled/aux/line/1 s "Installing prereq"
    oscsend localhost 4001 /oled/aux/line/2 s "jackd"
    sudo ~/scripts/remount-rw.sh
    sudo mv /etc/apt/sources.list /etc/apt/sources.list/bak
    sudo cp ./sources.list /etc/apt/sources.list
    sudo apt-get -y update
    echo 'jackd2 jackd/tweak_rt_limits boolean true' | sudo debconf-set-selections
    sudo -E apt-get -y install jackd2
    if [ ! $? -eq 0 ]; then
        oscsend localhost 4001 /oled/aux/line/1 s "jackd install failed"
        sudo ~/scripts/remount-ro.sh
        cd ..
        rm -rf $1
    fi
    sudo ~/scripts/remount-ro.sh
fi

if ! [ -f /usr/local/share/SuperCollider/Extensions ]; then
    sudo ~/scripts/remount-rw.sh
    sudo mkdir /usr/local/share/SuperCollider/Extensions
    sudo cp ./FM7* /usr/local/share/SuperCollider/Extensions
    sudo ~/scripts/remount-ro.sh
fi

exit 1

