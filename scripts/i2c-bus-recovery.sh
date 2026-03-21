#!/bin/bash
# I2C Bus Recovery Script for Raspberry Pi CM4
#
# Recovers a hung I2C bus (bus 1) when a peripheral holds SDA low.
# Uses pinctrl to bit-bang 9 SCL clock pulses, then rebinds the driver.
#
# Must be run as root. Requires 'pinctrl' (installed by default on Bookworm).
#
# How it works:
#   1. Check if SDA (GPIO2) is actually stuck low
#   2. Switch SCL (GPIO3) to output mode via pinctrl
#   3. Toggle SCL 9 times to clock out the stuck slave
#   4. Restore both pins to ALT0 (I2C function)
#   5. Unbind/rebind i2c-bcm2835 driver to reset controller state
#
# Exit codes:
#   0 - Recovery succeeded (or bus was not stuck)
#   1 - Recovery failed
#   2 - Prerequisites not met (not root, pinctrl missing, etc.)

set -euo pipefail

# GPIO pins for I2C bus 1
SDA_PIN=2
SCL_PIN=3

# I2C1 device address on BCM2711 (CM4 / Pi 4)
I2C_DEVICE="fe804000.i2c"
I2C_DRIVER_PATH="/sys/bus/platform/drivers/i2c-bcm2835"

# How long to hold each clock half-cycle (microseconds, via sleep)
# 5us is I2C spec but shell overhead makes this ~1ms which is fine for recovery
HALF_CYCLE="0.001"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [i2c-recovery] $*"
}

# --- Prerequisite checks ---

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Must be run as root" >&2
    exit 2
fi

if ! command -v pinctrl &>/dev/null; then
    echo "ERROR: pinctrl not found (required on Bookworm+)" >&2
    exit 2
fi

# --- Check if bus is actually stuck ---

# Read SDA pin level. pinctrl output format: "2: ip -- SDA1/GPIO2 = 0"
# If SDA is low (0) while bus is idle, it's stuck.
sda_state=$(pinctrl get "$SDA_PIN" | grep -oP '= \K[01]')

if [[ "$sda_state" == "1" ]]; then
    log "SDA is high, bus appears healthy. No recovery needed."
    exit 0
fi

log "SDA (GPIO${SDA_PIN}) is stuck LOW. Starting recovery..."

# --- Phase 1: Bit-bang 9 SCL clock pulses ---

# Switch SCL to output, drive high initially
pinctrl set "$SCL_PIN" op dh
log "SCL switched to output mode"

for i in $(seq 1 9); do
    pinctrl set "$SCL_PIN" dl
    sleep "$HALF_CYCLE"
    pinctrl set "$SCL_PIN" dh
    sleep "$HALF_CYCLE"

    # Check if SDA released after each clock
    sda_now=$(pinctrl get "$SDA_PIN" | grep -oP '= \K[01]')
    if [[ "$sda_now" == "1" ]]; then
        log "SDA released after $i clock pulse(s)"
        break
    fi
done

# Generate a STOP condition: SDA low -> SCL high -> SDA high
pinctrl set "$SDA_PIN" op dl
sleep "$HALF_CYCLE"
pinctrl set "$SCL_PIN" dh
sleep "$HALF_CYCLE"
pinctrl set "$SDA_PIN" dh
sleep "$HALF_CYCLE"

# --- Phase 2: Restore pins to ALT0 (I2C function) ---

pinctrl set "$SDA_PIN" a0
pinctrl set "$SCL_PIN" a0
log "Pins restored to ALT0 (I2C mode)"

# --- Phase 3: Rebind I2C driver to reset controller state ---

if [[ -d "$I2C_DRIVER_PATH" ]]; then
    log "Rebinding i2c-bcm2835 driver..."
    echo "$I2C_DEVICE" > "$I2C_DRIVER_PATH/unbind" 2>/dev/null || true
    sleep 0.1
    echo "$I2C_DEVICE" > "$I2C_DRIVER_PATH/bind" 2>/dev/null || true
    sleep 0.2
    log "Driver rebound"
else
    log "WARNING: i2c-bcm2835 driver path not found, skipping rebind"
fi

# --- Phase 4: Verify recovery ---

# Wait for /dev/i2c-1 to reappear after rebind
for _ in $(seq 1 10); do
    if [[ -e /dev/i2c-1 ]]; then
        break
    fi
    sleep 0.1
done

if [[ ! -e /dev/i2c-1 ]]; then
    log "ERROR: /dev/i2c-1 did not reappear after driver rebind"
    exit 1
fi

# Check SDA is now high
sda_final=$(pinctrl get "$SDA_PIN" | grep -oP '= \K[01]')
if [[ "$sda_final" == "1" ]]; then
    log "Recovery successful. SDA is high, bus is free."
    exit 0
else
    log "ERROR: Recovery FAILED. SDA is still low after 9 clock pulses."
    exit 1
fi
