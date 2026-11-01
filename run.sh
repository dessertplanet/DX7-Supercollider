#!/bin/sh
cd /tmp/patch
FW_DIR=${FW_DIR:="$HOME/fw_dir"}
$FW_DIR/scripts/start-jack.sh
# give jackd a moment so supernova doesn't try to autostart its own jack server
sleep 1
# debian's sclang is built with Qt, which needs this to start without a display
export QT_QPA_PLATFORM=offscreen
echo "starting supercollider from run.sh"
/usr/bin/sclang ./mother.scd "patch.scd" & echo $! > /tmp/pids/sclang.pid
