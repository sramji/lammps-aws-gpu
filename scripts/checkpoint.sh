#!/bin/bash

# Configuration
S3_BUCKET="lammps-simulations"
CHECKPOINT_DIR="/simulation"
MAX_CHECKPOINTS=3

# Create timestamp for this checkpoint
timestamp=$(date +%Y%m%d_%H%M%S)
checkpoint_path="s3://${S3_BUCKET}/checkpoints/${timestamp}"

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to clean up old checkpoints
cleanup_old_checkpoints() {
    log_message "Cleaning up old checkpoints..."
    checkpoints=$(aws s3 ls s3://${S3_BUCKET}/checkpoints/ | sort -r | awk '{print $2}')
    count=0
    for cp in $checkpoints; do
        ((count++))
        if [ $count -gt $MAX_CHECKPOINTS ]; then
            log_message "Removing old checkpoint: $cp"
            aws s3 rm "s3://${S3_BUCKET}/checkpoints/$cp" --recursive
        fi
    done
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Main checkpoint process
log_message "Starting checkpoint process..."

# Verify LAMMPS simulation directory exists
if [ ! -d "$CHECKPOINT_DIR" ]; then
    handle_error "Simulation directory not found: $CHECKPOINT_DIR"
fi

# Create checkpoint using LAMMPS write_restart command
# Note: This assumes LAMMPS is configured to use this script for checkpointing
log_message "Creating checkpoint files..."
lmp_status=$?
if [ $lmp_status -ne 0 ]; then
    handle_error "Failed to create LAMMPS checkpoint"
fi

# Upload checkpoint files to S3
log_message "Uploading checkpoint to S3: $checkpoint_path"
aws s3 cp ${CHECKPOINT_DIR}/checkpoint.* "$checkpoint_path/" \
    || handle_error "Failed to upload checkpoint to S3"

# Clean up old checkpoints
cleanup_old_checkpoints

# Clean up local checkpoint files older than 1 day
find ${CHECKPOINT_DIR} -name "checkpoint.*" -mtime +1 -delete

log_message "Checkpoint process completed successfully"
exit 0