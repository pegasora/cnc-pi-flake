# I/O Mapping Example - CLICK PLC

## Overview

This document provides example I/O mapping for the CLICK PLC controlling the CNC simulator. Your actual I/O may vary based on robot model and physical wiring.

## CLICK PLC I/O Allocation

### Digital Inputs

| Terminal | Label | Description | Source | Signal Type |
|----------|-------|-------------|--------|-------------|
| **X1** | `ROBOT_READY` | Robot has loaded part and is ready | Robot Controller DO1 | 24VDC, NO |
| **X2** | `DOOR_OPEN_SW` | Door open limit switch | Door Sensor | 24VDC, NO |
| **X3** | `ESTOP` | Emergency stop button | E-Stop Circuit | 24VDC, NC |
| **X4** | `MANUAL_START` | Manual cycle start button | Pushbutton | 24VDC, NO |
| **X5** | `MANUAL_RESET` | Manual reset button | Pushbutton | 24VDC, NO |
| **X6** | `SPARE_1` | Spare input | - | - |
| **X7** | `SPARE_2` | Spare input | - | - |
| **X8** | `SPARE_3` | Spare input | - | - |

### Digital Outputs

| Terminal | Label | Description | Destination | Signal Type |
|----------|-------|-------------|-------------|-------------|
| **Y1** | `CYCLE_DONE` | Cycle complete, robot can unload | Robot Controller DI1 | 24VDC, NO |
| **Y2** | `FAULT_LAMP` | Red fault indicator lamp | Tower Light | 24VDC |
| **Y3** | `RUNNING_LAMP` | Green running indicator lamp | Tower Light | 24VDC |
| **Y4** | `IDLE_LAMP` | Yellow idle indicator lamp | Tower Light | 24VDC |
| **Y5** | `SPARE_4` | Spare output | - | - |
| **Y6** | `SPARE_5` | Spare output | - | - |
| **Y7** | `SPARE_6` | Spare output | - | - |
| **Y8** | `SPARE_7` | Spare output | - | - |

### Internal Coils (Memory)

| Coil | Label | Description | Set By | Reset By |
|------|-------|-------------|--------|----------|
| **C1** | `START_CYCLE` | Cycle start latch | X1 (Robot Ready) or X4 (Manual Start) | T1 (Timer Done) |
| **C2** | `CYCLE_DONE_FLAG` | Cycle complete flag | T1 (Timer Done) | X2 (Door Open) or X5 (Manual Reset) |
| **C10** | `FIRST_SCAN` | First scan flag | System | - |
| **C11** | `PI_SIGNAL_RECEIVED` | Pi acknowledged start (from Modbus) | Modbus Coil 10 | START_CYCLE reset |
| **C12** | `PI_SIM_ACTIVE` | Pi simulation running (from Modbus) | Modbus Coil 11 | - |
| **C13** | `PI_CYCLE_COMPLETE` | Pi cycle done (from Modbus) | Modbus Coil 12 | - |
| **C100** | `STARTUP_DONE` | System startup complete | T100 (Startup Timer) | - |

### Timers

| Timer | Label | Preset | Description | Trigger |
|-------|-------|--------|-------------|---------|
| **T1** | `CYCLE_TIMER` | 30.0s | CNC machining cycle duration | START_CYCLE |
| **T2** | `SIGNAL_PULSE` | 0.5s | Modbus signal pulse width | Various |
| **T100** | `STARTUP_DELAY` | 2.0s | System startup delay | First scan |

### Data Registers

| Register | Label | Description | Source | Data Type |
|----------|-------|-------------|--------|-----------|
| **DS1** | `CNC_STATE` | Machine state (0-3) | Modbus HR0 | INT16 |
| **DS2** | `PARTS_COUNT` | Total parts machined | Modbus HR1 | UINT16 |
| **DS3** | `SPINDLE_RPM` | Current spindle speed | Modbus HR2 | UINT16 |
| **DS4** | `CURRENT_TOOL` | Tool in spindle | Modbus HR3 | UINT16 |
| **DS5** | `FEEDRATE_X10` | Feedrate × 10 | Modbus HR4 | UINT16 |
| **DS10** | `CYCLE_COUNT` | Cycles completed today | Counter | UINT16 |
| **DS11** | `FAULT_CODE` | Current fault code | Logic | UINT16 |

## Modbus TCP Configuration

### Device Settings

| Parameter | Value |
|-----------|-------|
| Device Name | `CNC_Simulator` |
| IP Address | `10.8.4.27` |
| Port | `502` |
| Slave ID | `1` |
| Timeout | `5000ms` |
| Retry Count | `3` |

### Modbus Send Operations

#### Send 1: Start Cycle Signal

| Parameter | Value |
|-----------|-------|
| **Trigger Condition** | `C1` (START_CYCLE) OR NOT `C1` |
| **Function Code** | `05 - Write Single Coil` |
| **Address Type** | `Modbus 984 Addressing` |
| **Starting Slave Address** | `1` (Coil 0) |
| **Starting Master Address** | `C1` |
| **Description** | Writes the state of START_CYCLE to Pi |

