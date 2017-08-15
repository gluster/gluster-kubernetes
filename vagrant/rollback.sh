#!/bin/sh

MACHINES=(${@:-$(vagrant status | grep running | awk '{print $1}')})

vagrant sandbox rollback "${MACHINES[@]}"

for m in ${MACHINES[*]}; do
  echo "[${m}] Restarting services..."
  vagrant ssh "${m}" -c "sudo systemctl restart docker kubelet" 1>/dev/null
done
