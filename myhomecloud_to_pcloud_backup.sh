#!/bin/bash

# filepath: d:\APPRENTISSAGE\PROGRAMMATION\pcloud\myhomecloud_to_pcloud_backup.sh

# Variables
MYHOMECLOUD_REMOTE="\\\\MYCLOUD-HE1NBD/alex/"    # Replace with your rclone remote for myhomecloud
PCLOUD_REMOTE="P:/"                              # Replace with your rclone remote for pCloud
BACKUP_BASE="myhomecloud_backup/"
BACKUP_BASE_CRYPTO="Crypto Folder/$BACKUP_BASE/"
LOG_FOLDER="$PCLOUD_REMOTE/logs/"
LOG_FILE="$LOG_FOLDER/rclone_myhomecloud_backup.log"
STATE_FILE="$LOG_FOLDER/.rclone_monthly_transfer"      # File to track monthly transfer
MAX_TRANSFER_BYTES=$((50 * 1024 * 1024 * 1024))  # 50GB in bytes
START_DAY=16                                     # Day of the month to reset the limit

# Ensure the state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

# Reset the monthly transfer if the current day is >= 16 and the file's last modification date is before the 16th
CURRENT_DAY=$(date +%d)
if [ "$CURRENT_DAY" -ge "$START_DAY" ]; then
    LAST_MODIFIED_DAY=$(date -r "$STATE_FILE" +%d 2>/dev/null || echo "0")
    if [ "$LAST_MODIFIED_DAY" -lt "$START_DAY" ]; then
        echo "0" > "$STATE_FILE"
        echo "$(date): Monthly transfer reset." >> "$LOG_FILE"
    fi
fi

# Read the current transfer total from the state file
CURRENT_TRANSFER=$(cat "$STATE_FILE")

# Backup function
backup_folder() {
    local source="$1"
    local destination="$2"
    echo "$(date): Starting backup of $source to $destination" >> "$LOG_FILE"

    # Calculate the remaining transfer quota
    REMAINING_TRANSFER=$((MAX_TRANSFER_BYTES - CURRENT_TRANSFER))

    # Check if there is any remaining transfer quota
    if [ "$REMAINING_TRANSFER" -le 0 ]; then
        echo "$(date): Monthly transfer limit reached. Exiting." >> "$LOG_FILE"
        exit 0
    fi

    # Perform the sync with the remaining transfer quota
    rclone sync "$MYHOMECLOUD_REMOTE$source" "$PCLOUD_REMOTE$destination" \
        --max-transfer="$REMAINING_TRANSFER" --log-file="$LOG_FILE" --log-level INFO

    # Capture the transferred bytes from the log
    TRANSFERRED=$(grep -oP 'Transferred:\s+\K[\d.]+\s\w+' "$LOG_FILE" | tail -1)

    # Convert the transferred value to bytes
    if [[ "$TRANSFERRED" == *KiB ]]; then
        TRANSFERRED_BYTES=$(echo "$TRANSFERRED" | awk '{printf "%.0f", $1 * 1024}')
    elif [[ "$TRANSFERRED" == *MiB ]]; then
        TRANSFERRED_BYTES=$(echo "$TRANSFERRED" | awk '{printf "%.0f", $1 * 1024 * 1024}')
    elif [[ "$TRANSFERRED" == *GiB ]]; then
        TRANSFERRED_BYTES=$(echo "$TRANSFERRED" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024}')
    else
        TRANSFERRED_BYTES=0
    fi

    # Update the total transfer
    CURRENT_TRANSFER=$((CURRENT_TRANSFER + TRANSFERRED_BYTES))
    echo "$CURRENT_TRANSFER" > "$STATE_FILE"

    echo "$(date): Finished backup of $source to $destination" >> "$LOG_FILE"
}

# Backup @DOCUMENTS
backup_folder "@DOCUMENTS/ADMIN/" "$BACKUP_BASE_CRYPTO/@DOCUMENTS/ADMIN"
backup_folder "@DOCUMENTS/" "$BACKUP_BASE/@DOCUMENTS"

# Backup @SOUVENIRS
backup_folder "@SOUVENIRS/" "$BACKUP_BASE/@SOUVENIRS"

# Backup @MULTIMEDIA
backup_folder "@MULTIMEDIA/" "$BACKUP_BASE/@MULTIMEDIA"

echo "$(date): Backup process completed." >> "$LOG_FILE"