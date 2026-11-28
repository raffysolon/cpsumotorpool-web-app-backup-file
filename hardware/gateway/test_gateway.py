import tempfile
import unittest
from pathlib import Path
from gateway import parse, connect, enqueue, acknowledged, serial_ack

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

if __name__ == '__main__':
    unittest.main()
