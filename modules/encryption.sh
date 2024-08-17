#!/bin/bash

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
    gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -d "${ENV_FILE}.gpg" >"$ENV_FILE"
    log "INFO" ".env file decrypted successfully"
  else
    log "ERROR" "Encrypted .env file not found"
    exit 1
  fi
}

# Function to encrypt backups
encrypt_backups() {
  local dest="$1"
  local timestamp="$2"

  log "INFO" "Encrypting backups"
  find "$dest" -type f -name "*${timestamp}*" -print0 |
    parallel -0 -j$(nproc) gpg --batch --yes --passphrase "$ENCRYPTION_PASSPHRASE" -c {} '&&' rm '{}'
  log "INFO" "Backup encryption completed"
}
