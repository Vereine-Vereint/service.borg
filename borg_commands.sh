# $1: name of the backup
# $2: if exists, automatically set default name
#     "latest" find the latest backup name
#     "generate" generate a new backup name
borg_check_name() {

  name="$1"

  # if "$2" is empty, "$name" will MUST be given
  if [ -z "$2" ]; then
    if [ -z "$name" ]; then
      echo "[BORG] name is required"
      exit 1
    fi
  else
    # if name is NOT given, prompt user to use latest backup
    if [ -z "$name" ]; then
      # promping user to use the latest backup
      read -p "[BORG] Use latest backup?(y/N): " use_latest
      case "$use_latest" in
      [yY][eE][sS]|[yY])
          name="latest"
          ;;
      *)
          echo "       exiting"
          exit 1
          ;;
      esac
    fi

    # if the name is "latest" (NOT case-sensitive), find/create the latest backup
    if [ "${name,,}" == "latest" ] || [ "${name,,}" == "auto" ]; then

      # if the second argument is "generate", we will set the name to the current date and time
      if [ "$2" == "generate" ]; then
        name=$(date +"%Y-%m-%d_%H-%M-%S")
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
  sudo -E borg delete  --progress "::$name"
  echo "[BORG] Backup deleted"
}

borg_compact() {
  echo "[BORG] Compact the repository..."
  sudo -E borg compact --progress
  echo "[BORG] Repository compacted"
}

borg_prune() {
  echo "[BORG] Prune old backups..."
  sudo -E borg prune --progress --keep-hourly=48 --keep-daily=21 --keep-weekly=16 --keep-monthly=12 --keep-yearly=3 # todo keep last hours
  echo "[BORG] Old backups pruned"
}

borg_break-lock() {
  echo "[BORG] Free the repository lock"
  echo "[BORG] Waiting 5 seconds before breaking the lock"
  echo "[BORG] ONLY USE THIS COMMAND IF YOU KNOW WHAT YOU ARE DOING"
  sleep 5
  sudo -E borg break-lock
  echo "[BORG] Repository lock freed"
}
