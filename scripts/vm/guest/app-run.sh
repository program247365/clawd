#!/bin/sh
# As root in the guest: the real app for 25 minutes with roaming on. Logs memory every 30 seconds to
# ~/s/app.log, locks the screen at 2 minutes, and relaunches him while locked at 10 minutes.
# Where his window is goes to ~/s/watch.log: spaces7=[1] is the desktop, spaces7=[] is the lock screen.
G="launchctl asuser 501 sudo -u admin"
D=/Users/admin/s; L=$D/app.log; : > $L
say() { echo "$(date +%T) $*" >> $L; }
pkill -x Deskling
$G defaults write sh.kbr.deskling roams -bool true
$G defaults write sh.kbr.deskling visitsLockScreen -bool true
$G open $D/Deskling.app; say "opened"
$G sh -c "cd $D && nohup ./watch $D 1560 >/dev/null 2>&1 &"
i=0
while [ $i -lt 50 ]; do
  sleep 30; i=$((i+1))
  p=$(pgrep -x Deskling); [ -n "$p" ] && say "mem $(footprint $p | grep phys_footprint | tr -s ' ' | tr '\n' ' ')" || say "mem NOT RUNNING"
  case $i in
    4) say "LOCK $($G $D/lock)";;
    20) say "RELAUNCH while locked"; pkill -x Deskling; sleep 3; $G open $D/Deskling.app;;
  esac
done
say done
