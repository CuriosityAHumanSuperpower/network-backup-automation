#!/bin/bash

# filepath: d:\APPRENTISSAGE\PROGRAMMATION\pcloud\myhomecloud_to_pcloud_backup.sh

# Variables
MYHOMECLOUD_REMOTE="\\\\MYCLOUD-HE1NBD/alex/"       # Replace with your rclone remote for myhomecloud
PCLOUD_REMOTE="P:/"                                 # Replace with your rclone remote for pCloud
BACKUP_BASE="myhomecloud_backup/"
BACKUP_BASE_CRYPTO="Crypto Folder/$BACKUP_BASE"
#LOG_FOLDER="$PCLOUD_REMOTE/logs/"
LOG_FOLDER="./logs/"
LOG_FILE="$LOG_FOLDER/rclone_myhomecloud_backup_$(date +%d-%m-%Y"-"%H:%M:%S).log"
STATE_FILE="$LOG_FOLDER/.rclone_monthly_transfer"   # File to track monthly transfer
MAX_TRANSFER_BYTES=$((50 * 1024 * 1024 * 1024))     # 50GB in bytes
START_DAY=16                                        # Day of the month to reset the limit

# Ensure the state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "$(date +%d-%m-%Y"-"%H:%M:%S) $MAX_TRANSFER_BYTES" > "$STATE_FILE"
fi

# Reset the monthly transfer if the current day is >= 16 and the file's last modification date is before the 16th
CURRENT_DAY=$(date +%d)
if [ "$CURRENT_DAY" -ge "$START_DAY" ]; then
    LAST_MODIFIED_DAY=$(date -r "$STATE_FILE" +%d 2>/dev/null || echo "0")
    if [ "$LAST_MODIFIED_DAY" -lt "$START_DAY" ]; then
        echo "$(date +%d-%m-%Y"-"%H:%M:%S) $MAX_TRANSFER_BYTES" > "$STATE_FILE"
        echo "$(date): Monthly transfer reset." >> "$LOG_FILE"
    fi
fi

# Read the current transfer total from the state file
CURRENT_TRANSFER=$(tail -1 "$STATE_FILE" | awk '{print $2}')

# Trap to ensure CURRENT_TRANSFER is saved on exit
trap 'echo "$(date +%d-%m-%Y"-"%H:%M:%S) $((MAX_TRANSFER_BYTES - CURRENT_TRANSFER))" >> "$STATE_FILE"; echo "$(date): Script exited. Transfer state saved." >> "$LOG_FILE"' EXIT

# Function to convert transferred value to bytes
convert_to_bytes() {
    local transferred="$1"
    if [[ "$transferred" == *KiB ]]; then
        echo "$(echo "$transferred" | awk '{printf "%.0f", $1 * 1024}')"
    elif [[ "$transferred" == *MiB ]]; then
        echo "$(echo "$transferred" | awk '{printf "%.0f", $1 * 1024 * 1024}')"
    elif [[ "$transferred" == *GiB ]]; then
        echo "$(echo "$transferred" | awk '{printf "%.0f", $1 * 1024 * 1024 * 1024}')"
    else
        echo "0"
    fi
}

# Function to monitor rclone log and update STATE_FILE
monitor_rclone_log() {
    local log_file="$1"

    # Monitor the log file for "Transferred" updates
    tail -f "$log_file" | while read -r line; do
        # Check if the line contains "Transferred:"
        if [[ "$line" =~ Transferred:\s+([0-9.]+\s\w+) ]]; then
            # Extract the transferred value (e.g., "395.855 MiB")
            TRANSFERRED="${BASH_REMATCH[1]}"

            # Convert the transferred value to bytes
            TRANSFERRED_BYTES=$(convert_to_bytes "$TRANSFERRED")

            # Update the total transfer
            CURRENT_TRANSFER=$((CURRENT_TRANSFER + TRANSFERRED_BYTES))

            # Append the updated transfer state to the STATE_FILE
            echo "$(date +%d-%m-%Y"-"%H:%M:%S) $((MAX_TRANSFER_BYTES - CURRENT_TRANSFER))" >> "$STATE_FILE"
        fi
    done
}

# Updated backup function
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

    # Start monitoring the log file in the background
    monitor_rclone_log "$LOG_FILE" &
    MONITOR_PID=$!

    # Perform the sync with the remaining transfer quota
    rclone sync "$MYHOMECLOUD_REMOTE$source" "$PCLOUD_REMOTE$destination" \
        --max-transfer="$REMAINING_TRANSFER" --log-file="$LOG_FILE" --log-level INFO

    # Wait for the monitor process to finish
    kill "$MONITOR_PID" 2>/dev/null
    wait "$MONITOR_PID" 2>/dev/null

    echo "$(date): Finished backup of $source to $destination" >> "$LOG_FILE"
}

# Backup @DOCUMENTS
#backup_folder "@DOCUMENTS/ADMIN/" "$BACKUP_BASE_CRYPTO/@DOCUMENTS/ADMIN"
#backup_folder "@DOCUMENTS/ARCHIVES" "$BACKUP_BASE/@DOCUMENTS/ARCHIVES"
#backup_folder "@DOCUMENTS/PROGRAMMATION" "$BACKUP_BASE/@DOCUMENTS/PROGRAMMATION"

# Backup @SOUVENIRS
backup_folder "@SOUVENIRS/" "$BACKUP_BASE/@SOUVENIRS"

# Backup @MULTIMEDIA
backup_folder "@MULTIMEDIA/" "$BACKUP_BASE/@MULTIMEDIA"

echo "$(date): Backup process completed." >> "$LOG_FILE"