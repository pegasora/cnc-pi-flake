#set document(title: "Modbus TCP Reference Guide")
#set page(numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)

#align(center)[
  #text(size: 20pt, weight: "bold")[Modbus TCP Reference Guide]
]

#v(1em)

= Connection Information

#table(
  columns: (auto, auto),
  align: (left, left),
  table.header([*Parameter*], [*Value*]),
  [*Pi IP Address*], [`10.8.4.x`],
  [*Port*], [`502` (Modbus TCP default)],
  [*Slave ID / Device ID*], [`1`],
  [*Protocol*], [Modbus TCP],
  [*Byte Order*], [Big Endian (Modbus standard)],
)

= Address Mapping

== Control Coils (Read/Write)

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: (center, center, center, left, center, left),
  table.header(
    [*Modbus Address*],
    [*Raw Address*],
    [*Direction*],
    [*Purpose*],
    [*Data Type*],
    [*Values*],
  ),
  [`00001`],
  [0],
  [CLICK → Pi],
  [Start/Stop Signal],
  [Boolean],
  [0=Stop, 1=Start],
)

*Usage:*
- CLICK PLC writes to this coil to control the simulation start/stop
- HIGH (1) = Start machining simulation
- LOW (0) = Stop machining simulation
  - Setting it up this way allows the CLICK PLC to determine cycle time
- Pi detects rising edge (LOW→HIGH) to begin new cycle
  - This is acceptable due to the overhead of time required to load/unload and then start a cycle - so no "stop" signal needed.

== Status Flags (Read-Only)

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: (center, center, center, left, center, left),
  table.header(
    [*Modbus Address*],
    [*Raw Address*],
    [*Direction*],
    [*Purpose*],
    [*Data Type*],
    [*Values*],
  ),
  [`00011`], [10], [Pi → All], [Signal Received], [Boolean], [0=No, 1=Yes],
  [`00012`],
  [11],
  [Pi → All],
  [Simulation Active],
  [Boolean],
  [0=Idle, 1=Running],

  [`00013`], [12], [Pi → All], [Cycle Complete], [Boolean], [0=No, 1=Yes],
)

*Usage:*
- CLICK PLC and students can read these to monitor simulation state
- Coil 10: Pi acknowledges receipt of start signal
- Coil 11: Pi is currently generating machining data
- Coil 12: Pi has completed a full cycle

#pagebreak()

