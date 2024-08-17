#!/bin/bash

# Logging setup
LOG_FILE="/var/log/backup_script.log"
LOG_LEVEL="INFO" # Possible values: DEBUG, INFO, WARN, ERROR

# Array to store errors
ERRORS=()

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
  if [[ "$level" == "ERROR" ]]; then
    echo "[$timestamp] [$level] $message" >&2
  fi
}

# Improved error handling function
handle_error() {
  local error_message="$1"
  local error_code="${2:-1}"
  log "ERROR" "$error_message"
  ERRORS+=("$error_message")
  return "$error_code"
}

# Function to report errors
report_errors() {
  if [[ ${#ERRORS[@]} -ne 0 ]]; then
    log "ERROR" "The following errors occurred during the backup process:"
    for error in "${ERRORS[@]}"; do
      log "ERROR" "- $error"
    done
    send_error_notification
  else
    log "INFO" "Backup completed successfully without any errors"
    send_success_notification
  fi
}
