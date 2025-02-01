#!/bin/bash

# Configuration
METADATA_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
CHECK_INTERVAL=5  # Seconds between checks
CHECKPOINT_SCRIPT="/opt/scripts/checkpoint.sh"
SIMULATION_PID_FILE="/simulation/lammps.pid"

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    logger -t spot-termination-handler "$1"
}

# Function to check for spot termination notice
check_termination_notice() {
    curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" \
         -s http://169.254.169.254/latest/meta-data/spot/termination-time
}

# Function to handle simulation checkpoint and cleanup
handle_termination() {
    log_message "Spot termination notice received. Starting cleanup..."

    # Get LAMMPS process ID
    if [ -f "$SIMULATION_PID_FILE" ]; then
        LAMMPS_PID=$(cat "$SIMULATION_PID_FILE")
        
        # Send SIGTERM to LAMMPS process
        if kill -15 "$LAMMPS_PID" 2>/dev/null; then
            log_message "Sent SIGTERM to LAMMPS process $LAMMPS_PID"
            
            # Wait for process to handle SIGTERM (max 30 seconds)
            for i in {1..30}; do
                if ! kill -0 "$LAMMPS_PID" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
        else
            log_message "LAMMPS process $LAMMPS_PID not found"
        fi
    fi

    # Run final checkpoint
    log_message "Running final checkpoint..."
    if [ -x "$CHECKPOINT_SCRIPT" ]; then
        "$CHECKPOINT_SCRIPT"
        checkpoint_status=$?
        if [ $checkpoint_status -eq 0 ]; then
            log_message "Final checkpoint completed successfully"
        else
            log_message "ERROR: Final checkpoint failed with status $checkpoint_status"
        fi
    else
        log_message "ERROR: Checkpoint script not found or not executable"
    fi

    # Notify AWS Batch that we're ready for termination
    log_message "Cleanup complete. Ready for termination."
}

# Main loop
log_message "Starting spot termination handler..."

while true; do
    if check_termination_notice >/dev/null; then
        handle_termination
        break
    fi
    sleep $CHECK_INTERVAL
done

exit 0