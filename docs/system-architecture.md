# CNC Simulator System Architecture

## Overview

**Course:** Robotics Systems Engineering 2 (RSE2)  
**Purpose:** Educational robot machine tending system simulating a Haas UMC-450 5-axis CNC mill  
**Duration:** 5-week module on robot tending operations

This system allows students to practice robot programming and SCADA monitoring without requiring actual CNC machining. The Raspberry Pi simulates realistic CNC parameters while the robot performs physical machine tending tasks (load/unload parts, door/vise control).

---

## ⚠️ System Safety Overview

### What the E-Stop Controls
- **STOPS:** CNC simulator (Pi), CLICK PLC outputs, pneumatics
- **DOES NOT STOP:** Robot controller (separate E-stop required)

### Major Hazards
- **100+ PSI pneumatics:** Door and vise actuators
- **Pinch points:** CNC door (2 locations), vise jaws
- **Electrical:** 200-480VAC in robot cabinet, 120VAC in PLC enclosure
- **Robot motion:** Moving manipulator during tending operations

---

## Machine Tending Workflow

```mermaid
flowchart TD
    Start([Raw Part Available]) --> PickPart[Robot: Pick Part from Input]
    PickPart --> OpenDoor[Robot: Command Door Open via O3]
    OpenDoor --> WaitDoor1{Door Fully Open?<br/>I1 = ON}
    WaitDoor1 -->|Yes| OpenVise[Robot: Command Vise Open via O4]
    WaitDoor1 -->|No, Timeout| Fault1[Alarm: Door Failed to Open]
    
    OpenVise --> WaitVise1[Robot: Wait 1.5s for Vise Motion]
    WaitVise1 --> LoadPart[Robot: Place Part in Vise]
    LoadPart --> CloseVise[Robot: Command Vise Close via O4=OFF]
    CloseVise --> WaitVise2[Robot: Wait 1.5s for Vise Motion]
    
    WaitVise2 --> SafePos[Robot: Retract to Safe Position]
    SafePos --> CloseDoor[Robot: Command Door Close via O3=OFF]
    CloseDoor --> WaitDoor2{Door Fully Closed?<br/>I2 = ON}
    WaitDoor2 -->|Yes| StartSignal[Robot: Pulse O1 Start Signal]
    WaitDoor2 -->|No, Timeout| Fault2[Alarm: Door Failed to Close]
    
    StartSignal --> PLCStart[CLICK PLC: Latch Start Cycle]
    PLCStart --> ModbusStart[CLICK: Send Modbus Coil 0 = HIGH]
    ModbusStart --> PiStart[Pi: Detect Rising Edge, Start Sim]
    
    PiStart --> SelectProfile[Pi: Select Random Profile]
    SelectProfile --> SimLoop[Pi: Generate CNC Parameters<br/>Every 0.5 seconds]
    
    SimLoop --> PLCTimer[CLICK PLC: 30s Timer Running]
    PLCTimer --> Students[Students: Monitor via Ignition SCADA]
    
    Students --> TimerCheck{Timer<br/>Complete?}
    TimerCheck -->|No| SimLoop
    TimerCheck -->|Yes| PLCStop[CLICK PLC: Unlatch Start Cycle]
    
    PLCStop --> ModbusStop[CLICK: Send Modbus Coil 0 = LOW]
    ModbusStop --> PiStop[Pi: Stop Simulation]
    PiStop --> CycleDone[CLICK PLC: Energize Y006 Cycle Done]
    
    CycleDone --> RobotWait[Robot: Detect I5 = ON]
    RobotWait --> UnloadSeq[Robot: Open Door/Vise, Unload Part]
    UnloadSeq --> PlaceOutput[Robot: Place Part at Output]
    PlaceOutput --> CloseAll[Robot: Close Door/Vise]
    CloseAll --> Start
```

---

## Communication Architecture

