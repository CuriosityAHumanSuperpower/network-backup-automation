#!/bin/bash

# Source the configuration file
source "$(dirname "$0")/config.sh"

# Ensure the state file exists
if [ ! -f "$state_file" ]; then
    echo "$(date +%Y-%m-%d"-"%H:%M:%S) $max_transfer_bytes" > "$state_file"
fi

# Reset the monthly transfer if the current day is >= $start_day and the file's last modification date is before $start_day
current_day=$(date +%d)
if [ "$current_day" -ge "$start_day" ]; then
    last_modified_day=$(date -r "$state_file" +%d 2>/dev/null || echo "0")
    if [ "$last_modified_day" -lt "$start_day" ]; then
        echo "$(date +%Y-%m-%d"-"%H:%M:%S) $max_transfer_bytes" > "$state_file"
        echo "$(date): Monthly transfer reset." >> "$log_file"
    fi
fi

# Read the current transfer total from the state file
current_transfer=$(tail -1 "$state_file" | awk '{print $2}')

# Trap to ensure current_transfer is saved on exit
trap 'echo "$(date +%Y-%m-%d"-"%H:%M:%S) $((max_transfer_bytes - current_transfer))" >> "$state_file"; echo "$(date): Script exited. Transfer state saved." >> "$log_file"' EXIT

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

# Function to monitor rclone log and update state_file
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
            current_transfer=$((current_transfer + TRANSFERRED_BYTES))

            # Append the updated transfer state to the state_file
            echo "$(date +%Y-%m-%d"-"%H:%M:%S) $((max_transfer_bytes - current_transfer))" >> "$state_file"
        fi
    done
}

# Updated backup function
backup_folder() {
    local source_folder="$1"
    local destination_folder="$2"
    echo "$(date): Starting backup of $source_folder to $destination_folder" >> "$log_file"

    # Calculate the remaining transfer quota
    remaining_transfer=$((max_transfer_bytes - current_transfer))

    # Check if there is any remaining transfer quota
    if [ "$remaining_transfer" -le 0 ]; then
        echo "$(date): Monthly transfer limit reached. Exiting." >> "$log_file"
        exit 0
    fi

    # Start monitoring the log file in the background
    monitor_rclone_log "$log_file" &
    monitor_pid=$!

    # Perform the sync with the remaining transfer quota
    rclone sync "$source_folder" "$destination_folder" \
        --max-transfer="$remaining_transfer" --log-file="$log_file" --log-level INFO

    # Wait for the monitor process to finish
    kill "$monitor_pid" 2>/dev/null
    wait "$monitor_pid" 2>/dev/null

    echo "$(date): Finished backup of $source_folder to $destination_folder" >> "$log_file"
}

# Read the CSV file and run backup_folder for each row
while IFS=',' read -r source_path destination_path; do
    # Skip the header row
    if [[ "$source_path" == "source" && "$destination_path" == "destination" ]]; then
        continue
    fi

    # Run the backup_folder function
    backup_folder "$source_path" "$destination_path"
done < "$(dirname "$0")/backup_paths.csv"

# Final log entry
echo "$(date): Backup process completed." >> "$log_file"