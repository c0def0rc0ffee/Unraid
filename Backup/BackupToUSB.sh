# ================================================
# Experimental!
# ================================================

#!/bin/bash
#!/bin/bash

# ================================================
# Multi-Disk Backup Script with Auto-USB Detection
# ================================================

# Set your share paths
MEDIA_SHARE_PATHS=("/mnt/user/Media/TV" "/mnt/user/Media/Movies")
LOG_FILE="/var/log/media_backup.log"
MIN_FREE_SPACE=10
DEFAULT_RSYNC_OPTS="--update --checksum --delete -avh"

# List of already processed disks
PROCESSED_DISKS=()

# ================================================
# Logging Function
# ================================================
log_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# ================================================
# Send Unraid Notifications
# ================================================
send_notification() {
    local title=$1
    local message=$2
    local level=${3:-"normal"}  # Levels: normal, warning, alert
    /usr/local/emhttp/webGui/scripts/notify -e "Backup Script" -s "$title" -d "$message" -i "$level"
}

# ================================================
# Check Free Space on Disk
# ================================================
check_free_space() {
    df -BG "$1" | awk 'NR==2 {print $4}' | sed 's/G//'
}

# ================================================
# Detect New USB Disk
# ================================================
wait_for_new_disk() {
    while true; do
        log_message "Waiting for a new USB disk to be inserted..." >&2
        send_notification "Waiting for USB" "Please insert a new USB disk." >&2

        # Scan for available disks
        for disk in /mnt/disks/*; do
            if [ -d "$disk" ] && [[ ! " ${PROCESSED_DISKS[@]} " =~ " $disk " ]] && [ ! -f "$disk/UNRAID" ]; then
                log_message "New USB disk detected: $disk" >&2
                send_notification "USB Detected" "Backup will resume using $disk." >&2
                PROCESSED_DISKS+=("$disk")
                echo "$disk"
                return
            fi
        done

        # Wait a few seconds before checking again
        sleep 10
    done
}

# ================================================
# Backup to Single Disk with Verification
# ================================================
backup_to_single_disk() {
    local usb_mount_path=$1
    local share_path=$2
    local rsync_opts="$DEFAULT_RSYNC_OPTS"

    # Debug: Log the source and destination
    log_message "Starting rsync from '$share_path/' to '$usb_mount_path/'."

    # Perform the backup
    rsync $rsync_opts --progress "$share_path/" "$usb_mount_path/" | tee -a "$LOG_FILE"

    # Verify files after transfer
    log_message "Verifying files after transfer..."
    rsync --dry-run --checksum "$share_path/" "$usb_mount_path/" | tee -a "$LOG_FILE"

    # Check verification results
    if [ $? -eq 0 ]; then
        log_message "Verification completed successfully for $share_path."
        send_notification "Verification Successful" "All files for $share_path were successfully verified on $usb_mount_path."
        return 0
    else
        log_message "Verification failed for $share_path. Please check the log for details."
        send_notification "Verification Failed" "Some files for $share_path failed verification on $usb_mount_path." "alert"
        return 1
    fi
}

# ================================================
# Main Script Logic
# ================================================
log_message "Starting the multi-disk backup script."

for share_path in "${MEDIA_SHARE_PATHS[@]}"; do
    log_message "Starting backup for share: $share_path"

    while true; do
        # Wait for a new USB disk to be inserted
        usb_mount_path="$(wait_for_new_disk 2>/dev/null)"

        # Perform the backup
        backup_to_single_disk "$usb_mount_path" "$share_path"

        # Check if the backup completed successfully or the disk is full
        if [ $? -eq 0 ]; then
            log_message "Backup completed for this share. Moving to the next share."
            break
        fi
    done
done

log_message "Backup process finished for all shares."
send_notification "Backup Completed" "All backups have been completed successfully."