== CNC Parameters (Holding Registers, Read-Only)

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: (center, center, left, center, center, left),
  table.header(
    [*Modbus Address*],
    [*Raw Address*],
    [*Parameter*],
    [*Unit*],
    [*Range*],
    [*Description*],
  ),
  [`40001`],
  [0],
  [Machine State],
  [enum],
  [0-3],
  [0=Idle, 1=Running, 2=Paused, 3=Alarm],

  [`40002`],
  [1],
  [Parts Count],
  [count],
  [0-65535],
  [Total parts machined since startup],

  [`40003`], [2], [Spindle RPM], [RPM], [0-12000], [Current spindle speed],
  [`40004`],
  [3],
  [Current Tool],
  [int],
  [1-24],
  [Tool number in spindle (T01-T24)],

  [`40005`],
  [4],
  [Feedrate],
  [IPM × 10],
  [0-2500],
  [Divide by 10 for actual IPM],

  [`40006`],
  [5],
  [Spindle Load],
  [int],
  [0-100],
  [Percentage of max spindle load],

  [`40007`],
  [6],
  [X Axis Position],
  [µm],
  [-32768 to 32767],
  [Divide by 1000 for mm (signed)],

  [`40008`],
  [7],
  [Y Axis Position],
  [µm],
  [-32768 to 32767],
  [Divide by 1000 for mm (signed)],

  [`40009`],
  [8],
  [Z Axis Position],
  [µm],
  [-32768 to 32767],
  [Divide by 1000 for mm (signed)],

  [`40010`],
  [9],
  [Coolant Flow],
  [GPM × 10],
  [0-1000],
  [Divide by 10 for actual GPM],

  [`40011`], [10], [Coolant Temp], [°F], [0-200], [Temperature in Fahrenheit],
  [`40012`], [11], [Spindle Temp], [°F], [0-250], [Temperature in Fahrenheit],
  [`40013`],
  [12],
  [Hydraulic Pressure],
  [PSI],
  [0-2000],
  [Pressure in pounds per square inch],

  [`40014`],
  [13],
  [Program Number],
  [int],
  [0-9999],
  [O-code program number (O\#\#\#\#)],

  [`40015`],
  [14],
  [Block Number],
  [int],
  [0-65535],
  [Current program line (N\#\#\#\#)],

  [`40016`],
  [15],
  [Alarm Code],
  [code],
  [0-65535],
  [0=No alarm, >0=Alarm active],

  [`40017`],
  [16],
  [Tool Life],
  [int],
  [0-100],
  [Remaining tool life percentage],

  [`40018`], [17], [Elapsed Time], [seconds], [0-65535], [Cycle time elapsed],
  [`40019`],
  [18],
  [Remaining Time],
  [seconds],
  [0],
  [Always 0 (CLICK controls timing)],

  [`40020`],
  [19],
  [Power Consumption],
  [watts],
  [0-15000],
  [Current power draw],
)

*Note on Scaling:*
- *Feedrate (register 4):* Multiply by 10 to fit in 16-bit integer. Example: 152 → 15.2 IPM
- *Coolant Flow (register 9):* Multiply by 10. Example: 45 → 4.5 GPM
- *Positions (registers 6-8):* Stored in microns (µm). Divide by 1000 for millimeters. Signed 16-bit values support negative positions.

#pagebreak()

= Function Codes

#table(
  columns: (auto, auto, auto, auto),
  align: (center, left, left, left),
  table.header([*Function Code*], [*Name*], [*Purpose*], [*Used For*]),
  [`01 (0x01)`], [Read Coils], [Read multiple coils], [Reading status flags],
  [`03 (0x03)`],
  [Read Holding Registers],
  [Read multiple registers],
  [Reading CNC parameters],

  [`05 (0x05)`],
  [Write Single Coil],
  [Write one coil],
  [CLICK sending start/stop],

  [`06 (0x06)`],
  [Write Single Register],
  [Write one register],
  [Not used (read-only data)],

  [`15 (0x0F)`], [Write Multiple Coils], [Write multiple coils], [Not used],
  [`16 (0x10)`],
  [Write Multiple Registers],
  [Write multiple registers],
  [Not used],
)

*Typical Usage:*
- *CLICK PLC:* Function Code 05 to write start/stop coil
- *Students (Ignition):* Function Code 03 to read all 20 registers at once
- *Students (Ignition):* Function Code 01 to read status flags

= Common Alarm Codes

#table(
  columns: (auto, auto, auto),
  align: (center, center, left),
  table.header([*Code*], [*Severity*], [*Description*]),
  [`0`], [None], [No alarm active],
  [`101`], [Warning], [Coolant temperature rising],
  [`102`], [Warning], [Spindle load high],
  [`103`], [Warning], [Tool life low],
  [`201`], [Critical], [Coolant flow stopped],
  [`202`], [Critical], [Spindle overtemperature],
  [`301`], [Fatal], [Emergency stop activated],
)

*Note:* Current implementation only simulates warning codes (101-103) at 5% random chance.

= Data Update Rate

- *Pi generates new parameters:* Every 0.5 seconds (2 Hz)

#pagebreak()

= Connection Examples

== Python (pymodbus)

```python
from pymodbus.client import ModbusTcpClient

# Connect to Pi
client = ModbusTcpClient('10.8.4.x', port=502)
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

== Ignition SCADA

1. *Add Modbus TCP Driver:*
  - Device Name: `CNC_Simulator`
  - Hostname: `10.8.4.x`
  - Port: `502`
  - Device ID: `1`

2. *Create Tags:*
  - `SpindleRPM`: Address `HR2` (Holding Register 2)
  - `Feedrate`: Address `HR4`, Scale: `/10`
  - `XPosition`: Address `HR6`, Scale: `/1000`, Data Type: `Int16`
  - `SimulationActive`: Address `C11` (Coil 11)

3. *Build HMI:* Drag tags to Vision or Perspective screens
