# Weather Station MQTT Publisher
# Build for Raspberry Pi with hardware sensor access via Podman
#
# Build:
#   podman build -t weatherhat:latest .
#
# Run on Pi (requires device access):
#   podman run --privileged \
#     --device /dev/i2c-1 \
#     --device /dev/spidev0.0 \
#     --device /dev/gpiochip0 \
#     --env-file config/mqtt.env \
#     weatherhat:latest

FROM python:3.11-slim-bookworm AS builder

# Install build dependencies for C extensions (RPi.GPIO, spidev)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy and install the weatherhat package
COPY weatherhat/ ./weatherhat/
COPY pyproject.toml README.md CHANGELOG.md LICENSE ./
RUN pip install --no-cache-dir .

# Runtime stage - no build tools needed
FROM python:3.11-slim-bookworm

LABEL org.opencontainers.image.source="https://github.com/pimoroni/weatherhat-python"
LABEL org.opencontainers.image.description="Weather HAT MQTT Publisher"

# Install runtime dependencies for I2C/SPI/GPIO
RUN apt-get update && apt-get install -y --no-install-recommends \
    i2c-tools \
    libgpiod2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy application code
COPY bin/ ./bin/

# Default environment variables
ENV MQTT_SERVER=localhost \
    MQTT_PORT=1883 \
    MQTT_TOPIC_PREFIX=sensors \
    TEMP_OFFSET=-7.5 \
    UPDATE_INTERVAL=2.0 \
    PUBLISH_INTERVAL=2.0

ENTRYPOINT ["python3", "bin/mqtt-publisher.py"]
