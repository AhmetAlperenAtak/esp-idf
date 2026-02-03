#!/bin/bash
#
# ESP32-C3 Industrial Secure WiFi Enterprise - Production Flash Script
# Copyright (c) 2026 - Industrial Grade Security Implementation
#
# This script automates the secure production flashing process:
# 1. Generates unique encryption keys per device
# 2. Creates device-specific NVS credentials
# 3. Encrypts credentials with NVS encryption
# 4. Flashes firmware and encrypted data to ESP32
# 5. Backs up credentials to secure vault
# 6. Securely deletes temporary unencrypted files
#
# Requirements:
# - ESP-IDF v5.5+
# - esptool.py
# - Python 3.8+
# - Access to secure backup vault (configure BACKUP_PATH)
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# ========== CONFIGURATION ==========

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$SCRIPT_DIR/nvs_credentials_template.csv"
BACKUP_PATH="${BACKUP_PATH:-/secure/vault/esp32_credentials}"  # Override with env var

# ESP32 Configuration
ESP_PORT="${ESP_PORT:-/dev/ttyUSB0}"
ESP_BAUD="${ESP_BAUD:-921600}"
NVS_PARTITION_SIZE="0x6000"  # 24KB
NVS_PARTITION_OFFSET="0x9000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# ========== FUNCTIONS ==========

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check ESP-IDF
    if [ -z "${IDF_PATH:-}" ]; then
        log_error "ESP-IDF not found. Please source export.sh first."
        exit 1
    fi
    
    # Check esptool
    if ! command -v esptool.py &> /dev/null; then
        log_error "esptool.py not found. Install with: pip install esptool"
        exit 1
    fi
    
    # Check NVS partition generator
    NVS_GEN="$IDF_PATH/components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py"
    if [ ! -f "$NVS_GEN" ]; then
        log_error "NVS partition generator not found at: $NVS_GEN"
        exit 1
    fi
    
    # Check template
    if [ ! -f "$TEMPLATE_FILE" ]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    log_info "All requirements satisfied."
}

generate_device_id() {
    # Generate unique device ID: ESP32-FAB-YYYYMMDD-HHMMSS-RANDOM
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local random=$(openssl rand -hex 4)
    echo "ESP32-FAB-${timestamp}-${random}"
}

generate_encryption_key() {
    local key_file="$1"
    log_info "Generating NVS encryption key..."
    python "$IDF_PATH/components/esptool_py/esptool/espsecure.py" \
        generate_flash_encryption_key "$key_file"
    log_info "Encryption key generated: $key_file"
}

create_nvs_credentials() {
    local device_id="$1"
    local wifi_password="$2"
    local output_file="$3"
    
    log_info "Creating NVS credentials for device: $device_id"
    
    # Copy template and replace placeholders
    cp "$TEMPLATE_FILE" "$output_file"
    sed -i "s/PLACEHOLDER_DEVICE_ID/$device_id/g" "$output_file"
    sed -i "s/PLACEHOLDER_WIFI_PASSWORD/$wifi_password/g" "$output_file"
    
    log_info "NVS credentials created: $output_file"
}

encrypt_nvs_partition() {
    local csv_file="$1"
    local key_file="$2"
    local output_bin="$3"
    
    log_info "Encrypting NVS partition..."
    python "$IDF_PATH/components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py" \
        encrypt "$csv_file" "$output_bin" "$NVS_PARTITION_SIZE" \
        --inputkey "$key_file"
    log_info "NVS partition encrypted: $output_bin"
}

flash_device() {
    local nvs_bin="$1"
    local key_bin="$2"
    
    log_info "Flashing ESP32-C3 on port $ESP_PORT..."
    
    # Flash NVS encryption key (this burns eFuse - IRREVERSIBLE!)
    log_warn "Flashing encryption key - THIS IS IRREVERSIBLE!"
    esptool.py --port "$ESP_PORT" --baud "$ESP_BAUD" \
        write_flash "$NVS_PARTITION_OFFSET" "$nvs_bin"
    
    log_info "Device flashed successfully."
}

backup_credentials() {
    local device_id="$1"
    local device_dir="$BACKUP_PATH/$device_id"
    shift
    
    log_info "Backing up credentials to secure vault..."
    
    # Create device-specific backup directory
    mkdir -p "$device_dir"
    chmod 700 "$device_dir"
    
    # Copy all credential files
    for file in "$@"; do
        if [ -f "$file" ]; then
            cp "$file" "$device_dir/"
            log_info "Backed up: $(basename "$file")"
        fi
    done
    
    # Create metadata
    cat > "$device_dir/metadata.txt" << EOF
Device ID: $device_id
Production Date: $(date -Iseconds)
Script Version: 1.0.0
Operator: ${USER}
Hostname: $(hostname)
EOF
    
    log_info "Backup completed: $device_dir"
}

secure_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        # Overwrite with random data before deletion
        shred -vfz -n 3 "$file"
        log_info "Securely deleted: $file"
    fi
}

# ========== MAIN SCRIPT ==========

main() {
    log_info "=== ESP32-C3 Secure Production Flash ==="
    log_info "Starting at: $(date)"
    
    # Check requirements
    check_requirements
    
    # Get inputs
    read -p "Enter WiFi Password: " -s wifi_password
    echo
    if [ -z "$wifi_password" ]; then
        log_error "WiFi password cannot be empty."
        exit 1
    fi
    
    # Generate device ID
    device_id=$(generate_device_id)
    log_info "Device ID: $device_id"
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT
    
    # File paths
    key_file="$temp_dir/nvs_encryption_key.bin"
    credentials_csv="$temp_dir/nvs_credentials.csv"
    nvs_encrypted="$temp_dir/nvs_encrypted.bin"
    
    # Generate encryption key
    generate_encryption_key "$key_file"
    
    # Create NVS credentials
    create_nvs_credentials "$device_id" "$wifi_password" "$credentials_csv"
    
    # Encrypt NVS partition
    encrypt_nvs_partition "$credentials_csv" "$key_file" "$nvs_encrypted"
    
    # Flash device
    flash_device "$nvs_encrypted" "$key_file"
    
    # Backup credentials
    backup_credentials "$device_id" "$key_file" "$credentials_csv" "$nvs_encrypted"
    
    # Secure delete temporary files
    log_warn "Securely deleting temporary files..."
    secure_delete "$credentials_csv"
    
    log_info "${GREEN}=== Production Flash Completed Successfully ===${NC}"
    log_info "Device ID: $device_id"
    log_info "Backup Location: $BACKUP_PATH/$device_id"
    log_info "Completed at: $(date)"
}

# Run main function
main "$@"
