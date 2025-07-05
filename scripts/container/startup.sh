#!/bin/bash

# Exit on any error
set -e

echo "Starting MX Bikes Server..."

# Load environment variables
if [ -f "/container/config/instance.env" ]; then
    source /container/config/instance.env
fi

# Set up runtime environment
export WINEPREFIX="/container/user_data/wine_prefix"
export PATH="/container/runtime/bin:$PATH"
export LD_LIBRARY_PATH="/container/runtime/lib64:/container/runtime/lib:$LD_LIBRARY_PATH"
export DISPLAY="${XVFB_DISPLAY:-:99}"

# Function to cleanup processes on exit
cleanup() {
    echo "Shutting down server..."
    
    # Kill Xvfb
    if [ -f "/tmp/.X${DISPLAY#:}-lock" ]; then
        pkill Xvfb
    fi
    
    # Shutdown Wine processes gracefully
    wineserver -k
    
    echo "Server shutdown complete"
}

# Register cleanup function
trap cleanup EXIT

echo "Step 1: Validating environment..."
if [ ! -f "/container/mxbikes/server_config.ini" ]; then
    echo "Error: server_config.ini not found. Running generate_server_config.sh..."
    /container/scripts/helpers/generate_server_config.sh
fi

echo "Step 2: Starting Xvfb..."
Xvfb "$DISPLAY" -screen 0 1024x768x16 &
sleep 2

if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo "Error: Failed to start Xvfb"
    exit 1
fi

echo "Step 3: Setting up Wine environment..."
# Ensure Wine prefix directory has correct ownership
if [ "$(id -u)" -eq 0 ]; then
    echo "Running as root, fixing Wine prefix ownership..."
    mkdir -p "$WINEPREFIX"
    chown -R $(logname):$(logname) "$WINEPREFIX"
fi

# Initialize Wine prefix if needed
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "Initializing Wine prefix..."
    if [ "$(id -u)" -eq 0 ]; then
        # Run wineboot as the regular user if we're root
        su - $(logname) -c "WINEPREFIX=$WINEPREFIX wineboot --init"
    else
        wineboot --init
    fi
    sleep 5
fi

echo "Step 4: Starting MX Bikes Server..."
cd /container/mxbikes

# Create logs directory if it doesn't exist
mkdir -p /container/logs
chmod 777 /container/logs

# Run the server
if [ "$(id -u)" -eq 0 ]; then
    # Run wine as the regular user if we're root
    echo "Running as root, starting MX Bikes as regular user..."
    REGULAR_USER=$(logname)
    chown -R $REGULAR_USER:$REGULAR_USER /container/logs
    
    # Start the server as the regular user
    su - $REGULAR_USER -c "cd /container/mxbikes && WINEPREFIX=$WINEPREFIX DISPLAY=$DISPLAY wine mxbikes.exe > /container/logs/server.log 2> /container/logs/server.error.log" &
else
    # Redirect logs to appropriate files
    exec wine "mxbikes.exe" \
        > >(tee -a /container/logs/server.log) \
        2> >(tee -a /container/logs/server.error.log >&2) &
fi

SERVER_PID=$!

echo "Server started with PID: $SERVER_PID"
echo "Live timing port: ${LIVE_TIMING_PORT:-54201}"
echo "Remote admin port: ${REMOTE_ADMIN_PORT:-54230}"
echo "Log files:"
echo "- Server log: /container/logs/server.log"
echo "- Error log: /container/logs/server.error.log"

# Monitor server process
while kill -0 $SERVER_PID 2>/dev/null; do
    sleep 1
done

echo "Server process has terminated"