**Ladder Logic:**
```
Rung: Send start signal when it changes
┌──────┬──────────┬────────────────────────┐
│ C1   │ NOT C1   │  MODBUS SEND [SEND1]   │
├─] [──┼──]/[─────┼───[SEND START]─────────┤
│      │          │                        │
└──────┴──────────┴────────────────────────┘
```

### Modbus Receive Operations

#### Receive 1: Status Flags

| Parameter | Value |
|-----------|-------|
| **Trigger Condition** | Always (continuous) |
| **Function Code** | `01 - Read Coils` |
| **Address Type** | `Modbus 984 Addressing` |
| **Starting Slave Address** | `11` (Coil 10) |
| **Number of Points** | `3` |
| **Starting Master Address** | `C11` |
| **Description** | Reads Pi status flags to C11, C12, C13 |

#### Receive 2: CNC Parameters (Optional)

| Parameter | Value |
|-----------|-------|
| **Trigger Condition** | `C12` (PI_SIM_ACTIVE) |
| **Function Code** | `03 - Read Holding Registers` |
| **Address Type** | `Modbus 984 Addressing` |
| **Starting Slave Address** | `40001` (Register 0) |
| **Number of Points** | `5` |
| **Starting Master Address** | `DS1` |
| **Description** | Reads first 5 CNC parameters for display |

## Example Ladder Logic Program

### Main Control Logic

```
Rung 1: Emergency Stop Check
┌──────┬───────────┐
│ X3   │   C100    │  (E-Stop NC contact)
├─]/[──┼───(U)─────┤  (Unlatch system if E-stop pressed)
│      │           │
└──────┴───────────┘

Rung 2: System Startup Delay
┌──────┬──────┬────────┐
│ C10  │ T100 │  T100  │  (First scan starts timer)
├─] [──┼─]/[──┼─(TON)──┤  Preset: 2.0s
│      │      │        │
└──────┴──────┴────────┘

┌──────┬────────┐
│ T100 │  C100  │  (Set startup done flag)
├─] [──┼─(L)────┤
│      │        │
└──────┴────────┘

Rung 3: Manual/Auto Start Cycle
┌──────┬──────┬──────┬──────┬─────────┐
│ C100 │  X1  │  X4  │  C1  │   C1    │  (Robot ready OR manual start)
├─] [──┼─] [──┼─] [──┼─]/[──┼──(L)────┤  (Latch start cycle)
│      │      │      │      │         │
└──────┴──────┴──────┴──────┴─────────┘

Rung 4: Reset Cycle Done on New Start
┌──────┬─────────┐
│ C1   │   C2    │  (New cycle starts)
├─]P[──┼──(U)────┤  (Unlatch cycle done)
│      │         │
└──────┴─────────┘

Rung 5: Cycle Timer
┌──────┬──────┬─────────┐
│ C1   │  T1  │   T1    │  (Start cycle active)
├─] [──┼─]/[──┼─(TON)───┤  Preset: 30.0s
│      │      │         │
└──────┴──────┴─────────┘

Rung 6: Cycle Complete
┌──────┬─────────┐
│ T1   │   C1    │  (Timer done)
├─] [──┼──(U)────┤  (Unlatch start cycle)
│      │         │
│      │   C2    │  (Latch cycle done)
├──────┼──(L)────┤
│      │         │
└──────┴─────────┘

Rung 7: Cycle Done Output to Robot
┌──────┬─────────┐
│ C2   │   Y1    │  (Cycle done flag)
├─] [──┼──( )────┤  (Energize output to robot)
│      │         │
└──────┴─────────┘

Rung 8: Reset Cycle Done (Door Opens)
┌──────┬─────────┐
│ X2   │   C2    │  (Door open)
├─] [──┼──(U)────┤  (Unlatch cycle done)
│      │         │
└──────┴─────────┘

Rung 9: Manual Reset
┌──────┬─────────┐
│ X5   │   C1    │  (Manual reset button)
├─] [──┼──(U)────┤  (Unlatch start)
│      │         │
│      │   C2    │  (Unlatch cycle done)
├──────┼──(U)────┤
│      │         │
└──────┴─────────┘

Rung 10: Tower Light - Running (Green)
┌──────┬──────┬─────────┐
│ C1   │ NOT  │   Y3    │  (Cycle active, no faults)
├─] [──┼─]/[──┼──( )────┤
│      │ C11  │         │
└──────┴──────┴─────────┘

Rung 11: Tower Light - Idle (Yellow)
┌──────┬──────┬─────────┐
│ NOT  │ NOT  │   Y4    │  (Not running, no faults)
├─]/[──┼─]/[──┼──( )────┤
│ C1   │ C11  │         │
└──────┴──────┴─────────┘

Rung 12: Tower Light - Fault (Red)
┌──────┬─────────┐
│ DS11 │   Y2    │  (Fault code present)
├─]>0[─┼──( )────┤
│      │         │
└──────┴─────────┘

Rung 13: Increment Cycle Counter
┌──────┬─────────┐
│ C2   │  DS10   │  (Cycle done rising edge)
├─]P[──┼──(CTU)──┤  (Count up)
│      │         │
└──────┴─────────┘
```