```mermaid
graph TB
    subgraph Robot[Robot Controller - Fanuc]
        RobotIO[Digital I/O]
        RobotProg[TP Program]
        RobotSensors[Hardwired Sensors:<br/>I1=Door Open<br/>I2=Door Closed]
    end
    
    subgraph PLC[CLICK PLC]
        PLCLogic[Ladder Logic]
        PLCTimer[30s Cycle Timer]
        PLCModbus[Modbus TCP Client]
        PLCPneu[Pneumatic Outputs]
    end
    
    subgraph Pi[Raspberry Pi 4 - NixOS]
        ModbusSlave[Modbus TCP Slave<br/>Port 502]
        Simulator[CNC Simulator<br/>Python/pymodbus]
        Profiles[4 Machining Profiles]
    end
    
    subgraph Students[Student Workstations]
        Ignition[Ignition SCADA]
        HMI[HMI Screens]
        Historian[Data Logging]
    end
    
    subgraph Pneumatics[Pneumatic System]
        AirSupply[100 PSI Supply]
        DoorValve[Door Valve<br/>5/2 Solenoid]
        ViseValve[Vise Valve<br/>5/2 Solenoid]
        DoorCyl[Door Cylinder]
        ViseCyl[Vise Cylinder]
    end
    
    RobotProg --> RobotIO
    RobotSensors --> RobotIO
    
    RobotIO -->|O1: Start<br/>O3: Door<br/>O4: Vise| PLCLogic
    PLCLogic -->|Y006: Cycle Done| RobotIO
    
    PLCLogic --> PLCTimer
    PLCTimer --> PLCLogic
    PLCLogic --> PLCModbus
    PLCLogic --> PLCPneu
    
    PLCModbus -->|Modbus TCP<br/>Coil 0| ModbusSlave
    ModbusSlave --> Simulator
    Simulator --> Profiles
    
    ModbusSlave -->|Modbus TCP<br/>Registers 0-19| Ignition
    Ignition --> HMI
    Ignition --> Historian
    
    PLCPneu -->|Y001/Y002| DoorValve
    PLCPneu -->|Y003/Y004| ViseValve
    AirSupply --> DoorValve
    AirSupply --> ViseValve
    DoorValve --> DoorCyl
    ViseValve --> ViseCyl
```

---

## Network Topology

```mermaid
graph TD
    subgraph Network["24V DIN Rail Ethernet Switch<br/>Subnet: 10.8.4.0/24"]
        Switch[Unmanaged Switch<br/>5-Port Gigabit]
    end
    
    subgraph Pi["Raspberry Pi 4"]
        PiDev[cnc-pi<br/>IP: 10.8.4.27<br/>Hostname: cnc-pi.local<br/>Modbus TCP Server: 502]
    end
    
    subgraph PLC["CLICK PLC"]
        PLCDev[AutomationDirect CLICK<br/>IP: 10.8.4.50 configurable<br/>Modbus TCP Client]
    end
    
    subgraph StudentPCs["Student Workstations"]
        PC1[PC #1<br/>Ignition Designer/Client]
        PC2[PC #2<br/>Ignition Designer/Client]
        PCN[PC #N<br/>Ignition Designer/Client]
    end
    
    subgraph RobotSys["Robot System"]
        RobotCtrl[Fanuc Controller<br/>Digital I/O Only<br/>No Ethernet to This System]
    end
    
    Switch === Pi
    Switch === PLC
    Switch === PC1
    Switch === PC2
    Switch === PCN
    
    RobotCtrl -.Molex Connector<br/>O1/O3/O4 → PLC<br/>I5 ← PLC.-> PLC
    RobotCtrl -.Hardwired<br/>I1/I2 Door Sensors.-> RobotCtrl
```

**Key Points:**
- Robot I/O connected to CLICK PLC via **Molex quick-disconnect**
- Door sensors **hardwired directly to robot controller**
- Pi and PLC on same Ethernet switch for low-latency Modbus TCP
- Students can connect from any PC on the subnet

---

## I/O Signal Flow

### Robot → PLC Signals

| Robot Output | Wire | PLC Input | Purpose | Signal Timing |
|--------------|------|-----------|---------|---------------|
| O1 | Via Molex | X002 | Start cycle signal | 0.5s pulse |
| O3 | Via Molex | X003 | Door control (HIGH=open) | Level signal |
| O4 | Via Molex | X004 | Vise control (HIGH=open) | Level signal |

### PLC → Robot Signals

| PLC Output | Wire | Robot Input | Purpose | Signal Timing |
|------------|------|-------------|---------|---------------|
| Y006 | Via Molex | I5 | Cycle done | Latched until next cycle |

### Hardwired Robot Sensors

| Sensor | Wire | Robot Input | Purpose | Sensor Type |
|--------|------|-------------|---------|-------------|
| Door Open (Top) | Dedicated | I1 | Door fully open | NPN Inductive, NO |
| Door Closed (Bottom) | Dedicated | I2 | Door fully closed | NPN Inductive, NO |

---

## Machining Profile Selection

