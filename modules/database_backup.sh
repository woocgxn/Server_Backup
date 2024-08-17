#!/bin/bash

# Database backup function
database_backup() {
  local db="$1"
  local dest="$2"
  local timestamp="$3"

  log "INFO" "Starting backup of database $db"
  nice -n 19 ionice -c2 -n7 mysqldump --single-transaction -u "$DB_USER" -p"$DB_PASSWORD" "$db" |
    pv | pigz -9 >"$dest/${db}_${timestamp}.sql.gz" ||
    handle_error "Database backup failed for $db"
  log "INFO" "Backup of database $db completed"
}

# Function to perform all database backups
perform_database_backups() {
  local dest="$1"
  local timestamp="$2"

  log "INFO" "Starting database backups"
  for db in "${DATABASES[@]}"; do
    database_backup "$db" "$dest" "$timestamp"
  done
  log "INFO" "Database backups completed"
}
