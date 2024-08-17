#!/bin/bash

# Function to perform rollback
perform_rollback() {
  local dest="$1"
  local timestamp="$2"

  log "INFO" "Starting rollback to previous backup"
  local previous_backup=$(ls -1tr "$dest" | tail -n 2 | head -n 1)

  if [[ -z "$previous_backup" ]]; then
    log "ERROR" "No previous backup found for rollback"
    return 1
  fi

  # Remove the failed backup
  rm -rf "$dest/$timestamp"

  # Restore the previous backup as the latest
  rm -f "$dest/latest"
  ln -s "$dest/$previous_backup" "$dest/latest"

  log "INFO" "Rollback completed. Restored to backup: $previous_backup"
}
