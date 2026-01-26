#!/bin/bash
# install-display-service.sh
# Installs the Weather HAT display service
# Note: Run install-service.sh first to set up the weather user and virtualenv

set -e

SERVICE_NAME="weatherhat-display"
SERVICE_USER="weather"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PROJECT="$(dirname "$SCRIPT_DIR")"
TARGET_PROJECT="/home/$SERVICE_USER/weather-station"
SOURCE_SERVICE="$SOURCE_PROJECT/weatherhat-display.service"
VENV_PATH="/home/$SERVICE_USER/.virtualenvs/pimoroni"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
prompt() { echo -e "${BLUE}[?]${NC} $1"; }

# Check for root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo $0"
    exit 1
fi

# Check service file exists
if [ ! -f "$SOURCE_SERVICE" ]; then
    error "Service file not found: $SOURCE_SERVICE"
    exit 1
fi

echo "=========================================="
echo "Weather HAT Display Service Installer"
echo "=========================================="
echo ""
info "Service user: $SERVICE_USER"
info "Target project: $TARGET_PROJECT"
echo ""

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    if ! id "$SERVICE_USER" &>/dev/null; then
        error "User '$SERVICE_USER' does not exist"
        error "Run install-service.sh first to set up the user"
        exit 1
    fi

    if [ ! -d "$VENV_PATH" ]; then
        error "Virtual environment not found at $VENV_PATH"
        error "Run install-service.sh first to set up the environment"
        exit 1
    fi

    if [ ! -d "$TARGET_PROJECT" ]; then
        error "Project not found at $TARGET_PROJECT"
        error "Run install-service.sh first to set up the project"
        exit 1
    fi

    info "Prerequisites OK"
}

# Check font dependencies
check_fonts() {
    info "Checking font dependencies..."

    if ! sudo -u "$SERVICE_USER" "$VENV_PATH/bin/python" -c "import fonts" 2>/dev/null; then
        warn "Font packages not installed"
        echo ""
        prompt "Install font packages now? [Y/n] "
        read -p "" -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            info "Installing fonts..."
            sudo -u "$SERVICE_USER" "$VENV_PATH/bin/pip" install fonts font-manrope
            info "Fonts installed"
        fi
    else
        info "Font packages installed"
    fi
}

# Stop existing service if running
stop_existing() {
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        info "Stopping existing $SERVICE_NAME service..."
        systemctl stop "$SERVICE_NAME"
    fi
}

# Install the service file
install_service() {
    info "Installing service file to $SERVICE_FILE..."
    cp "$SOURCE_SERVICE" "$SERVICE_FILE"
    chmod 644 "$SERVICE_FILE"

    info "Reloading systemd daemon..."
    systemctl daemon-reload
}

# Enable and start service
enable_service() {
    info "Enabling $SERVICE_NAME to start on boot..."
    systemctl enable "$SERVICE_NAME"

    read -p "Start service now? [Y/n] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "Starting $SERVICE_NAME service..."
        systemctl start "$SERVICE_NAME"
        sleep 3

        echo ""
        info "Service status:"
        systemctl status "$SERVICE_NAME" --no-pager -l || true
    fi
}

# Show useful commands
show_commands() {
    echo ""
    echo "=========================================="
    info "Installation complete!"
    echo "=========================================="
    echo ""
    echo "Display Features:"
    echo "  - Sleeps by default (power saving)"
    echo "  - Press any button to wake"
    echo "  - A: Overview | B: Temp | X: Wind | Y: Rain"
    echo "  - Auto-sleep after 30 seconds"
    echo ""
    echo "Useful commands:"
    echo ""
    echo "  # Check service status"
    echo "  sudo systemctl status $SERVICE_NAME"
    echo ""
    echo "  # View live logs"
    echo "  sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "  # Restart / stop service"
    echo "  sudo systemctl restart $SERVICE_NAME"
    echo "  sudo systemctl stop $SERVICE_NAME"
    echo ""
    echo "  # Run manually as $SERVICE_USER"
    echo "  sudo -u $SERVICE_USER $VENV_PATH/bin/python $TARGET_PROJECT/bin/display-interface.py"
    echo ""
}

# Main
main() {
    check_prerequisites
    echo ""
    check_fonts
    echo ""
    stop_existing
    echo ""
    install_service
    echo ""
    enable_service
    echo ""
    show_commands
}

main "$@"