```mermaid
flowchart LR
    Start[Start Signal<br/>Coil 0 Rising Edge] --> Random{Random Selection<br/>25% each}
    
    Random -->|Profile 1| Light["Light Aluminum<br/><br/>RPM: 8000-12000<br/>Feed: 150-250 IPM<br/>Load: 20-40%<br/><br/>Use: Soft materials,<br/>high-speed finishing"]
    
    Random -->|Profile 2| Heavy["Heavy Steel<br/><br/>RPM: 800-2000<br/>Feed: 20-60 IPM<br/>Load: 60-90%<br/><br/>Use: Hard materials,<br/>roughing cuts"]
    
    Random -->|Profile 3| Finish["Finishing Pass<br/><br/>RPM: 5000-8000<br/>Feed: 40-80 IPM<br/>Load: 15-30%<br/><br/>Use: Surface finish,<br/>tight tolerances"]
    
    Random -->|Profile 4| Drill["Drilling Operation<br/><br/>RPM: 2000-4000<br/>Feed: 10-30 IPM<br/>Load: 40-70%<br/><br/>Use: Hole making,<br/>peck drilling"]
    
    Light --> Noise["Add 5-12% Random Noise<br/>to All Parameters"]
    Heavy --> Noise
    Finish --> Noise
    Drill --> Noise
    
    Noise --> Toolpath["Generate Realistic Toolpath<br/>X/Y: Circular motion<br/>Z: Gradual descent"]
    
    Toolpath --> Temps["Simulate Thermal Effects<br/>Coolant: +0.5°F/sec<br/>Spindle: +1.2°F/sec"]
    
    Temps --> Output["Output 20 Parameters<br/>Every 0.5 Seconds"]
```

---

## Data Flow During Cycle

```mermaid
sequenceDiagram
    participant R as Robot
    participant P as CLICK PLC
    participant Pi as Raspberry Pi
    participant S as Students (Ignition)
    
    Note over R: Raw part loaded
    R->>P: O1: Pulse start signal (0.5s)
    activate P
    
    P->>P: Latch C1 (Start Cycle)
    P->>P: Start T1 timer (30s)
    P->>Pi: Modbus: Write Coil 0 = HIGH
    activate Pi
    
    Pi->>Pi: Detect rising edge
    Pi->>Pi: Select random profile
    Pi->>P: Modbus: Set Coil 10 (signal received)
    Pi->>P: Modbus: Set Coil 11 (sim active)
    
    Note over Pi: Simulation running
    
    loop Every 0.5 seconds for 30 seconds
        Pi->>Pi: Generate CNC parameters
        S->>Pi: Modbus: Read Registers 0-19
        Pi->>S: Modbus: Return live data
        S->>S: Update HMI, log to historian
    end
    
    Note over P: Timer T1 expires (30s)
    P->>P: Unlatch C1 (Stop Cycle)
    P->>Pi: Modbus: Write Coil 0 = LOW
    deactivate Pi
    
    Pi->>Pi: Stop simulation
    Pi->>P: Modbus: Set Coil 12 (cycle complete)
    
    P->>P: Latch C2 (Cycle Done)
    P->>R: Y006: Energize cycle done
    deactivate P
    
    R->>R: Detect I5 = ON
    Note over R: Unload finished part
    
    R->>P: O3/O4: Door/vise commands
    Note over R: Part removed, door closed
    
    Note over R,S: Ready for next cycle
```

---

## State Machine (Pi Simulator)

```mermaid
stateDiagram-v2
    [*] --> Idle: System startup
    
    Idle --> WaitingStart: Power on, slave.py running
    WaitingStart --> Running: Coil 0: LOW→HIGH (rising edge)
    
    Running --> Running: Generate parameters (0.5s interval)
    Running --> Stopping: Coil 0: HIGH→LOW (falling edge)
    
    Stopping --> CycleComplete: Set completion flags
    CycleComplete --> WaitingReset: Set Coil 12 = HIGH
    WaitingReset --> WaitingStart: Wait for next rising edge
    
    note right of Running
        - Random profile selected
        - 20 parameters updated
        - Students reading data
        - CLICK timer running
    end note
    
    note right of CycleComplete
        - Parts count incremented
        - Machine state = Idle
        - Coil 11 (sim active) = LOW
        - Coil 12 (complete) = HIGH
    end note
```

---

## Key System Components

### Raspberry Pi 4 Model B
**Hardware:**
- 4GB RAM, quad-core ARM Cortex-A72
- Samsung 128GB SD card (2 available)
- Ethernet connection (10.8.4.27)

**Software:**
- NixOS 25.11 (declarative configuration)
- Python 3.13 with pymodbus 3.12.1
- devenv for development environment

**Role:**
- Modbus TCP slave server (port 502)
- CNC parameter generation and simulation
- Provides 20 registers of live machining data

### CLICK PLC (AutomationDirect)
**Model:** C0-02DD1-D (8 in, 8 out, 24VDC discrete)

**Role:**
- Robot I/O interface (start signal, cycle done)
- Pneumatic control (door/vise solenoids)
- Cycle timing (30-second timer)
- Modbus TCP master to Pi

**Ladder Logic Functions:**
- E-stop monitoring and safety interlocks
- Door/vise control based on robot commands
- 30s cycle timer
- Modbus communication with Pi
- Tower light indicators

### Robot Controller (Fanuc)
**I/O Configuration:**
- 3 outputs: O1 (start), O3 (door), O4 (vise)
- 3 inputs: I1 (door open), I2 (door closed), I5 (cycle done)

