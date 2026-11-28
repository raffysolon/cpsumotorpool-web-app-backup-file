"""Durable GPS gateway. Legacy packets are retained, never given invented IDs.

V2 serial line (exactly one per received record):
GPS2|VEHICLE-01|VEHICLE-01-123|123|2026-11-27T01:00:00Z|10.5|123.4|7
The current receiver's 'Raw message: VEHICLE-01,LAT:...' is quarantined.
"""
import json
import math
import os
import re
import sqlite3
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


def connect(path):
    db = sqlite3.connect(path, timeout=30)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA synchronous=FULL')
    db.executescript('''
        CREATE TABLE IF NOT EXISTS records (
          record_id TEXT PRIMARY KEY, payload TEXT NOT NULL,
          state TEXT NOT NULL DEFAULT 'pending', received_at TEXT NOT NULL,
          error TEXT, UNIQUE(record_id));
        CREATE INDEX IF NOT EXISTS records_state ON records(state);
        CREATE TABLE IF NOT EXISTS sync_updates (
          device_id TEXT PRIMARY KEY, revision INTEGER NOT NULL DEFAULT 1,
          sent_revision INTEGER NOT NULL DEFAULT 0, upload_issue TEXT);
        CREATE TABLE IF NOT EXISTS unparsed (
          id INTEGER PRIMARY KEY, received_at TEXT NOT NULL, raw TEXT NOT NULL);
    ''')
    with db:
        db.execute("""
            INSERT OR IGNORE INTO sync_updates(device_id)
            SELECT DISTINCT json_extract(payload, '$.device_id')
            FROM records WHERE state IN ('pending', 'review')
        """)
    return db


def parse(line):
    parts = line.split('|')
    if len(parts) != 8 or parts[0] != 'GPS2':
        return None
    _, device, record, seq, captured, lat, lon, sat = parts
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', device):
        raise ValueError('Invalid device ID')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,150}', record) or not record.startswith(device + '-'):
        raise ValueError('Invalid record ID')
    if not seq.isdigit() or not 1 <= int(seq) <= 9223372036854775807:
        raise ValueError('Invalid sequence')
    stamp = datetime.fromisoformat(captured.replace('Z', '+00:00'))
    if stamp.tzinfo is None:
        raise ValueError('Capture time must include timezone')
    latitude, longitude = float(lat), float(lon)
    if not (math.isfinite(latitude) and math.isfinite(longitude)
            and -90 <= latitude <= 90 and -180 <= longitude <= 180):
        raise ValueError('Invalid coordinates')
    if not sat.isdigit() or not 0 <= int(sat) <= 255:
        raise ValueError('Invalid satellites')
    return dict(device_id=device, record_id=record, device_sequence=int(seq),
                captured_at=stamp.astimezone(timezone.utc).isoformat(),
                latitude=latitude, longitude=longitude, satellites=int(sat),
                upload_source='recovered_lora')


def enqueue(db, payload):
    encoded = json.dumps(payload, sort_keys=True)
    with db:
        old = db.execute('SELECT payload FROM records WHERE record_id=?',
                         (payload['record_id'],)).fetchone()
        if old and old[0] != encoded:
            raise ValueError('Conflicting data for existing record ID')
        inserted = db.execute(
            'INSERT OR IGNORE INTO records(record_id,payload,received_at) VALUES(?,?,?)',
            (payload['record_id'], encoded, datetime.now(timezone.utc).isoformat()),
        )
        if inserted.rowcount:
            db.execute("""
                INSERT INTO sync_updates(device_id) VALUES(?)
                ON CONFLICT(device_id) DO UPDATE SET revision=revision+1
            """, (payload['device_id'],))


def acknowledged(response, record_id):
    if response.status_code not in (200, 201):
        return False
    try:
        return response.json().get('acknowledged_record_id') == record_id
    except (ValueError, AttributeError):
        return False


def serial_ack(db, payload):
    state = db.execute('SELECT state FROM records WHERE record_id=?',
                       (payload['record_id'],)).fetchone()
    if not state or state[0] == 'review':
        return None
    phase = 'CLOUD' if state[0] == 'cloud_saved' else 'PI'
    return f"ACK2|{payload['device_id']}|{payload['record_id']}|{phase}\n".encode('ascii')


def record_upload_result(db, device_id, record_id, state, error=None, issue=None):
    with db:
        db.execute('UPDATE records SET state=?,error=? WHERE record_id=?',
                   (state, error, record_id))
        db.execute("""
            INSERT INTO sync_updates(device_id,upload_issue) VALUES(?,?)
            ON CONFLICT(device_id) DO UPDATE SET revision=revision+1,
                upload_issue=excluded.upload_issue
            WHERE sync_updates.upload_issue IS NOT excluded.upload_issue
                  OR excluded.upload_issue IS NULL
        """, (device_id, issue))


