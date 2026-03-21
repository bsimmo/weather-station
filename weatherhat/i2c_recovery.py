"""
I2C Bus Recovery for Raspberry Pi CM4.

Recovers a hung I2C bus when a peripheral holds SDA low by calling
the i2c-bus-recovery.sh script, which uses pinctrl to bit-bang 9 SCL
clock pulses and rebinds the kernel driver.

Requires:
    - Root privileges (or passwordless sudo for the recovery script)
    - pinctrl (installed by default on Pi OS Bookworm)
    - The i2c-bus-recovery.sh script in the project's scripts/ directory

Usage from mqtt-publisher.py:
    from weatherhat.i2c_recovery import attempt_i2c_recovery

    # After detecting I2C errors:
    if attempt_i2c_recovery():
        # Re-open SMBus / reinitialize sensors
        ...
"""

import logging
import os
import subprocess
import time

logger = logging.getLogger(__name__)

# Path to the recovery shell script (relative to this file)
_SCRIPT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts")
RECOVERY_SCRIPT = os.path.join(_SCRIPT_DIR, "i2c-bus-recovery.sh")

# Minimum interval between recovery attempts to avoid thrashing
MIN_RECOVERY_INTERVAL = 30  # seconds
_last_recovery_time = 0.0


def attempt_i2c_recovery(force=False):
    """Attempt to recover the I2C bus using pinctrl bit-bang + driver rebind.

    Args:
        force: If True, skip the rate-limiting check.

    Returns:
        True if recovery succeeded or was unnecessary (bus not stuck).
        False if recovery failed or was rate-limited.
    """
    global _last_recovery_time

    now = time.monotonic()
    if not force and (now - _last_recovery_time) < MIN_RECOVERY_INTERVAL:
        elapsed = now - _last_recovery_time
        logger.warning(f"I2C recovery rate-limited ({elapsed:.0f}s since last attempt, min {MIN_RECOVERY_INTERVAL}s)")
        return False

    if not os.path.isfile(RECOVERY_SCRIPT):
        logger.error(f"I2C recovery script not found: {RECOVERY_SCRIPT}")
        return False

    logger.info("Attempting I2C bus recovery...")
    _last_recovery_time = now

    try:
        result = subprocess.run(
            ["sudo", RECOVERY_SCRIPT],
            capture_output=True,
            text=True,
            timeout=15,
        )

        for line in result.stdout.strip().splitlines():
            logger.info(f"  {line}")

        if result.returncode == 0:
            logger.info("I2C bus recovery succeeded")
            return True
        elif result.returncode == 2:
            logger.error(f"I2C recovery prerequisites not met: {result.stderr.strip()}")
            return False
        else:
            logger.error(f"I2C recovery failed (exit {result.returncode}): {result.stderr.strip()}")
            return False

    except subprocess.TimeoutExpired:
        logger.error("I2C recovery script timed out after 15s")
        return False
    except FileNotFoundError:
        logger.error("sudo not found or recovery script not executable")
        return False
    except Exception as e:
        logger.error(f"I2C recovery unexpected error: {e}")
        return False
