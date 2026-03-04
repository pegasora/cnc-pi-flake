# Modbus TCP Reference Guide

## Connection Information

| Parameter | Value |
|-----------|-------|
| **Pi IP Address** | `10.8.4.x` |
| **Port** | `502` (Modbus TCP default) |
| **Slave ID / Device ID** | `1` |
| **Protocol** | Modbus TCP |
| **Byte Order** | Big Endian (Modbus standard) |

## Address Mapping

### Control Coils (Read/Write)

| Modbus Address | Raw Address | Direction | Purpose | Data Type | Values |
|----------------|-------------|-----------|---------|-----------|--------|
| `00001` | 0 | CLICK → Pi | Start/Stop Signal | Boolean | 0=Stop, 1=Start |

**Usage:**
- CLICK PLC writes to this coil to control the simulation start/stop
- HIGH (1) = Start machining simulation
- LOW (0) = Stop machining simulation
    - Setting it up this way allows the CLICK PLC to determine cycle time
- Pi detects rising edge (LOW→HIGH) to begin new cycle
    - Thsi is acceptable due to the overehad of time required to load/unload and then start a cycle - so no "stop" signal needed.

### Status Flags (Read-Only)

| Modbus Address | Raw Address | Direction | Purpose | Data Type | Values |
|----------------|-------------|-----------|---------|-----------|--------|
| `00011` | 10 | Pi → All | Signal Received | Boolean | 0=No, 1=Yes |
| `00012` | 11 | Pi → All | Simulation Active | Boolean | 0=Idle, 1=Running |
| `00013` | 12 | Pi → All | Cycle Complete | Boolean | 0=No, 1=Yes |

**Usage:**
- CLICK PLC and students can read these to monitor simulation state
- Coil 10: Pi acknowledges receipt of start signal
- Coil 11: Pi is currently generating machining data
- Coil 12: Pi has completed a full cycle

### CNC Parameters (Holding Registers, Read-Only)

| Modbus Address | Raw Address | Parameter | Unit | Range | Description |
|----------------|-------------|-----------|------|-------|-------------|
| `40001` | 0 | Machine State | enum | 0-3 | 0=Idle, 1=Running, 2=Paused, 3=Alarm |
| `40002` | 1 | Parts Count | count | 0-65535 | Total parts machined since startup |
| `40003` | 2 | Spindle RPM | RPM | 0-12000 | Current spindle speed |
| `40004` | 3 | Current Tool | # | 1-24 | Tool number in spindle (T01-T24) |
| `40005` | 4 | Feedrate | IPM × 10 | 0-2500 | Divide by 10 for actual IPM |
| `40006` | 5 | Spindle Load | % | 0-100 | Percentage of max spindle load |
| `40007` | 6 | X Axis Position | µm | -32768 to 32767 | Divide by 1000 for mm (signed) |
| `40008` | 7 | Y Axis Position | µm | -32768 to 32767 | Divide by 1000 for mm (signed) |
| `40009` | 8 | Z Axis Position | µm | -32768 to 32767 | Divide by 1000 for mm (signed) |
| `40010` | 9 | Coolant Flow | GPM × 10 | 0-1000 | Divide by 10 for actual GPM |
| `40011` | 10 | Coolant Temp | °F | 0-200 | Temperature in Fahrenheit |
| `40012` | 11 | Spindle Temp | °F | 0-250 | Temperature in Fahrenheit |
| `40013` | 12 | Hydraulic Pressure | PSI | 0-2000 | Pressure in pounds per square inch |
| `40014` | 13 | Program Number | # | 0-9999 | O-code program number (O####) |
| `40015` | 14 | Block Number | # | 0-65535 | Current program line (N####) |
| `40016` | 15 | Alarm Code | code | 0-65535 | 0=No alarm, >0=Alarm active |
| `40017` | 16 | Tool Life | % | 0-100 | Remaining tool life percentage |
| `40018` | 17 | Elapsed Time | seconds | 0-65535 | Cycle time elapsed |
| `40019` | 18 | Remaining Time | seconds | 0 | Always 0 (CLICK controls timing) |
| `40020` | 19 | Power Consumption | watts | 0-15000 | Current power draw |

**Note on Scaling:**
- **Feedrate (register 4):** Multiply by 10 to fit in 16-bit integer. Example: 152 → 15.2 IPM
- **Coolant Flow (register 9):** Multiply by 10. Example: 45 → 4.5 GPM
- **Positions (registers 6-8):** Stored in microns (µm). Divide by 1000 for millimeters. Signed 16-bit values support negative positions.

## Function Codes

| Function Code | Name | Purpose | Used For |
|---------------|------|---------|----------|
| `01 (0x01)` | Read Coils | Read multiple coils | Reading status flags |
| `03 (0x03)` | Read Holding Registers | Read multiple registers | Reading CNC parameters |
| `05 (0x05)` | Write Single Coil | Write one coil | CLICK sending start/stop |
| `06 (0x06)` | Write Single Register | Write one register | Not used (read-only data) |
| `15 (0x0F)` | Write Multiple Coils | Write multiple coils | Not used |
| `16 (0x10)` | Write Multiple Registers | Write multiple registers | Not used |

