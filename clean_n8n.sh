#!/bin/bash

# Configuration
BINARY_DATA_DIR="/opt/n8n/binaryData"
N8N_DATA_DIR="/opt/n8n/n8n_data"
LOG_FILE="/var/log/n8n_cleaner.log"

echo "=== n8n Storage Cleaner Run: $(date) ===" >> "$LOG_FILE"

# Rule 1: Delete files > 500MB that are older than 1 hour (60 minutes)
echo "Rule 1: Checking for files > 500MB older than 1 hour..." >> "$LOG_FILE"
DELETED_RULE1=$(find "$BINARY_DATA_DIR" -type f -size +500M -mmin +60 -print -delete 2>/dev/null | wc -l)
echo "Rule 1: Deleted $DELETED_RULE1 file(s) > 500MB." >> "$LOG_FILE"

# Rule 2: If server disk space usage is >= 90%
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
echo "Current Server Disk Usage: ${DISK_USAGE}%" >> "$LOG_FILE"

if [ "$DISK_USAGE" -ge 90 ]; then
    echo "Rule 2 Triggered! Disk usage is ${DISK_USAGE}% (>= 90%). Starting emergency cleanup..." >> "$LOG_FILE"
    
    # 2a. Delete files > 100MB that are older than 2 hours (120 minutes)
    DELETED_RULE2=$(find "$BINARY_DATA_DIR" -type f -size +100M -mmin +120 -print -delete 2>/dev/null | wc -l)
    echo "Rule 2: Deleted $DELETED_RULE2 heavy file(s) (>100MB, >2h)." >> "$LOG_FILE"
    
    # 2b. Clean up old rotated event logs in n8n_data
    echo "Rule 2: Cleaning up rotated n8n log files..." >> "$LOG_FILE"
    rm -f "$N8N_DATA_DIR"/n8nEventLog-*.log 2>/dev/null
    
    # 2c. Run heavy Docker pruning to reclaim gigabytes of space
    echo "Rule 2: Running Docker system prune..." >> "$LOG_FILE"
    docker system prune -a --volumes -f >> "$LOG_FILE" 2>&1
fi

# Periodic maintenance: Clean up empty directories in binaryData (runs every time)
find "$BINARY_DATA_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null

echo "=== Cleanup finished: $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
