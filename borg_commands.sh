# helper function that gets called
# when the name is not given
# and determines which prompt to show
# $1: the prompt mode (latest, generate)
name_prompt() {
  local mode="$1"

  if [ "$mode" == "generate" ]; then
    # prompt user to use the latest backup
    # "generate" uses YES as default
    printf "[BORG] Generate default backup name?(Y/n): "
    read -n 1 -r
    echo
    case "$REPLY" in
    [nN][oO] | [nN])
      echo "       exiting"
      exit 1
      ;;
    *)
      name="latest"
      ;;
    esac
  elif [ "$mode" == "latest" ]; then
    # prompting user to use the latest backup
    # "latest" uses NO as default
    printf "[BORG] Use latest backup?(y/N): "
    read -n 1 -r
    echo
    case "$REPLY" in
    [yY][eE][sS] | [yY])
      name="latest"
      ;;
    *)
      echo "       exiting"
      exit 1
      ;;
    esac
  else
    # just to avoid misuse of the function
    echo "ILLEGAL: Call to function 'name_prompt' with mode: $mode"
    exit 1
  fi
}

# $1: name of the backup
# $2: if exists, automatically set default name
#     "latest" find the latest backup name
#     "generate" generate a new backup name
borg_check_name() {

  name="$1"

  # if "$2" is empty, "$name" MUST be given
  if [ -z "$2" ]; then
    if [ -z "$name" ]; then
      echo "[BORG] name is required"
      exit 1
    fi
  else
    # if name is NOT given, call the prompt function
    if [ -z "$name" ]; then
      name_prompt "$2"
    fi

    # if the name is "latest" (NOT case-sensitive), find/create the latest backup
    if [ "${name,,}" == "latest" ] || [ "${name,,}" == "auto" ]; then

      # if the second argument is "generate", we will set the name
      # to the hostname and current date and time
      if [ "$2" == "generate" ]; then
        name=${HOSTNAME}_$(date +"%Y-%m-%d_%H-%M-%S")
      else
        # else we will search for the latest
        name=$(sudo -E borg list --sort-by timestamp | tail -n 1 | awk '{print $1}')
      fi

      # a bit of logging
      echo "[BORG] using backup: $name"
    fi
  fi
}

borg_init() {
  # ceck if repository exists
  if borg info &>/dev/null; then
    echo "[BORG] Repository already exists"
    exit 0
  fi

  echo "[BORG] Creating remote repository"
  sudo -E borg init --encryption=repokey-blake2 --make-parent-dirs >/dev/null
  echo "[BORG] Repository created"
}

borg_info() {
  echo "[BORG] Service information:"
  if crontab -l | grep -q "$SERVICE_NAME/service.sh"; then
    echo "[BORG] Automatic backups are enabled."
  else
    echo "[BORG] Automatic backups are disabled."
  fi
  echo
  echo "[BORG] Repository information:"
  sudo -E borg info
}

borg_list() {
  echo "[BORG] List of backups:"
  sudo -E borg list
}

borg_backup() {
  borg_check_name "$1" "generate"

  echo "[BORG] Backup current data..."
  sudo -E borg create --stats --progress --compression zlib "::$name" ./volumes
  echo "[BORG] Backup finished"
}

borg_restore() {
  borg_check_name "$1" "latest"

  echo "[BORG] Restore data from backup..."
  BORG_RSH="$(echo $BORG_RSH | sed "s/~/\/home\/$USER/g")"
  sudo -E borg extract --progress "::$name"
  echo "[BORG] Restore finished"
}

borg_export() {
  local file="$1"
  borg_check_name "$2" "latest"

  if [ -z "$file" ]; then
    echo "[BORG] File name is required"
    exit 1
  fi
  if [[ ! "$file" =~ \.tar$ ]]; then
    echo "[BORG] File name must end with .tar"
    exit 1
  fi

  echo "[BORG] Export backup to a .tar file..."
  sudo -E borg export-tar --progress "::$name" $file
  echo "[BORG] Export finished"
}

borg_delete() {
  borg_check_name "$1"

  echo "[BORG] Delete backup..."
  sudo -E borg delete --progress "::$name"
  echo "[BORG] Backup deleted"
}

borg_compact() {
  echo "[BORG] Compact the repository..."
  sudo -E borg compact --progress
  echo "[BORG] Repository compacted"
}

borg_prune() {
  echo "[BORG] Prune old backups..."
  sudo -E borg prune --progress --keep-within 1d --keep-hourly=48 --keep-daily=21 --keep-weekly=16 --keep-monthly=12 --keep-yearly=3
  echo "[BORG] Old backups pruned"
  # executing compact as well, as prune does not delete the data
  borg_compact
}

borg_break-lock() {
  echo "[BORG] Free the repository lock"
  echo "[BORG] Waiting 5 seconds before breaking the lock"
  echo "[BORG] ONLY USE THIS COMMAND IF YOU KNOW WHAT YOU ARE DOING"
  sleep 5
  sudo -E borg break-lock
  echo "[BORG] Repository lock freed"
}

borg_pwgen() {
  echo "[BORG] Generating a new passphrase..."
  echo "BORG_PASSPHRASE=$(openssl rand -base64 48)" >> "../$ENV_FILE"
}

borg_autobackup-enable() {
  if crontab -l | grep -q "$SERVICE_NAME/service.sh"; then
    echo "[BORG] Reenabling automatic hourly backups for this service..."
    borg_autobackup-disable true
  else
    echo "[BORG] Enabling automatic hourly backups for this service..."
  fi
  (crontab -l; echo "0 * * * * $SERVICE_DIR/service.sh borg autobackup-now > $BORG_DIR/autobackup.log 2>&1") | crontab -
  echo "[CRON] Added the following cronjob:"  
  echo "$(crontab -l | grep "$SERVICE_NAME/service.sh")"
}

borg_autobackup-disable() {
  if [ -z "$1" ] || [ "$1" == false ]; then
    echo "[BORG] Disabling automatic hourly backups for this service..."
  fi
  cronjob=$(crontab -l | grep "$SERVICE_NAME/service.sh")
  crontab -l | grep -v "$SERVICE_NAME/service.sh" | crontab -
  echo "[CRON] Removed the following cronjob:"
  echo "$cronjob"
}

borg_autobackup-now() {
  echo "[CRON] Automatic backup started..."
  borg_backup auto
  borg_prune
  if [ ! -z "$BORG_SUCCESS_URL" ]; then
    echo "[CRON] Sending uptime message..."
    curl "$BORG_SUCCESS_URL&$name"
  fi
  echo  
  echo "[CRON] Automatic backup finished"
}
