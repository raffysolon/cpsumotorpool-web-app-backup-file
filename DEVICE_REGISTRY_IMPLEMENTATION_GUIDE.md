# Device Registry Backend Implementation Guide

## Current Status
- ✅ Frontend Complete (Admin UI working)
- x Backend at working state (commit d1ea91f)
- ❌ Backend Device Registry not yet implemented
- ❌ Database table not yet created

---

## Goal
Implement Device Registry backend without breaking existing login/features.

---

## Step-by-Step Implementation

### STEP 1: Create Migration File

**Location**: `d:\cpsumotorpoolbackend\database\migrations\`

**Filename**: `2026_11_07_000001_create_device_registry_table.php`

**Code**:
```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_registry', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 100)->unique();
            $table->unsignedBigInteger('vehicle_id');
            $table->string('vehicle_plate', 50);
            $table->timestamp('last_seen')->nullable();
            $table->boolean('is_online')->default(false);
            $table->timestamp('registered_at')->useCurrent();
            $table->timestamps();

            $table->foreign('vehicle_id')
                  ->references('id')
                  ->on('vehicles')
                  ->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_registry');
    }
};
```

**Check**:
- ✅ File saved in `database/migrations/` folder?
- ✅ Filename starts with date `2026_11_07`?
- ✅ No syntax errors (check closing tags)?

---

### STEP 2: Create Device Model

**Location**: `d:\cpsumotorpoolbackend\app\Models\`

**Filename**: `Device.php`

**Code**:
```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Device extends Model
{
    use HasFactory;

    protected $table = 'device_registry';

    protected $fillable = [
        'device_id',
        'vehicle_id',
        'vehicle_plate',
        'last_seen',
        'is_online',
        'registered_at',
    ];

    // IMPORTANT: Vehicle model uses 'plate_no' column, not 'plate_number'

    protected $casts = [
        'last_seen' => 'datetime',
        'registered_at' => 'datetime',
        'is_online' => 'boolean',
    ];

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }
}
```

**Check**:
- ✅ File saved in `app/Models/` folder?
- ✅ Namespace is `App\Models`?
- ✅ Table name is `device_registry`?
- ✅ No syntax errors?

---

### STEP 3: Create Device Controller

**Location**: `d:\cpsumotorpoolbackend\app\Http\Controllers\`

**Filename**: `DeviceController.php`

**Code**:
```php
<?php

namespace App\Http\Controllers;