**Programming:**
- TP (Teach Pendant) language primary
- Python option available (advanced students)

**Role:**
- Execute machine tending sequence
- Control pneumatic door/vise via outputs
- Monitor door position sensors
- Signal PLC to start/stop cycles

### Student Workstations
**Software:** Ignition SCADA (Designer + Vision/Perspective)

**Activities:**
- Connect to Pi via Modbus TCP
- Create HMI screens for monitoring
- Log production data
- Calculate OEE and performance metrics
- Generate shift reports

---

## Pneumatic System Details

### Air Supply
- **Pressure:** 100+ PSI supply, regulated to 80 PSI
- **Filtration:** F/R/L unit (filter, regulator, lubricator)
- **Safety:** Manual shutoff valve for maintenance

### Solenoid Valves
- **Type:** 5/2 double-solenoid, spring-return
- **Voltage:** 24VDC
- **Safety:** De-energize = safe position (door closed, vise open)

### Actuators
- **Door Cylinder:** Double-acting, position sensors at each end
- **Vise Cylinder:** Double-acting, no position feedback (time-based)

### Safety Features
- Spring-return valves ensure safe state on power loss
- E-stop de-energizes all solenoid outputs
- Door must be closed before cycle can start (I2 interlock)

---

## Timing Diagram

```
Robot Start Signal (O1)     ___                        ___
                        ___|   |______________________|   |___

CLICK Start Cycle (C1)      ___________               ___________
                        ___|           |_____________|           |__

Pi Coil 0 (Modbus)          ___________               ___________
                        ___|           |_____________|           |__

CLICK 30s Timer (T1)        0--------30s              0--------30s

Pi Simulation Active        [=GENERATING DATA=]       [=GENERATING=]

CLICK Cycle Done (Y006)            ________                 ________
                        ___________|        |_______________|        |

Robot I5 Input                     ________                 ________
                        ___________|        |_______________|        |

Door Open (O3/Y001)     __________          ________  __________
                        |          |________|        ||          |__

Vise Open (O4/Y003)       ________          ________    ________
                        _|        |________|        |__|        |__
```

**Typical Cycle Duration:** 60-90 seconds total
- 10s: Door/vise open, load part
- 5s: Close door/vise, signal PLC
- 30s: Machining simulation
- 2s: Cycle complete signal
- 10s: Open door/vise, unload part
- 5s: Close door/vise, return to start

---

## System Specifications

| Parameter | Specification |
|-----------|---------------|
| **Cycle Time** | 30 seconds (configurable in PLC) |
| **Update Rate** | 0.5 seconds (2 Hz parameter generation) |
| **Network Latency** | < 10ms (Ethernet, same switch) |
| **Modbus Response** | < 50ms typical |
| **Door/Vise Motion** | 1.5-2.0 seconds (pneumatic) |
| **Simultaneous Students** | Unlimited (read-only Modbus access) |
| **Data Parameters** | 20 CNC registers, 3 status flags |
| **Profiles** | 4 machining profiles (random selection) |

---

## Safety Interlocks

### Hardware Interlocks
1. **E-stop:** De-energizes all PLC outputs immediately
2. **Spring-return valves:** Default to safe positions
3. **Separate robot E-stop:** Required to stop robot motion

### Software Interlocks (PLC Ladder Logic)
1. **Door closed check:** I2 must be ON before starting cycle
2. **E-stop check:** X001 must be closed for any output
3. **Timeout protection:** All waits have timeout limits
4. **Cycle interlock:** Cannot start new cycle while one is running

### Operational Procedures
1. **Low-speed testing:** Always test at 25-50% first
2. **Visual monitoring:** Never run unattended
3. **E-stop accessibility:** Operator within reach of E-stop
4. **Clearance verification:** Check area before starting

---

## Future Expansion Possibilities

### Hardware Enhancements
- Additional sensors (part present detection, pressure monitoring)
- Barcode scanner for part tracking
- Vision system for quality inspection
- Multiple Pi units for multi-machine simulation

### Software Enhancements
- More machining profiles (tapping, boring, contouring)
- Realistic alarm conditions (tool breakage, coolant low)
- Integration with MES (Manufacturing Execution System)
- Advanced SCADA analytics (predictive maintenance, SPC)

### Educational Additions
- ABB or UR robot integration (multi-vendor training)
- Advanced PLC programming (structured text, ladder)
- Industrial IoT/Industry 4.0 concepts
- OPC UA communication protocols

---

## Document Maintenance

**Last Updated:** March 3, 2026  
**Review Schedule:** Annually or when system is modified  
**Maintained By:** RSE2 Course Instructor  
**Revision History:**
- v1.0 (2026-03-03): Initial release with correct I/O and safety warnings
