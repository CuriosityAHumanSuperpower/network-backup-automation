#!/bin/bash

# Source the configuration file
source "$(dirname "$0")/config.sh"

# Ensure log folder exists
mkdir -p "$log_folder"

# Updated backup function
backup_folder() {
    local source_folder="$1"
    local destination_folder="$2"
    echo "$(date): Starting backup of $source_folder to $destination_folder" >> "$log_file"

    # Set remaining transfer to default max
    remaining_transfer=$max_transfer_bytes

    # Log the date and remaining transfer
    echo "$(date +%Y-%m-%d),$remaining_transfer" >> "$transfer_log"

    # Perform the sync with the max transfer quota
    rclone sync "$source_folder" "$destination_folder" \
        --max-transfer="$remaining_transfer" \
        --log-file="$log_file" \
        --log-level INFO \
        --progress \
        --exclude "$exclude_patterns" \
        --multi-thread-streams=0

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