use App\Models\Device;
use App\Models\Vehicle;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DeviceController extends Controller
{
    // Health check (public)
    public function health()
    {
        return response()->json([
            'status' => 'ok',
            'service' => 'device-registry',
            'timestamp' => now()
        ]);
    }

    // List all devices (admin only)
    public function index(Request $request)
    {
        $query = Device::with('vehicle');

        // Search by device_id or plate
        if ($request->has('search')) {
            $search = $request->search;
            $query->where('device_id', 'like', "%{$search}%")
                  ->orWhere('vehicle_plate', 'like', "%{$search}%");
        }

        // Filter by online status
        if ($request->has('online')) {
            $query->where('is_online', $request->online);
        }

        $devices = $query->orderBy('registered_at', 'desc')
                         ->paginate(20);

        return response()->json($devices);
    }

    // Register new device (admin only)
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'device_id' => 'required|string|max:100|unique:device_registry,device_id',
            'vehicle_id' => 'required|exists:vehicles,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        // Get vehicle info
        $vehicle = Vehicle::findOrFail($request->vehicle_id);

        $device = Device::create([
            'device_id' => $request->device_id,
            'vehicle_id' => $request->vehicle_id,
            'vehicle_plate' => $vehicle->plate_no, // Correct: Vehicle model uses 'plate_no'
            'registered_at' => now(),
            'is_online' => false,
        ]);

        return response()->json([
            'message' => 'Device registered successfully',
            'device' => $device
        ], 201);
    }

    // Get device by ID (admin only)
    public function show($device_id)
    {
        $device = Device::with('vehicle')
                        ->where('device_id', $device_id)
                        ->firstOrFail();

        return response()->json($device);
    }

    // Update device (admin only)
    public function update(Request $request, $device_id)
    {
        $device = Device::where('device_id', $device_id)->firstOrFail();

        $validator = Validator::make($request->all(), [
            'vehicle_id' => 'sometimes|exists:vehicles,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        if ($request->has('vehicle_id')) {
            $vehicle = Vehicle::findOrFail($request->vehicle_id);
            $device->vehicle_id = $request->vehicle_id;
            $device->vehicle_plate = $vehicle->plate_no; // Correct: Vehicle model uses 'plate_no'
        }

        $device->save();

        return response()->json([
            'message' => 'Device updated successfully',
            'device' => $device
        ]);
    }

    // Delete device (admin only)
    public function destroy($device_id)
    {
        $device = Device::where('device_id', $device_id)->firstOrFail();
        $device->delete();

        return response()->json([
            'message' => 'Device deleted successfully'
        ]);
    }

    // Get devices by vehicle (admin only)
    public function byVehicle($vehicle_id)
    {
        $devices = Device::where('vehicle_id', $vehicle_id)->get();

        return response()->json($devices);
    }
}
```

**Check**:
- ✅ File saved in `app/Http/Controllers/` folder?
- ✅ Namespace is `App\Http\Controllers`?
- ✅ Has 7 methods (health, index, register, show, update, destroy, byVehicle)?
- ✅ No syntax errors?

---

### STEP 4: Update API Routes

**Location**: `d:\cpsumotorpoolbackend\routes\api.php`

**Action**: ADD these lines at the END of the file (don't delete existing routes!)

**Code to ADD**:
```php
use App\Http\Controllers\DeviceController;

// Device Registry Routes
Route::get('/devices/health', [DeviceController::class, 'health']); // Public

// Admin-only Device Registry routes (with role check)
Route::middleware(['auth:sanctum', 'role:admin'])->group(function () {
    Route::get('/devices', [DeviceController::class, 'index']);
    Route::post('/devices/register', [DeviceController::class, 'register']);
    Route::get('/devices/{device_id}', [DeviceController::class, 'show']);
    Route::put('/devices/{device_id}', [DeviceController::class, 'update']);
    Route::delete('/devices/{device_id}', [DeviceController::class, 'destroy']);
    Route::get('/devices/vehicle/{vehicle_id}', [DeviceController::class, 'byVehicle']);
});
```

**Check**:
- ✅ Import line added at top (after other use statements)?
- ✅ Routes added at bottom (after existing routes)?
- ✅ No routes deleted?
- ✅ No syntax errors (check semicolons)?

---

## Deployment Steps

### STEP 5: Commit to Git

```bash
cd d:\cpsumotorpoolbackend

git add database/migrations/2026_11_07_000001_create_device_registry_table.php
git add app/Models/Device.php
git add app/Http/Controllers/DeviceController.php
git add routes/api.php

