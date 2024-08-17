#!/bin/bash
####################################
#
# Advanced Backup Script with Multiple Backup Strategies, Enhanced Security, and Comprehensive Logging
#
####################################

set -euo pipefail

# Configuration and environment files
CONFIG_FILE="/path/to/backup_config.sh"
ENV_FILE="/path/to/.env"

# Logging setup
LOG_FILE="/var/log/backup_script.log"
LOG_LEVEL="INFO"  # Possible values: DEBUG, INFO, WARN, ERROR

# Array to store errors
ERRORS=()

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    if [[ "$level" == "ERROR" ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

# Function to encrypt .env file
encrypt_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        log "INFO" "Encrypting .env file"
        gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c "$ENV_FILE" && rm "$ENV_FILE"
        log "INFO" ".env file encrypted successfully"
    else
        log "WARN" ".env file not found, skipping encryption"
    fi
}

# Function to decrypt .env file
decrypt_env_file() {
    if [[ -f "${ENV_FILE}.gpg" ]]; then
        log "INFO" "Decrypting .env file"
        gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "${ENV_FILE}.gpg" > "$ENV_FILE"
        log "INFO" ".env file decrypted successfully"
    else
        log "ERROR" "Encrypted .env file not found"
        exit 1
    fi
}

# Load environment variables
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    else
        log "ERROR" ".env file not found"
        exit 1
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

# Database backup function
database_backup() {
    local db="$1"
    local dest="$2"
    local timestamp="$3"

    log "INFO" "Starting backup of database $db"
    nice -n 19 ionice -c2 -n7 mysqldump --single-transaction -u "$DB_USER" -p"$DB_PASSWORD" "$db" |
        pv | pigz -9 > "$dest/${db}_${timestamp}.sql.gz" ||
        handle_error "Database backup failed for $db"
    log "INFO" "Backup of database $db completed"
}

# Backup rotation function
rotate_backups() {
    local dest="$1"
    local max_backups="$2"

    log "INFO" "Starting backup rotation"
    local backups=($(ls -1tr "$dest"))
    local num_backups=${#backups[@]}

    if (( num_backups > max_backups )); then
        local num_delete=$((num_backups - max_backups))
        for (( i=0; i<num_delete; i++ )); do
            rm -rf "$dest/${backups[i]}"
            log "INFO" "Deleted old backup: ${backups[i]}"
        done
    fi
    log "INFO" "Backup rotation completed"
}

# Main backup function
perform_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_type="$1"

    log "INFO" "Starting $backup_type backup"

    case "$backup_type" in
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
            log "ERROR" "Invalid backup type: $backup_type"
            exit 1
            ;;
    esac

    echo "$BACKUP_FILES" | tr ' ' '\n' | parallel -j$(nproc) $backup_function {} "$DEST" "$timestamp"

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
            parallel -0 -j$(nproc) gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c {} '&&' rm '{}'
        log "INFO" "Backup encryption completed"
    fi

    rotate_backups "$DEST" "$MAX_BACKUPS"

    log "INFO" "$backup_type backup completed"
}

# Configuration validation function
validate_config() {
    log "INFO" "Validating configuration"
    # Add configuration validation logic here
    log "INFO" "Configuration validation completed"
}

# Main script execution
main() {
    log "INFO" "Backup script started"

    # Parse command-line options
    local backup_type="incremental"
    while getopts ":ht:c:" opt; do
        case ${opt} in
            h )
                show_help
                exit 0
                ;;
            t )
                backup_type=$OPTARG
                ;;
            c )
                CONFIG_FILE=$OPTARG
                ;;
            \? )
                log "ERROR" "Invalid Option: -$OPTARG"
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Load and validate configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR" "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    source "$CONFIG_FILE"
    validate_config

    # Decrypt and load environment variables
    decrypt_env_file
    load_env

    # Perform backup
    perform_backup "$backup_type"

    # Encrypt sensitive data
    encrypt_env_file

    # Report errors
    if [[ ${#ERRORS[@]} -ne 0 ]]; then
        log "ERROR" "The following errors occurred during the backup process:"
        for error in "${ERRORS[@]}"; do
            log "ERROR" "- $error"
        done
        # Add integration with monitoring/alerting systems here
    else
        log "INFO" "Backup completed successfully without any errors"
    fi

    log "INFO" "Backup script finished"
}

# Show help function
show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-t TYPE] [-c CONFIG_FILE]

This script performs advanced backups with multiple strategies, enhanced security, and comprehensive logging.

    -h              Display this help and exit
    -t TYPE         Specify backup type: full, incremental, or differential (default: incremental)
    -c CONFIG_FILE  Use CONFIG_FILE as the configuration file

For more information, please refer to the README.md file.
EOF
}

# Call main function
main "$@"
