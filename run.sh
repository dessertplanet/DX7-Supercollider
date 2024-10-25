cd /tmp/patch
~/scripts/start-jack.sh
echo "starting supercollider from run.sh"
/usr/local/bin/sclang ./mother.scd & echo $! > /tmp/pids/sclang.pid