**Typical Usage:**
- **CLICK PLC:** Function Code 05 to write start/stop coil
- **Students (Ignition):** Function Code 03 to read all 20 registers at once
- **Students (Ignition):** Function Code 01 to read status flags

## Example Modbus Transactions

### Student: Read All CNC Parameters

**Request (Read Holding Registers):**
```
Function Code: 03 (Read Holding Registers)
Starting Address: 0
Quantity: 20
```

**Response:**
```
20 registers (40 bytes):
[0, 5, 10500, 12, 1850, 75, -5200, 8300, -12400, 55, 72, 95, 1020, 5432, 127, 0, 85, 18, 0, 8500]
```

**Decoded:**
- Machine State: 0 (Idle)
- Parts Count: 5
- Spindle RPM: 10500
- Current Tool: T12
- Feedrate: 185.0 IPM (1850 ÷ 10)
- Spindle Load: 75%
- X Position: -5.200 mm (-5200 µm ÷ 1000)
- Y Position: 8.300 mm
- Z Position: -12.400 mm
- ...etc

### Student: Read Status Flags

**Request (Read Coils):**
```
Function Code: 01 (Read Coils)
Starting Address: 10
Quantity: 3
```

**Response:**
```
3 coils (1 byte):
0b00000111 = [1, 1, 1]
```

**Decoded:**
- Coil 10 (Signal Received): 1 (Yes)
- Coil 11 (Simulation Active): 1 (Running)
- Coil 12 (Cycle Complete): 1 (Yes)

## Common Alarm Codes

| Code | Severity | Description |
|------|----------|-------------|
| `0` | None | No alarm active |
| `101` | Warning | Coolant temperature rising |
| `102` | Warning | Spindle load high |
| `103` | Warning | Tool life low |
| `201` | Critical | Coolant flow stopped |
| `202` | Critical | Spindle overtemperature |
| `301` | Fatal | Emergency stop activated |

**Note:** Current implementation only simulates warning codes (101-103) at 5% random chance.

## Data Update Rate

- **Pi generates new parameters:** Every 0.5 seconds (2 Hz)
- **Recommended polling rate for students:** 1-2 seconds
  - Faster polling creates unnecessary network traffic
  - Slower polling misses parameter changes
- **CLICK PLC control signals:** Can be sent anytime (event-driven)

## Connection Examples

### Python (pymodbus)

```python
from pymodbus.client import ModbusTcpClient

# Connect to Pi
client = ModbusTcpClient('10.8.4.27', port=502)
client.connect()

# Read all CNC parameters
result = client.read_holding_registers(address=0, count=20, device_id=1)
if not result.isError():
    rpm = result.registers[2]
    feedrate = result.registers[4] / 10.0
    print(f"RPM: {rpm}, Feedrate: {feedrate} IPM")

# Read status flags
flags = client.read_coils(address=10, count=3, device_id=1)
if not flags.isError():
    print(f"Simulation Active: {flags.bits[1]}")

client.close()
```

### Ignition SCADA

1. **Add Modbus TCP Driver:**
   - Device Name: `CNC_Simulator`
   - Hostname: `10.8.4.27`
   - Port: `502`
   - Device ID: `1`

2. **Create Tags:**
   - `SpindleRPM`: Address `HR2` (Holding Register 2)
   - `Feedrate`: Address `HR4`, Scale: `/10`
   - `XPosition`: Address `HR6`, Scale: `/1000`, Data Type: `Int16`
   - `SimulationActive`: Address `C11` (Coil 11)

3. **Build HMI:** Drag tags to Vision or Perspective screens

## Troubleshooting

**Problem:** Can't connect to Pi
- Verify Pi is running: `ssh vandal@cnc-pi.local`
- Check slave.py is running: `ps aux | grep slave.py`
- Verify network: `ping 10.8.4.27`
- Check firewall: Port 502 must be open

**Problem:** Reading all zeros
- Simulation might not be active (check coil 11)
- Wait for CLICK to send start signal
- Verify you're reading registers 0-19, not 1-20

**Problem:** Negative positions showing as large positive numbers
- Use signed 16-bit integer data type in your SCADA system
- In Ignition: Set data type to `Int16` instead of `UInt16`

**Problem:** Feedrate/Coolant values seem too high
- Remember to divide by 10 to get actual values
- Register 4 value of 1850 = 185.0 IPM
- Register 9 value of 45 = 4.5 GPM

**Problem:** Multiple students interfering with each other
- Students should only READ data (Function Code 03, 01)
- Only CLICK PLC should WRITE (Function Code 05)
- Modbus TCP supports multiple simultaneous read-only clients
