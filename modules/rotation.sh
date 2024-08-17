#!/bin/bash

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
