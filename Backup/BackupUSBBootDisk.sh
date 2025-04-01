#!/bin/bash
backup_dir="/mnt/user/backups/unraid-usb"
mkdir -p "$backup_dir"
cp -r /boot/* "$backup_dir/"
logger "Unraid USB backup completed."
