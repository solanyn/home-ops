#!/bin/sh
set -e

create_directories() {
    if [ -z "$BUCKETS" ]; then
        echo "No directories specified"
        return 0
    fi

    echo "Creating directories from environment variable..."
    echo "Directories to create:"
    echo "$BUCKETS"
    echo "---"

    # Process each line
    echo "$BUCKETS" | while read -r dir; do
        # Skip empty lines
        if [ -n "$dir" ]; then
            if mkdir -p "$dir" 2>/dev/null; then
                echo "✓ Created: $dir"
                chmod 755 "$dir" 2>/dev/null || true
            else
                echo "✗ Failed to create: $dir"
            fi
        fi
    done
}

# Get interval from environment variable (default to 300 seconds = 5 minutes)
INTERVAL=${INTERVAL_SECONDS:-300}

echo "Directory creator sidecar starting..."
echo "Check interval: ${INTERVAL} seconds"

# Initial directory creation
create_directories

# Run on interval as a proper sidecar
while true; do
    echo "Sleeping for ${INTERVAL} seconds..."
    sleep "$INTERVAL"

    echo "$(date): Periodic directory check..."
    create_directories
done
