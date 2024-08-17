#!/bin/bash

# Function for full backup
full_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"

  log "INFO" "Starting full backup of $source"
  rsync -avz --delete "$source" "$dest/$timestamp" ||
    handle_error "Full backup failed for $source"
  log "INFO" "Full backup of $source completed"
}

# Function for incremental backup
incremental_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"

  log "INFO" "Starting incremental backup of $source"
  rsync -avz --link-dest="$dest/latest" "$source" "$dest/$timestamp" ||
    handle_error "Incremental backup failed for $source"

  rm -f "$dest/latest"
  ln -s "$dest/$timestamp" "$dest/latest"
  log "INFO" "Incremental backup of $source completed"
}

# Function for differential backup
differential_backup() {
  local source="$1"
  local dest="$2"
  local timestamp="$3"

  log "INFO" "Starting differential backup of $source"
  rsync -avz --compare-dest="$dest/latest" "$source" "$dest/$timestamp" ||
    handle_error "Differential backup failed for $source"
  log "INFO" "Differential backup of $source completed"
}
