#!/bin/bash

# Source the configuration file
source "$(dirname "$0")/config.sh"

# Ensure the state file exists
if [ ! -f "$state_file" ]; then
    echo "$(date +%Y-%m-%d"-"%H:%M:%S) 0" > "$state_file"
fi

# Function to reset monthly transfer to max if conditions are met
reset_monthly_transfert_to_max() {
    local last_modified_day="$1"
    current_day=$(date +%d)
    if [ "$current_day" -gt "$start_day" ]; then
        if [ "$last_modified_day" -lt "$start_day" ]; then
            echo "$(date): Monthly transfer reset to max." >> "$log_file"
            return 0  # true
        fi
    fi
    return 1  # false
}

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

# Function to calculate remaining transfer based on the last log file
calculate_remaining_transfer() {
    # Find the most recent log file by creation date
    last_log_file=$(ls -t "$log_folder"/"$log_file_template_name"_*.log | head -n 1)

    if [ -z "$last_log_file" ]; then
        # No previous log file exists, set remaining transfer to max
        echo "$(date): No previous log file found. Setting remaining transfer to max." >> "$log_file"
        echo "$max_transfer_bytes"
        return
    fi

    # Extract the last TRANSFERRED value and its modification date from the log file
    last_transferred_line=$(grep -nE 'Transferred:\s+[0-9.]+\s+[KMG]iB' "$last_log_file" | tail -n 1)
    last_transferred=$(echo "$last_transferred_line" | awk -F ':' '{print $2}' | awk '{print $2, $3}')
    last_transferred_line_number=$(echo "$last_transferred_line" | awk -F ':' '{print $1}')

    if [ -z "$last_transferred" ]; then
        # No TRANSFERRED data found, set remaining transfer to max
        echo "$(date): No TRANSFERRED data found in $last_log_file. Setting remaining transfer to max." >> "$log_file"
        echo "$max_transfer_bytes"
        return
    fi

    # Get the last modification date just above the matching TRANSFERRED line
    last_modification_date=$(head -n "$last_transferred_line_number" "$last_log_file" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')

    # Check if reset conditions are met
    if reset_monthly_transfert_to_max "last_modification_date"; then
        echo "$(date): Reset conditions met. Ignoring previous TRANSFERRED data." >> "$log_file"
        echo "$max_transfer_bytes"
        return
    fi

    # Convert the last transferred value to bytes
    transferred_bytes=$(convert_to_bytes "$last_transferred")

    # Calculate remaining transfer
    remaining_transfer=$((max_transfer_bytes - transferred_bytes))

    if [ "$remaining_transfer" -le 0 ]; then
        echo "$(date): Monthly transfer limit reached. Remaining transfer set to 0." >> "$log_file"
        echo "0"
    else
        echo "$(date): Remaining transfer calculated: $remaining_transfer bytes." >> "$log_file"
        echo "$remaining_transfer"
    fi
}

# Updated backup function
backup_folder() {
    local source_folder="$1"
    local destination_folder="$2"
    echo "$(date): Starting backup of $source_folder to $destination_folder" >> "$log_file"

    # Calculate the remaining transfer quota
    remaining_transfer=$(calculate_remaining_transfer)

    # Check if there is any remaining transfer quota
    if [ "$remaining_transfer" -le 0 ]; then
        echo "$(date): Monthly transfer limit reached. Exiting." >> "$log_file"
        exit 0
    fi

    # Perform the sync with the remaining transfer quota
    rclone sync "$source_folder" "$destination_folder" \
        --max-transfer="$remaining_transfer" --log-file="$log_file" --log-level INFO

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