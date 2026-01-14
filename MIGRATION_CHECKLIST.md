# Migration Checklist

Use this checklist to safely deploy the improved weatherhat code to your production system.

## Pre-Migration

- [ ] **Backup current code**
  ```bash
  cp -r /home/coder/workspace/weatherhat-python /home/coder/workspace/weatherhat-python.backup
  ```

- [ ] **Document current settings**
  - MQTT server: ________________
  - Temperature offset: ________________
  - Update interval: ________________
  - Other custom settings: ________________

- [ ] **Stop existing service** (if running as systemd)
  ```bash
  sudo systemctl stop weatherhat-mqtt 2>/dev/null || echo "No service running"
  ```

## Library Changes (Low Risk)

- [ ] **Test history.py changes**
  ```bash
  python3 -c "from weatherhat import history; h = history.History(); h.append(1); print('OK')"
  ```

- [ ] **Test WeatherHAT initialization**
  ```bash
  python3 -c "import weatherhat; sensor = weatherhat.WeatherHAT(); sensor.close(); print('OK')"
  ```

- [ ] **Run basic example**
  ```bash
  timeout 30 python3 examples/basic.py
  ```

## MQTT Migration (Requires Configuration)

- [ ] **Create environment file**
  ```bash
  cd examples
  cp mqtt.env.example mqtt.env
  ```

- [ ] **Configure mqtt.env**
  ```bash
  nano mqtt.env
  ```
  Fill in:
  - MQTT_SERVER
  - MQTT_PORT
  - MQTT_USERNAME (if needed)
  - MQTT_PASSWORD (if needed)
  - TEMP_OFFSET
  - Other settings

- [ ] **Test manually**
  ```bash
  export $(cat mqtt.env | xargs) && timeout 60 python3 mqtt.py
  ```
  Check for:
  - "Connected to MQTT broker" message
  - No errors in output
  - Data appearing in MQTT broker

## Production Deployment

- [ ] **Update systemd service** (if using)
  Create `/etc/systemd/system/weatherhat-mqtt.service`:
  ```ini
  [Unit]
  Description=WeatherHAT MQTT Publisher
  After=network-online.target
  Wants=network-online.target

  [Service]
  Type=simple
  User=pi
  WorkingDirectory=/home/coder/workspace/weatherhat-python/examples
  EnvironmentFile=/home/coder/workspace/weatherhat-python/examples/mqtt.env
  ExecStart=/usr/bin/python3 /home/coder/workspace/weatherhat-python/examples/mqtt.py
  Restart=on-failure
  RestartSec=30

  [Install]
  WantedBy=multi-user.target
  ```

- [ ] **Reload systemd**
  ```bash
  sudo systemctl daemon-reload
  ```

- [ ] **Enable service**
  ```bash
  sudo systemctl enable weatherhat-mqtt
  ```

- [ ] **Start service**
  ```bash
  sudo systemctl start weatherhat-mqtt
  ```

## Post-Migration Verification

- [ ] **Check service status**
  ```bash
  sudo systemctl status weatherhat-mqtt
  ```
  Should show "active (running)"

- [ ] **Check logs**
  ```bash
  sudo journalctl -u weatherhat-mqtt -n 50
  ```
  Look for:
  - "Starting Weather Station MQTT Publisher"
  - "Connected to MQTT broker"
  - No ERROR messages

- [ ] **Verify MQTT data**
  ```bash
  mosquitto_sub -h YOUR_MQTT_SERVER -t "sensors/#" -v
  ```
  Should see sensor data flowing

- [ ] **Monitor for 1 hour**
  ```bash
  sudo journalctl -u weatherhat-mqtt -f
  ```
  Watch for:
  - Regular data publishing
  - No errors or warnings
  - Proper reconnection if network hiccups

- [ ] **Monitor CPU/Memory**
  ```bash
  top -p $(pgrep -f mqtt.py)
  ```
  Should see:
  - CPU: <1% average
  - Memory: <50MB

## Rollback (If Issues Occur)

- [ ] **Stop new service**
  ```bash
  sudo systemctl stop weatherhat-mqtt
  ```

- [ ] **Restore backup**
  ```bash
  cd /home/coder/workspace
  mv weatherhat-python weatherhat-python.new
  mv weatherhat-python.backup weatherhat-python
  ```

- [ ] **Restart old version**
  ```bash
  # Start however you were running it before
  ```

## Security Hardening (Recommended)

- [ ] **Restrict file permissions**
  ```bash
  chmod 600 examples/mqtt.env
  ```

- [ ] **Add to .gitignore**
  ```bash
  echo "examples/mqtt.env" >> .gitignore
  ```

- [ ] **Enable MQTT authentication** (if not already)
  Set MQTT_USERNAME and MQTT_PASSWORD in mqtt.env

- [ ] **Consider TLS** (future enhancement)
  Will need to modify mqtt.py to add:
  ```python
  client.tls_set(ca_certs="/path/to/ca.crt")
  ```

## Performance Validation

- [ ] **Measure performance improvement**
  Before (if still running old version):
  ```bash
  top -p $(pgrep -f mqtt.py) -n 1 -b | grep python
  ```

  After:
  ```bash
  top -p $(pgrep -f mqtt.py) -n 1 -b | grep python
  ```

  CPU should be significantly lower (~1% → ~0.01%)

## Long-term Monitoring

- [ ] **Set up log rotation** (if not already)
  Create `/etc/logrotate.d/weatherhat-mqtt`:
  ```
  /var/log/weatherhat-mqtt.log {
      daily
      rotate 7
      compress
      delaycompress
      missingok
      notifempty
  }
  ```

- [ ] **Set up alerts** (optional)
  Monitor for:
  - Service failures
  - High error rates in logs
  - Data gaps in MQTT

## Completion

- [ ] **Document deployed version**
  ```bash
  git log -1 --oneline > /home/coder/workspace/DEPLOYED_VERSION.txt
  date >> /home/coder/workspace/DEPLOYED_VERSION.txt
  ```

- [ ] **Update documentation** with any customizations made

- [ ] **Remove backup after 1 week** (if everything stable)
  ```bash
  # After 1 week of stable operation
  rm -rf /home/coder/workspace/weatherhat-python.backup
  ```

---

## Quick Reference

### View logs in real-time
```bash
sudo journalctl -u weatherhat-mqtt -f
```

### Restart service
```bash
sudo systemctl restart weatherhat-mqtt
```

### Check MQTT data
```bash
mosquitto_sub -h YOUR_SERVER -t "sensors/#" -v
```

### Check CPU usage
```bash
top -p $(pgrep -f mqtt.py)
```

### Manual test
```bash
cd /home/coder/workspace/weatherhat-python/examples
export $(cat mqtt.env | xargs) && python3 mqtt.py
```

---

## Support

If you encounter issues:

1. Check logs: `sudo journalctl -u weatherhat-mqtt -n 100`
2. Test manually: `export $(cat mqtt.env | xargs) && python3 mqtt.py`
3. Verify I2C: `i2cdetect -y 1`
4. Check network: `ping YOUR_MQTT_SERVER`
5. Review changes: `git diff HEAD^ HEAD`

For help, create an issue at: https://github.com/pimoroni/weatherhat-python/issues
