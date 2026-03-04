# Student Guide - CNC Machine Tending & SCADA Monitoring

## Course Information

**Course:** Robotics Systems Engineering 2 (RSE2)  
**Module:** Robot Machine Tending (5 weeks)  
**Equipment Being Simulated:** Haas UMC-450 (5-axis CNC mill)  

---

## !!!!! SAFETY - READ BEFORE OPERATING !!!!

### DANGER - High Pressure Pneumatics
- **System operates at 100+ PSI**
- Keep hands away from door and vise during operation
- **PINCH HAZARDS:** Door has pinch points, vise jaws can crush
- Never reach into cell while robot is running

### CAUTION - E-Stop Limitations
- **E-Stop button stops ONLY the CNC simulator and PLC**
- **E-Stop DOES NOT stop the robot**
- Use robot pendant E-stop to stop robot motion
- Always verify robot is stopped before entering cell

### ELECTRICAL HAZARDS
- **DO NOT open robot controller cabinet** (Potential shock hazards inside)
- **DO NOT mess with PLC enclosure** (120VAC present)
- Only instructor (Dawson, Levi, or James) may access the PLC
- Report any exposed wiring immediately

---

## Introduction

This system lets you practice **robot machine tending** - the process of using a robot to load/unload parts from a CNC machine. The Raspberry Pi simulates the CNC's machining data so you can build SCADA monitoring screens.

**You will learn:**
- Robot TP programming or Python programming
- SCADA data visualization
- Industrial Modbus TCP communication
- Machine tending workflow and safety

---

## Machine Tending Workflow

### The Process You'll Program

1. **Robot picks raw part** from dice holding fixture
2. **Robot opens CNC door** (via pneumatic control)
3. **Robot opens vise jaws** (via pneumatic control)
4. **Robot loads part into vise**
5. **Robot closes vise** to hold part securely
6. **Robot retracts to safe position**
7. **Robot closes CNC door**
8. **Robot signals CLICK PLC:** "Part loaded, start machining"
9. **CLICK PLC signals Pi:** Start x-second simulated cycle
10. **Pi generates realistic CNC data** (RPM, feedrate, positions, etc.)
11. **Students monitor data in Ignition SCADA**
12. **After x seconds, CLICK PLC signals robot:** "Cycle done"
13. **Robot opens door and vise**
14. **Robot unloads finished part**
15. **Robot closes door and vise**
16. **Robot places part on output conveyor**
17. **Repeat!**

### What the Robot Controls

| Robot Output | Controls | Purpose |
|--------------|----------|---------|
| **O1** | Start Signal | Tells PLC to start machining cycle |
| **O3** | Door Pneumatics | HIGH = open, LOW = close |
| **O4** | Vise Pneumatics | HIGH = open, LOW = close |

### What the Robot Reads

| Robot Input | Reads | Purpose |
|-------------|-------|---------|
| **I1** | Door Open Sensor | Confirms door fully open (safe to enter) |
| **I2** | Door Closed Sensor | Confirms door fully closed (safe to machine) |
| **I5** | Cycle Done Signal | PLC signals machining complete (safe to unload) |

---

## Robot Programming

### Key I/O Points for Your Program

**Digital Outputs (DO):**
- `DO[1]` = Start cycle signal (pulse it on then off before the cycle ends)
- `DO[3]` = Door control (ON=open, OFF=close)
- `DO[4]` = Vise control (ON=open, OFF=close)

**Digital Inputs (DI):**
- `DI[1]` = Door fully open (hardwired sensor)
- `DI[2]` = Door fully closed (hardwired sensor)
- `DI[5]` = Cycle done (from CLICK PLC)

### Good practices

1. **Always wait for sensor feedback** before proceeding (door sensors)
2. **Use timeouts on all wait/loop/delay statements** (handle failures gracefully)
3. **Pulse the start signal** - don't leave DO[1] high, this will trip up the PLC, and in real life you may accidentally start another cycle
4. **Allow time for pneumatics** - 1.5-2 seconds for door/vise motion (this is why we use the inductive sensors)
5. **Test at low speed first** (25-50%) before running at 100%
6. **Never skip safety checks** - verify door closed before starting cycle (PLC/Haas tracks this, but its good practice to wait for feedback)

---

## SCADA Monitoring (Ignition)

### What You'll Monitor

The Pi simulates a Haas CNC with **20+ live parameters**:

- **Spindle:** RPM, load %, temperature
- **Motion:** X/Y/Z axis positions, feedrate
- **Tooling:** Current tool number, tool life remaining
- **Coolant:** Flow rate, temperature  
- **System:** Hydraulic pressure, power consumption
- **Production:** Parts count, cycle times, alarm codes

### Connecting to the Simulator

**Pi IP Address:** `10.8.4.x`  
**Hostname:** `cnc-pi-moscow or cnc-pi-cda`  
**Modbus Port:** `502`  
**Device ID:** `1`

**Test connectivity:**
```bash
ping 10.8.4.x
```

### Step 1: Add Modbus Device in Ignition

1. Open **Ignition Designer**
2. **Config → OPC Connections → Devices**
3. **Create new Device... → Modbus TCP**
4. Configure:
   - Device Name: `CNC_Simulator`
   - Hostname: `10.8.4.x`
   - Port: `502`
   - Device ID: `1`
5. Verify **Connected** status (green)

### Step 2: Create Tags

Basic tags to get started:

