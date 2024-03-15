borg_check_name() {
  name="$1"
  if [ -z "$name" ]; then
    echo "[BORG] Backup name is required"
    exit 1
  fi
}

borg_init() {
  # ceck if repository exists
  if borg info &>/dev/null; then
    echo "[BORG] Repository already exists"
    exit 0
  fi

  echo "[BORG] Creating remote repository"
  borg init --encryption=repokey-blake2 --make-parent-dirs >/dev/null
  echo "[BORG] Repository created"
}

borg_info() {
  echo "[BORG] Repository information:"
  borg info
}

borg_list() {
  echo "[BORG] List of backups:"
  borg list
}

borg_backup() {
  borg_check_name "$1"
  # TODO allow "LATEST" and auto name the image

  echo "[BORG] Backup current data..."
  sudo -E borg create --stats --progress --compression zlib "::$name" ./volumes
  echo "[BORG] Backup finished"
}

borg_restore() {
  borg_check_name "$1"
  # TODO allow "LATEST" and load the latest backup

  echo "[BORG] Restore data from backup..."
  sudo -E borg extract --progress "::$name"
  echo "[BORG] Restore finished"
}

borg_export() {
  borg_check_name "$1"
  local file="$2"

  if [ -z "$file" ]; then
    echo "[BORG] File name is required"
    exit 1
  fi
  if [[ ! "$file" =~ \.tar$ ]]; then
    echo "[BORG] File name must end with .tar"
    exit 1
  fi

  echo "[BORG] Export backup to a .tar file..."
  borg export-tar --progress "::$name" $file
  echo "[BORG] Export finished"
}

borg_delete() {
  borg_check_name "$1"

  echo "[BORG] Delete backup..."
  borg delete  --progress "::$name"
  echo "[BORG] Backup deleted"
}

borg_compact() {
  echo "[BORG] Compact the repository..."
  borg compact --progress
  echo "[BORG] Repository compacted"
}

borg_prune() {
  echo "[BORG] Prune old backups..."
  borg prune --progress --keep-hourly=48 --keep-daily=21 --keep-weekly=16 --keep-monthly=12 --keep-yearly=3 # todo keep last hours
  echo "[BORG] Old backups pruned"
}

borg_break-lock() {
  echo "[BORG] Free the repository lock"
  echo "[BORG] Waiting 5 seconds before breaking the lock"
  echo "[BORG] ONLY USE THIS COMMAND IF YOU KNOW WHAT YOU ARE DOING"
  sleep 5
  borg break-lock
  echo "[BORG] Repository lock freed"
}
