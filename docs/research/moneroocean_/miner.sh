#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice /home/restudio/moneroocean/xmrig $*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
