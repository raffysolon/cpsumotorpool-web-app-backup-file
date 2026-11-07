#!/usr/bin/env python3
"""
CPSU MotorPool LoRa Gateway
Receives GPS data from vehicle trackers via LoRa
Stores locally and syncs to cloud
"""

import json
import time
import pymysql
import requests
from datetime import datetime
from flask import Flask, jsonify, request
from dotenv import load_dotenv
import os

# Load environment
load_dotenv()

app = Flask(__name__)

# Database config
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME'),
    'charset': 'utf8mb4'
}

CLOUD_API_URL = os.getenv('CLOUD_API_URL')
CLOUD_SYNC_ENABLED = os.getenv('CLOUD_SYNC_ENABLED', 'true').lower() == 'true'

print("=" * 70)
print("🚗 CPSU MotorPool LoRa Gateway Starting...")
print("=" * 70)
print(f"📦 Database: {DB_CONFIG['database']}@{DB_CONFIG['host']}")
print(f"☁️  Cloud Sync: {'Enabled' if CLOUD_SYNC_ENABLED else 'Disabled'}")
print(f"🌐 Cloud API: {CLOUD_API_URL}")
print("=" * 70)

def get_db_connection():
    return pymysql.connect(**DB_CONFIG)

def init_database():
    print("\n📦 Initializing database...")
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Vehicle locations table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS vehicle_locations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id VARCHAR(50) NOT NULL,
            vehicle_plate VARCHAR(20) DEFAULT NULL,
            latitude DECIMAL(10, 8) NOT NULL,
            longitude DECIMAL(11, 8) NOT NULL,
            speed FLOAT DEFAULT 0,
            altitude FLOAT DEFAULT 0,
            satellites INT DEFAULT 0,
            rssi INT DEFAULT 0,
            snr FLOAT DEFAULT 0,
            transmission_type ENUM('lora', 'lte') DEFAULT 'lora',
            timestamp DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            synced_to_cloud BOOLEAN DEFAULT FALSE,
            INDEX idx_device_id (device_id),
            INDEX idx_vehicle_plate (vehicle_plate),
            INDEX idx_timestamp (timestamp)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''')
    
    # Device registry
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS device_registry (
            id INT AUTO_INCREMENT PRIMARY KEY,
            device_id VARCHAR(50) UNIQUE NOT NULL,
            vehicle_plate VARCHAR(20) NOT NULL,
            vehicle_id INT DEFAULT NULL,
            device_type VARCHAR(50) DEFAULT 'LoRa32_V2',
            status ENUM('active', 'inactive', 'maintenance') DEFAULT 'active',
            last_seen DATETIME DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_device_id (device_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''')
    
    conn.commit()
    cursor.close()
    conn.close()
    print("✅ Database initialized!")

