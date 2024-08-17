#!/bin/bash
####################################
#
# Comprehensive Backup Script with Interactive Configuration
#
####################################

set -euo pipefail

# Default configuration (can be overridden)
BACKUP_TYPE="incremental" # Default backup type
DEST="/path/to/backup"    # Default backup destination
MAX_BACKUPS=7             # Default number of backups to keep
ENABLE_DB_BACKUP=true     # Default database backup enabled
ENABLE_ENCRYPTION=false   # Default encryption disabled
DB_USER="root"            # Default database user
DB_PASSWORD=""            # Default database password
ENCRYPTION_PASSPHRASE=""  # Default encryption passphrase

# Interactive configuration setup
interactive_setup() {
  echo "Interactive Backup Configuration Setup"
  read -p "Enter backup type (full/incremental/differential): " BACKUP_TYPE
  read -p "Enter backup destination path: " DEST
  read -p "Enter maximum number of backups to keep: " MAX_BACKUPS
  read -p "Enable database backup? (true/false): " ENABLE_DB_BACKUP
  if [[ "$ENABLE_DB_BACKUP" == "true" ]]; then
    read -p "Enter database user: " DB_USER
    read -sp "Enter database password: " DB_PASSWORD
    echo
  fi
  read -p "Enable encryption? (true/false): " ENABLE_ENCRYPTION
  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    read -sp "Enter encryption passphrase: " ENCRYPTION_PASSPHRASE
    echo
  fi
}

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $message"
  if [[ "$level" == "ERROR" ]]; then
    echo "[$timestamp] [$level] $message" >&2
  fi
}

# Error handling function
handle_error() {
  local error_message="$1"
  local error_code="${2:-1}"
  log "ERROR" "$error_message"
  exit "$error_code"
}

# Backup functions (full, incremental, differential)
full_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"
  log "INFO" "Starting full backup of $source"
  rsync -avz --delete "$source" "$dest/$timestamp" || handle_error "Full backup failed for $source"
  log "INFO" "Full backup of $source completed"
}

incremental_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"
  log "INFO" "Starting incremental backup of $source"
  rsync -avz --link-dest="$dest/latest" "$source" "$dest/$timestamp" || handle_error "Incremental backup failed for $source"
  rm -f "$dest/latest"
  ln -s "$dest/$timestamp" "$dest/latest"
  log "INFO" "Incremental backup of $source completed"
}

differential_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"
  log "INFO" "Starting differential backup of $source"
  rsync -avz --compare-dest="$dest/latest" "$source" "$dest/$timestamp" || handle_error "Differential backup failed for $source"
  log "INFO" "Differential backup of $source completed"
}

# Database backup function
database_backup() {
  local db="$1"
  local dest="$2"
  local timestamp="$3"
  log "INFO" "Starting backup of database $db"
  nice -n 19 ionice -c2 -n7 mysqldump --single-transaction -u "$DB_USER" -p"$DB_PASSWORD" "$db" |
    pv | pigz -9 >"$dest/${db}_${timestamp}.sql.gz" || handle_error "Database backup failed for $db"
  log "INFO" "Backup of database $db completed"
}

# Backup rotation function
rotate_backups() {
  local dest="$1"
  local max_backups="$2"
  log "INFO" "Starting backup rotation"
  local backups=($(ls -1tr "$dest"))
  local num_backups=${#backups[@]}
  if ((num_backups > max_backups)); then
    local num_delete=$((num_backups - max_backups))
    for ((i = 0; i < num_delete; i++)); do
      rm -rf "$dest/${backups[i]}"
      log "INFO" "Deleted old backup: ${backups[i]}"
    done
  fi
  log "INFO" "Backup rotation completed"
}

# Main backup function
perform_backup() {
  local timestamp=$(date +%Y%m%d_%H%M%S)
  log "INFO" "Starting $BACKUP_TYPE backup"

  case "$BACKUP_TYPE" in
  full)
    backup_function=full_backup
    ;;
  incremental)
    backup_function=incremental_backup
    ;;
  differential)
    backup_function=differential_backup
    ;;
  *)
    handle_error "Invalid backup type: $BACKUP_TYPE"
    ;;
  esac

  echo "$BACKUP_FILES" | tr ' ' '\n' | while read -r file; do
    $backup_function "$file" "$DEST" "$timestamp"
  done

  if [[ "$ENABLE_DB_BACKUP" == "true" ]]; then
    log "INFO" "Starting database backups"
    for db in "${DATABASES[@]}"; do
      database_backup "$db" "$DEST" "$timestamp"
    done
    log "INFO" "Database backups completed"
  fi

  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    log "INFO" "Encrypting backups"
    find "$DEST" -type f -name "*${timestamp}*" -print0 |
      while IFS= read -r -d '' file; do
        gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$file" && rm "$file"
      done
    log "INFO" "Backup encryption completed"
  fi

  rotate_backups "$DEST" "$MAX_BACKUPS"
  log "INFO" "$BACKUP_TYPE backup completed"
}

# Main script execution
main() {
  log "INFO" "Backup script started"
  interactive_setup
  perform_backup
  log "INFO" "Backup script finished"
}

main "$@"
