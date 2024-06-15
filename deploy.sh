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

if ! [ -f /usr/local/bin/sclang ]; then
    oscsend localhost 4001 /oled/gClear ii 3 1
    oscsend localhost 4001 /oled/aux/line/1 s "linking sclang"
    sudo ~/scripts/remount-rw.sh
    sudo ln -s /usr/bin/sclang /usr/local/bin/sclang
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
    oscsend localhost 4001 /oled/aux/line/1 s "Installing jackd"
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

exit 1