git commit -m "Add Device Registry backend (migration, model, controller, routes)"
```

**Check**:
- ✅ 4 files added?
- ✅ Commit message clear?

---

### STEP 6: Push to GitHub

```bash
git push origin main
```

**Check**:
- ✅ Push successful?
- ✅ No conflicts?

---

### STEP 7: Wait for Render Deployment

1. Open: https://dashboard.render.com/
2. Go to your backend service
3. Check "Events" tab
4. Wait 2-3 minutes for "Deploy succeeded"

**Check**:
- ✅ Status shows "Live"?
- ✅ No error messages in logs?

---

### STEP 8: Create Database Table Manually

**Important**: Render free tier doesn't run migrations automatically. You must create the table in Supabase.

1. Open: https://supabase.com/dashboard
2. Select your project
3. Go to "SQL Editor"
4. Click "New Query"
5. Paste this SQL:

```sql
CREATE TABLE IF NOT EXISTS device_registry (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(100) UNIQUE NOT NULL,
    vehicle_id BIGINT NOT NULL,
    vehicle_plate VARCHAR(50) NOT NULL,
    last_seen TIMESTAMP,
    is_online BOOLEAN DEFAULT false,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicles(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_device_id ON device_registry(device_id);
CREATE INDEX idx_vehicle_id ON device_registry(vehicle_id);
```

6. Click "Run" (or press Ctrl+Enter)

**Check**:
- ✅ Query shows "Success"?
- ✅ No errors about existing table?
- ✅ Table appears in left sidebar under "Tables"?

---

### STEP 9: Test Backend API

**Test 1: Health Check**
```bash
curl https://your-backend.onrender.com/api/devices/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "device-registry",
  "timestamp": "2026-11-07T14:30:00.000000Z"
}
```

**Test 2: List Devices (empty at first)**

You need auth token. Get from admin app login, then:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://your-backend.onrender.com/api/devices
```

Expected response:
```json
{
  "current_page": 1,
  "data": [],
  "total": 0
}
```

**Check**:
- ✅ Health endpoint returns 200 OK?
- ✅ Devices endpoint returns 200 (not 404)?
- ✅ No "table does not exist" errors?

---

### STEP 10: Test Admin UI

1. Open admin app: http://localhost:58000 (or your URL)
2. Login as admin
3. Click "Device Registry" in sidebar
4. Should show empty list (not 404 error)
5. Click "Register New Device"
6. Fill in:
   - Device ID: `LORA32_TEST001`
   - Select a vehicle from dropdown
7. Click "Register"
8. Should show success message
9. Device appears in list

**Check**:
- ✅ Page loads without 404 error?
- ✅ Can register device?
- ✅ Device appears in list?
- ✅ Can view device details?
- ✅ Can delete device?

---

## Final Checklist

Before telling me "done":

- [ ] Migration file created (2026_11_07_000001_create_device_registry_table.php)
- [ ] Device model created (Device.php)
- [ ] DeviceController created (DeviceController.php)
- [ ] Routes added to api.php (import + 7 routes)
- [ ] Git committed (4 files)
- [ ] Git pushed to GitHub (no conflicts)
- [ ] Render deployed successfully (status "Live")
- [ ] Table created in Supabase (SQL editor)
- [ ] Health endpoint works (curl test)
- [ ] Admin UI loads Device Registry page (no 404)
- [ ] Can register test device in admin UI

---

## If Something Breaks

### Problem: Backend won't start after deployment
**Solution**: 
```bash
cd d:\cpsumotorpoolbackend
git reset --hard d1ea91f
git push --force origin main
```
This reverts to working state. Wait for Render to redeploy.

### Problem: "Table already exists" error
**Solution**: Table was created before. This is OK, skip step 8.

### Problem: "Device not found" in admin UI
**Solution**: 
1. Check Render logs for errors
2. Verify table exists in Supabase
3. Test health endpoint with curl
4. Check if device_id matches exactly (case-sensitive!)

### Problem: Can't push to GitHub
**Solution**:
```bash
git status
git pull origin main
# Resolve conflicts if any
git push origin main
```

---

## What NOT to Do

❌ **DON'T** create render-build.sh or startup scripts (these broke the backend before)
❌ **DON'T** try to run migrations via Render commands (free tier doesn't support it)
❌ **DON'T** modify existing routes in api.php (only add new ones at the end)
❌ **DON'T** change .env file or database config
❌ **DON'T** force push unless reverting to d1ea91f

---

## Summary

**What You're Creating**:
1. Migration (table structure)
2. Model (PHP class for device_registry table)
3. Controller (7 API methods)
4. Routes (connect URLs to controller methods)

**Deployment Process**:
Code → Git Commit → GitHub Push → Render Auto-Deploy → Manual SQL in Supabase

**Key Point**: Backend files go in repository, but table must be created manually in Supabase SQL editor.

**After Success**: Your admin UI can register devices, and Raspberry Pi gateway can check if devices are registered before accepting GPS data!

