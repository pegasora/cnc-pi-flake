# CLICK PLC Configuration for CNC Simulator Integration

## Overview

The CLICK PLC controls the CNC simulation cycle by sending start/stop signals to the Raspberry Pi via Modbus TCP. The robot performs machine tending, then signals the CLICK PLC to start a simulated machining cycle.

## Network Configuration

**Pi Address:** `10.8.4.27:502` (or use hostname `cnc-pi.local:502`)  
**CLICK Address:** Configure in your subnet (e.g., `10.8.4.50`)  
**Protocol:** Modbus TCP

## Modbus Address Map

### Coils (Discrete Outputs - CLICK to Pi)

| Address | Direction | Purpose | Description |
|---------|-----------|---------|-------------|
| `00001` | CLICK → Pi | Start Signal | Triggers 30-second machining simulation |
| `00002` | CLICK → Pi | Stop Signal | Stops simulation early (optional) |
| `00011` | Pi → CLICK | Signal Received | Acknowledgment from Pi |
| `00012` | Pi → CLICK | Simulation Active | Pi is currently simulating |
| `00013` | Pi → CLICK | Cycle Complete | Machining cycle finished |

### Holding Registers (Read-Only - Students/Ignition)

Students will read these registers in Ignition for SCADA applications:

| Address | Parameter | Units | Description |
|---------|-----------|-------|-------------|
| `40001` | Machine State | 0-3 | 0=Idle, 1=Running, 2=Paused, 3=Alarm |
| `40002` | Parts Count | count | Total parts machined |
| `40003` | Spindle RPM | RPM | 0-12000 |
| `40004` | Tool Number | # | 1-24 |
| `40005` | Feedrate | IPM×10 | Divide by 10 for actual IPM |
| `40006` | Spindle Load | % | 0-100 |
| `40007` | X Position | µm | Microns (signed) |
| `40008` | Y Position | µm | Microns (signed) |
| `40009` | Z Position | µm | Microns (signed) |
| `40010` | Coolant Flow | GPM×10 | Divide by 10 for GPM |
| `40011` | Coolant Temp | °F | Fahrenheit |
| `40012` | Spindle Temp | °F | Fahrenheit |
| `40013` | Hydraulic PSI | PSI | Pressure |
| `40014` | Program Number | # | O-code program |
| `40015` | Block Number | # | Current line |
| `40016` | Alarm Code | code | 0=no alarm |
| `40017` | Tool Life | % | Remaining tool life |
| `40018` | Elapsed Time | seconds | Cycle time elapsed |
| `40019` | Remaining Time | seconds | Cycle time remaining |
| `40020` | Power | watts | Power consumption |

## CLICK PLC Programming (Ladder Logic)

### Step 1: Configure Modbus TCP in CLICK

1. Open CLICK Programming Software
2. Go to **Setup → Communication → Ethernet**
3. Set IP address (e.g., `10.8.4.50`, subnet `255.255.255.0`)
4. Enable **Modbus TCP Server/Client**
5. Add Modbus TCP Client configuration:
   - **Name:** `CNC_Simulator`
   - **IP Address:** `10.8.4.27` (or `cnc-pi.local`)
   - **Port:** `502`
   - **Device ID:** `1`

### Step 2: Map Modbus Addresses to CLICK Memory

Configure the following mappings in the Modbus TCP setup:

**Coils to Write (CLICK → Pi):**
- CLICK `C1` → Modbus Coil `00001` (Start Signal)
- CLICK `C2` → Modbus Coil `00002` (Stop Signal)

**Coils to Read (Pi → CLICK):**
- Modbus Coil `00011` → CLICK `C11` (Signal Received)
- Modbus Coil `00012` → CLICK `C12` (Simulation Active)
- Modbus Coil `00013` → CLICK `C13` (Cycle Complete)

**Registers to Read (for display/monitoring - optional):**
- Modbus Register `40001-40020` → CLICK `DS1-DS20`

### Step 3: Basic Ladder Logic Program

```
Rung 1: Robot signals "ready to start cycle"
┌─────┬────────┬────────┬─────────┐
│ X1  │  C100  │  C1    │   C1    │  (Robot input triggers start pulse)
├─] [─┼──]/[───┼──]/[───┼──( )────┤
│     │        │        │         │
└─────┴────────┴────────┴─────────┘

Rung 2: Latch start signal for Pi
┌─────┬────────┬─────────┐
│ C1  │  C11   │   C100  │  (Latch until Pi acknowledges)
├─] [─┼──]/[───┼──( )────┤
│     │        │         │
└─────┴────────┴─────────┘

Rung 3: Reset start signal after acknowledgment
┌─────┬─────────┐
│ C11 │   C1    │  (Pi acknowledged, reset start)
├─] [─┼──(R)────┤
│     │         │
└─────┴─────────┘

Rung 4: Start 30-second timer when simulation starts
┌─────┬────────┬─────────┐
│ C12 │  T1    │   T1    │  (Start timer when sim active)
├─] [─┼──]/[───┼──(TON)──┤  Preset: 30.0s
│     │        │         │
└─────┴────────┴─────────┘

Rung 5: Send stop signal after 30 seconds (optional - Pi auto-stops)
┌─────┬─────────┐
│ T1  │   C2    │  (Timer done, send stop)
├─] [─┼──( )────┤
│     │         │
└─────┴─────────┘

Rung 6: Reset stop signal after 2 seconds
┌─────┬─────────┐
│ C2  │   T2    │  (Delay reset)
├─] [─┼──(TON)──┤  Preset: 2.0s
│     │         │
└─────┴─────────┘

┌─────┬─────────┐
│ T2  │   C2    │  (Reset stop signal)
├─] [─┼──(R)────┤
│     │         │
└─────┴─────────┘

Rung 7: Cycle complete indicator
┌─────┬─────────┐
│ C13 │   Y1    │  (Turn on "cycle done" light)
├─] [─┼──( )────┤
│     │         │
└─────┴─────────┘

Rung 8: Reset cycle complete flag (manual button)
┌─────┬─────────┐
│ X10 │   C13   │  (Reset button clears flag)
├─] [─┼──(R)────┤
│     │         │
│ C100│         │  (Also reset latch)
├─] [─┼──(R)────┤
│     │         │
└─────┴─────────┘
```

