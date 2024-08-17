#!/bin/bash
####################################
#
# Modular Backup Script with Enhanced Features
#
####################################

set -euo pipefail

# Source module files
source "$(dirname "$0")/modules/config.sh"
source "$(dirname "$0")/modules/logging.sh"
source "$(dirname "$0")/modules/backup_functions.sh"
source "$(dirname "$0")/modules/database_backup.sh"
source "$(dirname "$0")/modules/encryption.sh"
source "$(dirname "$0")/modules/rotation.sh"
source "$(dirname "$0")/modules/rollback.sh"
source "$(dirname "$0")/modules/notifications.sh"

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
    log "ERROR" "Invalid backup type: $BACKUP_TYPE"
    exit 1
    ;;
  esac

  echo "$BACKUP_FILES" | tr ' ' '\n' | parallel -j$(nproc) $backup_function {} "$DEST" "$timestamp"

  if [[ "$ENABLE_DB_BACKUP" == "true" ]]; then
    perform_database_backups "$DEST" "$timestamp"
  fi

  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    encrypt_backups "$DEST" "$timestamp"
  fi

  rotate_backups "$DEST" "$MAX_BACKUPS"

  log "INFO" "$BACKUP_TYPE backup completed"
}

# Main script execution
main() {
  log "INFO" "Backup script started"

  parse_command_line_args "$@"
  load_configuration
  validate_configuration

  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    decrypt_env_file
  fi
  load_env

  perform_backup

  if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    encrypt_env_file
  fi

  report_errors

  log "INFO" "Backup script finished"
}

# Call main function
main "$@"
