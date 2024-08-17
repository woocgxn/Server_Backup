#!/bin/bash
####################################
#
# Comprehensive Backup Script with Enhanced Interactive Configuration
#
####################################

set -euo pipefail

# Default configuration
BACKUP_TYPE="incremental"
DEST="/path/to/backup"
MAX_BACKUPS=7
ENABLE_DB_BACKUP=true
ENABLE_ENCRYPTION=false
DB_USER="root"
DB_PASSWORD=""
ENCRYPTION_PASSPHRASE=""
BACKUP_FILES=""
DATABASES=()

# Function to validate input
validate_input() {
  local prompt="$1"
  local valid_options="$2"
  local default_value="$3"
  local user_input

  while true; do
    read -p "$prompt [$default_value]: " user_input
    user_input=${user_input:-$default_value}
    if [[ $valid_options =~ (^|[[:space:]])$user_input($|[[:space:]]) ]]; then
      echo "$user_input"
      return
    fi
    echo "Invalid input. Please choose from: $valid_options"
  done
}

# Interactive configuration setup
