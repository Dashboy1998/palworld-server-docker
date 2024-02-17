#!/bin/bash
# shellcheck source=/dev/null
source "/home/steam/server/helper_functions.sh"

if [[ ! "${PUID}" -eq 0 ]] && [[ ! "${PGID}" -eq 0 ]]; then
    LogAction "EXECUTING USERMOD"
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
else
    LogError "Running as root is not supported, please fix your PUID and PGID!"
    exit 1
fi

mkdir -p /palworld/backups
chown -R steam:steam /palworld /home/steam/

# shellcheck disable=SC2317
term_handler() {
    DiscordMessage "${DISCORD_PRE_SHUTDOWN_MESSAGE}" "in-progress"

    if ! shutdown_server; then
        # If it fails then kill the server
        kill -SIGTERM "$(pidof PalServer-Linux-Test)"
    fi

    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

su steam -c ./start.sh &
# Process ID of su
killpid="$!"
wait "$killpid"

mapfile -t backup_pids < <(pgrep backup)
if [ "${#backup_pids[@]}" -ne 0 ]; then
    LogInfo "Waiting for backup to finish"
    for pid in "${backup_pids[@]}"; do
        tail --pid="$pid" -f 2>/dev/null
    done
fi

mapfile -t restore_pids < <(pgrep restore)
if [ "${#restore_pids[@]}" -ne 0 ]; then
    LogInfo "Waiting for restore to finish"
    for pid in "${restore_pids[@]}"; do
        tail --pid="$pid" -f 2>/dev/null
    done
fi
