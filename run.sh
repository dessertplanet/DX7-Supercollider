cd /tmp/patch
sudo ~/scripts/start-jack.sh
echo "starting supercollider from run.sh"
/usr/local/bin/sclang ./run_me.scd & echo $! > /tmp/pids/sclang.pid