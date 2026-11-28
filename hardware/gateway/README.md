# Raspberry Pi gateway preparation

This is a new gateway, not a recovered copy of the old Pi script. Do not replace a working deployment before a bench test. No firmware pins are changed.

## Current compatibility

The supplied vehicle firmware sends only device ID, coordinates and satellite count. Its SD CSV contains record ID, sequence and capture time, but these are absent from the LoRa packet. The supplied admin firmware cannot send acknowledgments back to the vehicle.

This gateway retains legacy `Raw message:` packets in SQLite for review. It intentionally does NOT upload those packets with invented identities/timestamps. The matching bench firmware is now in `../firmware`; read its limitations before flashing. The receiver must emit each valid packet once as a newline-terminated GPS2 line (no diagnostic prefix).

## Behavior

- Serial ingestion and cloud uploads run independently.
- SQLite commits each record before reporting PI_SAVED locally.
- Repeated identical record IDs do not create new queue entries. Conflicting payloads are retained for review.
- Upload uses the existing `/api/gps/location` endpoint and trusted gateway key with `upload_source=recovered_lora`.
- A record becomes cloud_saved only after HTTP 200/201 AND a matching acknowledged_record_id.
- Failed uploads remain on disk; 404/409/422 records are held for review. Fix their underlying issue before manually requeuing them.
- No vehicle SD records are deleted. PI_SAVED is a local console message. The script additionally writes ACK2 PI/CLOUD confirmations over USB for the matching admin firmware to relay.
- Vehicle firmware initiates SD retries. Gateway reports describe records received by the Pi. The full vehicle SD backlog is unknown to the gateway.

## Pi installation (after firmware compatibility is ready)

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export SERIAL_PORT=/dev/ttyUSB0
export GATEWAY_DB="$HOME/motorpool-gateway/gateway.sqlite"
# Set GATEWAY_API_KEY securely on the Pi; never commit or screenshot its value.
.venv/bin/python gateway.py
```

Use a stable `/dev/serial/by-id/...` path when available. Only one gateway process should read the receiver. Keep the SQLite directory on persistent storage; do not clear it on restart. Test loss of cloud internet, serial reconnect and power interruption before field use. Monitor storage growth because retained records are not automatically purged.

Local-IP SSH normally requires network reachability to the Pi. Being on another Wi-Fi does not erase its files. Use the original network, direct console access, or an already configured remote-access connection to retrieve the original script. This preparation does not configure remote access.

## Admin Sync Logs

Deploy the backend migration and updated admin web app before installing this gateway version.
The Pi reports changed device queues to `/api/gps/sync-status` with the same trusted
gateway key. Set `GPS_SYNC_STATUS_URL` if the status endpoint is at a different path.

- **Receiving via LoRa** means records arrived on the Pi and are queued.
- **Waiting for connection** means an upload failed to reach the backend. During a total outage, the web app can only show the last report. The Pi reports its saved status once contact resumes.
- **Upload delayed** means the backend response did not confirm the record. **Needs review** identifies records that require attention after the normal upload queue has drained.
- **Uploaded** means the Pi has no remaining queued or review records for that device and all uploads it processed were acknowledged by the backend.
