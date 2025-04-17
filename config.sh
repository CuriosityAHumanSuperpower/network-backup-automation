# Configuration file for myhomecloud_to_pcloud_backup.sh

# Logs
log_folder="./logs/"
log_file="$log_folder/rclone_myhomecloud_backup_$(date +%Y-%m-%d"-"%H.%M.%S).log"
state_file="$log_folder/.rclone_monthly_transfer"   # File to track monthly transfer

# Transfer limits
max_transfer_bytes=$((50 * 1024 * 1024 * 1024))     # 50GB in bytes
start_day=16                                        # Day of the month to reset the limit
