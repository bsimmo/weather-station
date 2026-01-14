#!/bin/bash
# run-mqtt.sh - Helper script to run mqtt.py with environment variables

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/mqtt.env"
MQTT_SCRIPT="$SCRIPT_DIR/mqtt.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    error "Configuration file not found: $ENV_FILE"
    echo ""
    echo "Create it from the template:"
    echo "  cp mqtt.env.example mqtt.env"
    echo "  nano mqtt.env"
    echo ""
    exit 1
fi

# Check if mqtt.py exists
if [ ! -f "$MQTT_SCRIPT" ]; then
    error "mqtt.py not found: $MQTT_SCRIPT"
    exit 1
fi

info "Loading configuration from: $ENV_FILE"

# Load environment variables from file (ignoring comments and empty lines)
set -a
# shellcheck disable=SC1090
source <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
set +a

# Validate critical settings
if [ -z "$MQTT_SERVER" ]; then
    error "MQTT_SERVER not set in $ENV_FILE"
    exit 1
fi

info "MQTT Server: $MQTT_SERVER:${MQTT_PORT:-1883}"
info "Topic Prefix: ${MQTT_TOPIC_PREFIX:-sensors}"

# Run the script
info "Starting Weather HAT MQTT Publisher..."
echo ""

python3 "$MQTT_SCRIPT"
