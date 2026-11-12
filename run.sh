#!/bin/sh
cd /tmp/patch
# Same as $FW_DIR/scripts/start-jack.sh, but picks the first ALSA card with a playback
# PCM instead of assuming hw:0. USB MIDI controllers (e.g. Arturia KeyStep) register as
# sound cards with no PCM, and if connected at boot they can grab card 0, breaking JACK.
CARD=$(awk -F'[-:]' '/playback/ {print $1+0; exit}' /proc/asound/pcm 2>/dev/null)
CARD=${CARD:-0}
echo "starting jack on hw:$CARD"
jackd -R -P90 -p16 -t200 -d alsa -dhw:$CARD -p 128 -r 44100 -s -i2 -o2 & echo $! > /tmp/pids/jack.pid
# give jackd a moment so supernova doesn't try to autostart its own jack server
sleep 1
# debian's sclang is built with Qt, which needs this to start without a display
export QT_QPA_PLATFORM=offscreen
echo "starting supercollider from run.sh"
/usr/bin/sclang ./mother.scd "patch.scd" & echo $! > /tmp/pids/sclang.pid
