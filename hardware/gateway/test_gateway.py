import tempfile
import unittest
from pathlib import Path
from gateway import (
    parse, connect, enqueue, acknowledged, serial_ack,
    pending_progress, record_upload_result,
)

class GatewayTests(unittest.TestCase):
    def test_durable_dedup_and_conflict(self):
        payload = parse('GPS2|VEHICLE-01|VEHICLE-01-123|123|2026-11-27T01:00:00Z|10.5|123.4|7')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'test.sqlite'
            db = connect(path)
            enqueue(db, payload)
            enqueue(db, payload)
            self.assertTrue(serial_ack(db, payload).endswith(b'|PI\n'))
            with db:
                db.execute("UPDATE records SET state='cloud_saved'")
            self.assertTrue(serial_ack(db, payload).endswith(b'|CLOUD\n'))
            db.close()
            db = connect(path)
            self.assertEqual(db.execute('SELECT count(*) FROM records').fetchone()[0], 1)
            with self.assertRaises(ValueError):
                enqueue(db, dict(payload, latitude=11.0))
            db.close()

    def test_legacy_not_given_fabricated_identity(self):
        self.assertIsNone(parse('Raw message: VEHICLE-01,LAT:10.5,LON:123.4,SAT:7'))

    def test_requires_matching_cloud_ack(self):
        class Response:
            status_code = 201
            def json(self): return {'acknowledged_record_id': 'other'}
        self.assertFalse(acknowledged(Response(), 'VEHICLE-01-123'))

    def test_queue_progress_persists_across_restart(self):
        payload = parse('GPS2|VEHICLE-01|VEHICLE-01-123|123|2026-11-27T01:00:00Z|10.5|123.4|7')
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'test.sqlite'
            db = connect(path)
            enqueue(db, payload)
            enqueue(db, payload)
            report = pending_progress(db)[0][0]
            self.assertEqual((report['state'], report['pending_count']), ('receiving', 1))
            record_upload_result(db, payload['device_id'], payload['record_id'],
                                 'pending', issue='waiting_for_connection')
            db.close()

            db = connect(path)
            self.assertEqual(pending_progress(db)[0][0]['state'], 'waiting_for_connection')
            self.assertTrue(serial_ack(db, payload).endswith(b'|PI\n'))
            record_upload_result(db, payload['device_id'], payload['record_id'], 'cloud_saved')
            report = pending_progress(db)[0][0]
            self.assertEqual((report['state'], report['pending_count']), ('uploaded', 0))
            self.assertTrue(serial_ack(db, payload).endswith(b'|CLOUD\n'))
            db.close()

if __name__ == '__main__':
    unittest.main()