## Robot Controller I/O (Example - Fanuc)

### Robot Outputs (to CLICK PLC)

| Robot DO | Signal Name | CLICK Input | Description |
|----------|-------------|-------------|-------------|
| **DO[1]** | `PART_LOADED` | X1 | Part is in fixture, ready to machine |
| **DO[2]** | `GRIPPER_OPEN` | - | Gripper is open (monitoring only) |
| **DO[3]** | `GRIPPER_CLOSED` | - | Gripper is closed (monitoring only) |

### Robot Inputs (from CLICK PLC)

| Robot DI | Signal Name | CLICK Output | Description |
|----------|-------------|--------------|-------------|
| **DI[1]** | `CYCLE_DONE` | Y1 | CNC cycle complete, OK to unload |
| **DI[2]** | `FAULT` | Y2 | System fault, robot should pause |

### Robot TP Program Snippet

```
! Machine Tending Program
! Wait for door to open
WAIT_FOR DI[Door_Open_LS]=ON
! Pick part from conveyor
CALL PICK_PART
! Place part in fixture
CALL PLACE_PART
! Signal PLC: Part ready
DO[PART_LOADED]=ON
! Wait for CNC cycle complete
WAIT_FOR DI[CYCLE_DONE]=ON TIMEOUT=60sec
! Reset part loaded signal
DO[PART_LOADED]=OFF
! Unload finished part
CALL UNLOAD_PART
! Place on output conveyor
CALL PLACE_OUTPUT
```

## Wiring Diagram (Simplified)

```
┌─────────────────────────────────────────────────────┐
│                  CLICK PLC                          │
│  ┌──────────────────┐      ┌──────────────────┐    │
│  │ Digital Inputs   │      │ Digital Outputs  │    │
│  ├──────────────────┤      ├──────────────────┤    │
│  │ X1: ROBOT_READY  │◄─┐   │ Y1: CYCLE_DONE   │───┐│
│  │ X2: DOOR_OPEN    │◄─│   │ Y2: FAULT_LAMP   │───││
│  │ X3: ESTOP (NC)   │◄─│   │ Y3: RUNNING_LAMP │───││
│  │ X4: MANUAL_START │◄─│   │ Y4: IDLE_LAMP    │───││
│  └──────────────────┘  │   └──────────────────┘   ││
│                        │                          ││
│  ┌──────────────────┐  │                          ││
│  │ Ethernet Port    │  │                          ││
│  │ 10.8.4.50        │──┼──[Switch]──[Pi]         ││
│  └──────────────────┘  │                          ││
└────────────────────────┼──────────────────────────┼┘
                         │                          │
┌────────────────────────┼──────────────────────────┼┐
│  Robot Controller      │                          ││
│  ┌──────────────────┐  │  ┌──────────────────┐   ││
│  │ Digital Outputs  │──┘  │ Digital Inputs   │◄──┘│
│  │ DO1: PART_LOADED │     │ DI1: CYCLE_DONE  │    │
│  └──────────────────┘     └──────────────────┘    │
└───────────────────────────────────────────────────┘

┌────────────────────────┐    ┌────────────────┐
│  Door Limit Switch     │───►│ CLICK X2       │
└────────────────────────┘    └────────────────┘

┌────────────────────────┐    ┌────────────────┐
│  E-Stop Circuit (NC)   │───►│ CLICK X3       │
└────────────────────────┘    └────────────────┘

┌────────────────────────┐    ┌────────────────┐
│  Tower Light - Red     │◄───│ CLICK Y2       │
│  Tower Light - Green   │◄───│ CLICK Y3       │
│  Tower Light - Yellow  │◄───│ CLICK Y4       │
└────────────────────────┘    └────────────────┘
```

## Power Distribution

- **24VDC Power Supply:** Powers CLICK PLC, inputs, outputs, tower light
- **Common/Ground:** Shared between robot controller and CLICK PLC
- **Shielded cables:** Recommended for Modbus TCP Ethernet

## Testing Procedure

1. **Power up system** - Verify CLICK PLC boots normally
2. **Check network** - Ping Pi from another PC on network
3. **Test manual start** - Press X4, verify START_CYCLE latches
4. **Verify Modbus** - Check C11/C12/C13 reflect Pi status
5. **Test timer** - Cycle should complete in 30 seconds
6. **Test robot interface** - Simulate robot signals with temporary jumpers
7. **Test door reset** - Opening door should reset cycle done flag
8. **Verify tower lights** - Check green/yellow/red indicate correct states

## Modifications for Your System

- Adjust timer T1 preset for different cycle times
- Add more status monitoring (spindle RPM, parts count) to CLICK display
- Implement fault handling based on alarm codes from Pi
- Add data logging to CLICK SD card
- Interface with additional sensors (part present, coolant level, etc.)