### Step 4: I/O Mapping

**Inputs:**
- `X1` - Robot "Cycle Start Request" signal (from robot controller)
- `X10` - Manual "Reset" pushbutton

**Outputs:**
- `Y1` - "Cycle Complete" indicator light

**Internal Coils:**
- `C1` - Start signal to Pi (Modbus Coil 00001)
- `C2` - Stop signal to Pi (Modbus Coil 00002)
- `C11` - Signal received from Pi (Modbus Coil 00011)
- `C12` - Simulation active from Pi (Modbus Coil 00012)
- `C13` - Cycle complete from Pi (Modbus Coil 00013)
- `C100` - Start latch

**Timers:**
- `T1` - 30-second cycle timer
- `T2` - 2-second stop signal reset delay

**Data Registers (optional monitoring):**
- `DS1-DS20` - CNC parameters from Pi

## Testing Procedure

### Test 1: Manual Start Signal

1. Open CLICK software in **Run/Monitor** mode
2. Manually toggle `C1` ON
3. Verify on Pi console: "START SIGNAL RECEIVED FROM CLICK PLC"
4. Verify `C11` turns ON (signal received acknowledgment)
5. Verify `C12` turns ON (simulation active)
6. Wait ~30 seconds
7. Verify `C12` turns OFF and `C13` turns ON (cycle complete)

### Test 2: Full Cycle with Robot Input

1. Connect robot output to CLICK input `X1`
2. Robot completes part loading
3. Robot energizes `X1`
4. CLICK sends start signal to Pi
5. Pi simulates 30-second machining cycle
6. CLICK receives cycle complete signal
7. Robot can proceed to unload part

### Test 3: Verify Data in Ignition

Students should configure Ignition to:
1. Add Modbus TCP driver
2. Connect to Pi at `10.8.4.27:502`
3. Create tags for registers `40001-40020`
4. Build HMI screens to display:
   - Spindle RPM gauge
   - Axis position indicators
   - Coolant/temperature trends
   - Parts counter
   - Alarm status

## Troubleshooting

**Pi not responding to start signal:**
- Verify network connectivity: `ping 10.8.4.27` from CLICK (if supported)
- Check Pi is running: `ssh vandal@cnc-pi.local` → `ps aux | grep slave.py`
- Verify Modbus port 502 is open: `sudo netstat -tulpn | grep 502`

**Simulation doesn't start:**
- Check coil `C1` is actually being written to Pi (monitor CLICK Modbus status)
- Verify Pi received signal: check Pi console logs
- Ensure slave.py is running with sudo (port 502 requires root)

**Students can't read data in Ignition:**
- Verify Ignition Modbus driver configured correctly (IP: `10.8.4.27`, Port: `502`, Device ID: `1`)
- Check register addresses start at `40001` (Modbus addressing convention)
- Ensure simulation is active (`C12` = ON) before expecting live data

**No network connectivity:**
- Verify CLICK and Pi are on same subnet (`10.8.4.x`)
- Check DIN rail switch has power and link lights
- Verify IP addresses don't conflict with other devices

## Signal Flow Summary

```
[Robot] --digital out--> [CLICK X1]
                           ↓
                    [CLICK Ladder Logic]
                           ↓ (Modbus TCP)
                    [C1 → Coil 00001]
                           ↓
                    [Pi: slave.py receives start]
                           ↓
                    [Pi: Simulates 30s machining]
                           ↓ (Modbus TCP)
                    [Coil 00011-00013 ← Pi]
                           ↓
                    [CLICK reads flags]
                           ↓
                    [CLICK Y1 output: Cycle Done]
                           ↓
                    [Robot proceeds to unload]

[Students/Ignition] --Modbus TCP--> [Pi Registers 40001-40020]
                                        ↓
                                [Display CNC parameters in SCADA]
```

## Next Steps

After confirming basic start/stop functionality:

1. Add more robot integration logic (part present sensors, gripper status)
2. Implement alarm handling in CLICK (stop robot if CNC alarm)
3. Configure Ignition historian to log machining data
4. Create student lab exercises around parameter monitoring
5. Add manual mode for testing without robot
