#!/usr/bin/env sh
set -eu

mkdir -p /tmp/ccdc

#DROP ../failsafe_creator.sh /tmp/ccdc/failsafe_creator.sh
#DROP ../root_locker.sh /tmp/ccdc/root_locker.sh
#DROP ../user_locker.sh /tmp/ccdc/user_locker.sh
#DROP ../run_all.sh /tmp/ccdc/run_all.sh
#DROP allowlist.txt /tmp/ccdc/allowlist.txt

chmod 700 /tmp/ccdc/*.sh
sh /tmp/ccdc/run_all.sh /tmp/ccdc/allowlist.txt