def pending_progress(db):
    snapshots = db.execute("""
        SELECT device_id, revision, upload_issue FROM sync_updates
        WHERE revision != sent_revision ORDER BY device_id LIMIT 25
    """).fetchall()
    if not snapshots:
        return [], snapshots

    placeholders = ','.join('?' for _ in snapshots)
    counts = {
        (device, state): count
        for device, state, count in db.execute(f"""
            SELECT json_extract(payload, '$.device_id'), state, count(*)
            FROM records WHERE state IN ('pending', 'review')
              AND json_extract(payload, '$.device_id') IN ({placeholders})
            GROUP BY 1, 2
        """, [device for device, _, _ in snapshots])
    }
    reports = []
    for device, _, issue in snapshots:
        pending = counts.get((device, 'pending'), 0)
        review = counts.get((device, 'review'), 0)
        if pending:
            state = issue or 'receiving'
        elif review:
            state = 'needs_review'
        else:
            state = 'uploaded'
        reports.append(dict(device_id=device, state=state,
                            pending_count=pending, review_count=review))
    return reports, snapshots


def report_progress(db, session, url):
    import requests
    reports, snapshots = pending_progress(db)
    if not reports:
        return False
    try:
        response = session.post(url, json={'devices': reports}, timeout=(3, 4),
                                allow_redirects=False)
        if response.status_code != 204:
            return True
    except requests.RequestException:
        return True
    with db:
        db.executemany(
            'UPDATE sync_updates SET sent_revision=? WHERE device_id=?',
            [(revision, device) for device, revision, _ in snapshots],
        )
    return True


def upload_worker(path, url, status_url, key, stop):
    import requests
    db = connect(path)
    with requests.Session() as session:
        session.headers.update({'X-Gateway-Key': key, 'Accept': 'application/json'})
        next_progress = 0
        while not stop.is_set():
            if time.monotonic() >= next_progress:
                if report_progress(db, session, status_url):
                    next_progress = time.monotonic() + 15
            row = db.execute("SELECT record_id,payload FROM records WHERE state='pending' ORDER BY rowid LIMIT 1").fetchone()
            if not row:
                stop.wait(2)
                continue
            record_id, encoded = row
            payload = json.loads(encoded)
            device_id = payload['device_id']
            delay = 1  # Keep below the backend's 120 requests/minute limit.
            try:
                response = session.post(url, json=payload, timeout=(10, 30))
                if acknowledged(response, record_id):
                    record_upload_result(db, device_id, record_id, 'cloud_saved')
                    print(f'CLOUD_SAVED {record_id}', flush=True)
                else:
                    # Bad records remain available for review instead of blocking the queue.
                    state = 'review' if response.status_code in (404, 409, 422) else 'pending'
                    record_upload_result(db, device_id, record_id, state,
                                         f'HTTP {response.status_code}; acknowledgment not confirmed',
                                         'upload_delayed' if state == 'pending' else None)
                    delay = 60
            except requests.RequestException:
                record_upload_result(db, device_id, record_id, 'pending',
                                     'Cloud connection unavailable', 'waiting_for_connection')
                delay = 30
                print('CLOUD_UNAVAILABLE: records remain on Pi', flush=True)
            stop.wait(delay)
    db.close()


def main():
    import serial
    key = os.environ.get('GATEWAY_API_KEY', '')
    if not key:
        raise SystemExit('Set GATEWAY_API_KEY in the Pi environment.')
    url = os.getenv('GPS_API_URL', 'https://cpsu-motorpool-backend.onrender.com/api/gps/location')
    status_url = os.getenv('GPS_SYNC_STATUS_URL', url.rsplit('/', 1)[0] + '/sync-status')
    if not url.startswith('https://') or not status_url.startswith('https://'):
        raise SystemExit('Gateway API URLs must use HTTPS.')
    path = Path(os.getenv('GATEWAY_DB', str(Path.home() / 'motorpool-gateway' / 'gateway.sqlite')))
    path.parent.mkdir(parents=True, exist_ok=True)
    db = connect(path)
    stop = threading.Event()
    worker = threading.Thread(target=upload_worker, args=(path, url, status_url, key, stop), daemon=True)
    worker.start()
    try:
        while True:
            try:
                with serial.Serial(os.getenv('SERIAL_PORT', '/dev/ttyUSB0'), 115200, timeout=2) as receiver:
                    while True:
                        raw = receiver.read_until(b'\n', 1024)
                        if not raw.endswith(b'\n'):
                            continue
                        line = raw.decode('utf-8', errors='replace').strip()
                        if not (line.startswith('GPS2|') or line.startswith('Raw message:')):
                            continue
                        try:
                            payload = parse(line)
                            if payload is None:
                                raise ValueError('Legacy packet lacks capture time and record ID')
                            enqueue(db, payload)
                            print(f"PI_SAVED {payload['record_id']}", flush=True)
                            ack = serial_ack(db, payload)
                            if ack:
                                receiver.write(ack)
                                receiver.flush()
                        except ValueError as error:
                            with db:
                                db.execute('INSERT INTO unparsed(received_at,raw) VALUES(?,?)',
                                           (datetime.now(timezone.utc).isoformat(), line))
                            print(f'REVIEW_REQUIRED: {error}', flush=True)
            except serial.SerialException:
                print('SERIAL_DISCONNECTED: retrying in 5 seconds', flush=True)
                time.sleep(5)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        worker.join(timeout=45)
        db.close()


if __name__ == '__main__':
    main()