| Tag Name | Address | Data Type | Description |
|----------|---------|-----------|-------------|
| `MachineState` | `HR0` or `40001` | Int2 | 0=Idle, 1=Running |
| `PartsCount` | `HR1` or `40002` | Int4 | Total parts machined |
| `SpindleRPM` | `HR2` or `40003` | Int4 | 0-12000 RPM |
| `CurrentTool` | `HR3` or `40004` | Int2 | Tool 1-24 |
| `Feedrate` | `HR4` or `40005` | Int4 | IPM × 10 (divide by 10) |
| `SpindleLoad` | `HR5` or `40006` | Int2 | 0-100% |
| `SimActive` | `C11` or `00012` | Boolean | Is simulation running? |

**Scaling required for:**
- Feedrate: Divide by 10 (stored as 1850 = 185.0 IPM)
- Positions: Divide by 1000 (stored in microns)
- Coolant flow: Divide by 10 (stored as GPM × 10)

---

## Understanding CNC Machining Profiles

The simulator randomly selects one of **four machining profiles** each cycle:

### 1. Light Aluminum (Fast)
- **RPM:** 8000-12000 (high speed)
- **Feedrate:** 150-250 IPM (fast)
- **Load:** 20-40% (low cutting force)
- **Use:** Soft materials, finishing operations

### 2. Heavy Steel (Slow)
- **RPM:** 800-2000 (low speed)
- **Feedrate:** 20-60 IPM (slow)
- **Load:** 60-90% (high cutting force)
- **Use:** Hard materials, roughing operations

### 3. Finishing Pass (Medium)
- **RPM:** 5000-8000 (medium speed)
- **Feedrate:** 40-80 IPM (moderate)
- **Load:** 15-30% (light cuts)
- **Use:** Surface finishing, tight tolerances

### 4. Drilling Operation
- **RPM:** 2000-4000 (medium speed)
- **Feedrate:** 10-30 IPM (slow, peck drilling)
- **Load:** 40-70% (intermittent)
- **Use:** Hole making, tapping

---

## Safety Checklist (Before Running Robot)

### Pre-Operation

- [ ] Area around robot is clear of people
- [ ] No tools or objects in robot workspace
- [ ] All guards and barriers in place
- [ ] E-stop buttons are accessible and functional
- [ ] You understand door/vise pinch points
- [ ] Pneumatic pressure is at correct level (80+ PSI)

### During Operation

- [ ] Robot running at reduced speed (25-50%) for first test
- [ ] Watching robot motion continuously
- [ ] Hand near E-stop button (on the robot)
- [ ] Not reaching into work cell
- [ ] Monitoring for unexpected motions or alarms

### After Operation

- [ ] Robot returned to home position
- [ ] Door and vise are in safe/start positions
- [ ] All outputs turned OFF
- [ ] Area cleaned of any debris
- [ ] Instructor (Dawson, Levi, or James) notified of any issues

---

## Troubleshooting

### Robot Issues

**Problem:** Robot doesn't receive cycle done signal  
**Solution:**
- Verify I5 is wired to PLC Y006
- Check PLC ladder shows Y006 energized when cycle completes
- Test with manual mode: Press manual start button on PLC

**Problem:** Door doesn't open when commanded  
**Solution:**
- Check pneumatic air pressure (should be 80+ PSI)
- Verify DO[3] is actually turning ON (check on pendant)
- Listen for pneumatic valve clicking
- Check Molex connector is fully seated

**Problem:** Door sensor not reading  
**Solution:**
- I1/I2 are hardwired inductive sensors
- Check sensor LED (should light when activated)
- Manually move door to trigger sensor and verify DI changes
- You might have to "move in" the sensor on the mount, can be accoplished using the 2 nuts to adjust how close sensor is to the door
- Verify sensor wiring (Brown=+24V, Blue=0V, Black=Signal) - Have TA fix to avoid issues

### SCADA Issues

**Problem:** Can't connect to Pi  
**Solution:**
- `ping 10.8.4.x` to test network
- Verify Pi is powered on (LED lights visible)
- Check Ethernet cable connections
- Ask instructor (Dawson) to verify slave.py is running

**Problem:** All tags reading zero  
**Solution:**
- Check if simulation is active (`SimActive` tag)
- Simulation only runs during 30-second (adjustable, so varies) cycles
- Have robot start a cycle
- Verify correct Modbus addresses (HR0-HR19)

**Problem:** Positions showing huge numbers  
**Solution:**
- Use `Int2` (signed) data type, not `Int4` (unsigned)
- Positions are in microns, divide by 1000 for millimeters
- Example: -5200 → -5.2 mm

**Problem:** Feedrate/coolant values too high  
**Solution:**
- These registers are scaled by 10
- Create expression tag: `{FeedrateRaw} / 10.0`
- Example: 1850 → 185.0 IPM

---

## Testing Your Program Safely

### Step 1: Simulated Run (No Part)
1. Run program at 25% speed
2. Robot moves through motions without part
3. Verify door/vise open/close at correct times
4. Check sensor feedbacks are working

### Step 2: First Live Run (With Part)
1. Use soft foam dice "part" for first test
2. Run at 25-50% speed
3. Stop immediately if anything unexpected occurs

### Step 3: Full Speed Production
1. Only after successful slow-speed tests
2. Run several cycles at 50% speed
3. Gradually increase to 75%, then whatever you would like and feel comfortable with. 
4. Continuously monitor for issues

---


## Getting Help

**Robot not behaving correctly?**
- Ask instructor (Dawson, Levi, or James) to verify your program logic
- Check pendant for error messages
- Review I/O states on pendant screen

**SCADA not showing data?**
- Instructor (Dawson) can SSH to Pi and check slave.py process
- Verify Modbus TCP connection in Ignition Gateway
- Check tag quality in Tag Browser

**Safety concerns?**
- Press E-stop immediately
- Notify instructor (Dawson, Levi, or James)
- Do not attempt to troubleshoot electrical or pneumatic issues yourself

---

Remember: **Safety first, quality second, speed third.**