def store_gps_data(data):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        device_id = data.get('device_id')
        
        # Look up vehicle plate
        cursor.execute(
            'SELECT vehicle_plate FROM device_registry WHERE device_id = %s AND status = "active"',
            (device_id,)
        )
        result = cursor.fetchone()
        vehicle_plate = result[0] if result else None
        
        # Update last_seen
        if result:
            cursor.execute(
                'UPDATE device_registry SET last_seen = NOW() WHERE device_id = %s',
                (device_id,)
            )
        
        # Insert GPS data
        cursor.execute('''
            INSERT INTO vehicle_locations 
            (device_id, vehicle_plate, latitude, longitude, speed, altitude, 
             satellites, rssi, snr, transmission_type, timestamp)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ''', (
            device_id,
            vehicle_plate,
            data.get('latitude'),
            data.get('longitude'),
            data.get('speed', 0),
            data.get('altitude', 0),
            data.get('satellites', 0),
            data.get('rssi', 0),
            data.get('snr', 0),
            data.get('type', 'lora'),
            data.get('timestamp', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        ))
        
        conn.commit()
        location_id = cursor.lastrowid
        cursor.close()
        conn.close()
        
        print(f"✅ [{datetime.now().strftime('%H:%M:%S')}] Stored: {device_id} ({vehicle_plate or 'unregistered'}) - Lat: {data.get('latitude')}, Lng: {data.get('longitude')}")
        
        # Sync to cloud
        if CLOUD_SYNC_ENABLED:
            sync_to_cloud(data, vehicle_plate, location_id)
        
        return True
        
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False

def sync_to_cloud(data, vehicle_plate, location_id):
    if not CLOUD_API_URL:
        return
    
    try:
        payload = {
            'device_id': data.get('device_id'),
            'vehicle_plate': vehicle_plate,
            'latitude': data.get('latitude'),
            'longitude': data.get('longitude'),
            'speed': data.get('speed', 0),
            'altitude': data.get('altitude', 0),
            'satellites': data.get('satellites', 0),
            'transmission_type': data.get('type', 'lora'),
            'timestamp': data.get('timestamp')
        }
        
        response = requests.post(CLOUD_API_URL, json=payload, timeout=5)
        
        if response.status_code == 200:
            conn = get_db_connection()
            cursor = conn.cursor()
            cursor.execute('UPDATE vehicle_locations SET synced_to_cloud = TRUE WHERE id = %s', (location_id,))
            conn.commit()
            cursor.close()
            conn.close()
            print(f"☁️  Synced to cloud: {vehicle_plate or data.get('device_id')}")
        else:
            print(f"⚠️  Cloud sync failed: {response.status_code}")
            
    except Exception as e:
        print(f"⚠️  Cloud sync error: {e}")

# ============ API ENDPOINTS ============

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'ok',
        'service': 'CPSU MotorPool Gateway',
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/api/gps/update', methods=['POST'])
def receive_gps():
    """Receive GPS data (from LTE backup or testing)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data'}), 400
        
        required = ['device_id', 'latitude', 'longitude']
        if not all(field in data for field in required):
            return jsonify({'error': 'Missing required fields'}), 400
        
        if store_gps_data(data):
            return jsonify({
                'status': 'success',
                'message': 'GPS data received',
                'device_id': data['device_id']
            }), 200
        else:
            return jsonify({'error': 'Failed to store'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/devices/register', methods=['POST'])
def register_device():
    """Register device to vehicle"""
    try:
        data = request.get_json()
        
        device_id = data.get('device_id')
        vehicle_plate = data.get('vehicle_plate')
        vehicle_id = data.get('vehicle_id')
        
        if not device_id or not vehicle_plate:
            return jsonify({'error': 'device_id and vehicle_plate required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO device_registry 
            (device_id, vehicle_plate, vehicle_id, status)
            VALUES (%s, %s, %s, 'active')
            ON DUPLICATE KEY UPDATE
            vehicle_plate = %s,
            vehicle_id = %s,
            status = 'active',
            updated_at = NOW()
        ''', (device_id, vehicle_plate, vehicle_id, vehicle_plate, vehicle_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print(f"📝 Device registered: {device_id} → {vehicle_plate}")
        
        return jsonify({
            'status': 'success',
            'message': 'Device registered',
            'device_id': device_id,
            'vehicle_plate': vehicle_plate
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/devices', methods=['GET'])
def list_devices():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute('SELECT * FROM device_registry ORDER BY created_at DESC')
        devices = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(devices), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/locations/latest', methods=['GET'])
def get_latest_locations():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        cursor.execute('''
            SELECT vl.*, dr.vehicle_plate, dr.status as device_status
            FROM vehicle_locations vl
            INNER JOIN (
                SELECT device_id, MAX(id) as max_id
                FROM vehicle_locations
                GROUP BY device_id
            ) latest ON vl.id = latest.max_id
            LEFT JOIN device_registry dr ON vl.device_id = dr.device_id
            ORDER BY vl.timestamp DESC
        ''')
        
        locations = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return jsonify(locations), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ============ MAIN ============

if __name__ == '__main__':
    print("\n🚀 Starting Gateway...\n")
    
    init_database()
    
    print("\n" + "=" * 70)
    print("✅ Gateway Ready!")
    print("=" * 70)
    print(f"🌐 API Server: http://0.0.0.0:5000")
    print(f"📡 Health: http://localhost:5000/health")
    print(f"📝 Register Device: POST /api/devices/register")
    print(f"📍 Latest Locations: GET /api/locations/latest")
    print("=" * 70)
    print("\n🎧 Listening for GPS data via LoRa and LTE...\n")
    
    # Note: LoRa receiving will be added in next update
    # For now, can receive via HTTP (LTE backup)
    
    app.run(host='0.0.0.0', port=5000, debug=False)
