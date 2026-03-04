#set document(title: "I/O Mapping - CNC Simulator System")
#set page(numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)

#align(center)[
  #text(size: 20pt, weight: "bold")[I/O Mapping - CNC Simulator System]
]

#v(1em)

= Physical I/O Mapping

== Robot Controller I/O

=== Robot Digital Inputs

#table(
  columns: (auto, auto, auto, auto, auto),
  align: (center, left, left, left, left),
  table.header(
    [*Robot Input*], [*Signal Name*], [*Source*], [*Description*], [*Wire Type*]
  ),
  [*I1*],
  [`DOOR_OPEN_TOP`],
  [Inductive Sensor (Top)],
  [Door fully open position],
  [Hardwired],

  [*I2*],
  [`DOOR_CLOSED_BTM`],
  [Inductive Sensor (Bottom)],
  [Door fully closed position],
  [Hardwired],

  [*I5*],
  [`CYCLE_DONE`],
  [CLICK PLC Y006],
  [CNC cycle complete, OK to unload],
  [Molex connector],
)

*Notes:*
- I1/I2 are *hardwired* to robot controller (not via Molex)
- I1/I2 are NPN inductive proximity sensors (NO, 3-wire)
- I5 connected via *Molex quick-disconnect* for easy system separation

=== Robot Digital Outputs

#table(
  columns: (auto, auto, auto, auto, auto),
  align: (center, left, left, left, left),
  table.header(
    [*Robot Output*],
    [*Signal Name*],
    [*Destination*],
    [*Description*],
    [*Wire Type*],
  ),
  [*O1*],
  [`START_SIGNAL`],
  [CLICK PLC X002],
  [Part loaded, start CNC cycle],
  [Molex connector],

  [*O3*],
  [`DOOR_CONTROL`],
  [CLICK PLC X003],
  [Pneumatic door actuator control],
  [Molex connector],

  [*O4*],
  [`VISE_CONTROL`],
  [CLICK PLC X004],
  [Pneumatic vise jaw control],
  [Molex connector],
)

*Notes:*
- All outputs sourcing type (robot supplies 24VDC when ON)
- Connected via *Molex quick-disconnect* connector
- Common (0V) shared between robot and PLC

#pagebreak()

== CLICK PLC I/O

=== Digital Inputs (24VDC Sinking)

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: (center, left, left, left, left, left),
  table.header(
    [*Terminal*],
    [*Label*],
    [*Description*],
    [*Source*],
    [*Signal Type*],
    [*Notes*],
  ),
  [*X001*],
  [`ESTOP`],
  [Emergency stop (NC contact)],
  [E-Stop Button],
  [24VDC, NC],
  [Open when pressed, software E-stop],

  [*X002*],
  [`ROBOT_START`],
  [Robot signals part ready],
  [Robot O1],
  [24VDC, NO],
  [Rising edge starts cycle],

  [*X003*],
  [`ROBOT_DOOR_CMD`],
  [Robot door control command],
  [Robot O3],
  [24VDC, NO],
  [HIGH=open, LOW=close],

  [*X004*],
  [`ROBOT_VISE_CMD`],
  [Robot vise control command],
  [Robot O4],
  [24VDC, NO],
  [HIGH=open, LOW=close],

  [*X005*],
  [`MANUAL_START`],
  [Manual cycle start button],
  [Pushbutton],
  [24VDC, NO],
  [For testing without robot],

  [*X006*],
  [`MANUAL_RESET`],
  [Manual system reset button],
  [Pushbutton],
  [24VDC, NO],
  [Clears faults/latches],

  [*X007*], [`SPARE_1`], [Spare input], [-], [-], [Reserved for future],
  [*X008*], [`SPARE_2`], [Spare input], [-], [-], [Reserved for future],
)

=== Digital Outputs (24VDC Sourcing)

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: (center, left, left, left, left, left),
  table.header(
    [*Terminal*],
    [*Label*],
    [*Description*],
    [*Destination*],
    [*Signal Type*],
    [*Notes*],
  ),
  [*Y001*],
  [`GREEN_LAMP`],
  [Green tower light (running)],
  [Tower Light],
  [24VDC],
  [CNC simulation active],

  [*Y002*],
  [`YELLOW_LAMP`],
  [Yellow tower light (idle)],
  [Tower Light],
  [24VDC],
  [System idle/ready],

  [*Y003*],
  [`RED_LAMP`],
  [Red tower light (fault)],
  [Tower Light],
  [24VDC],
  [System fault indicator],

  [*Y004*],
  [`DOOR_SOLENOID`],
  [Pneumatic door solenoid],
  [Air Valve],
  [24VDC, NO],
  [Energize to open door],

  [*Y005*],
  [`VISE_SOLENOID`],
  [Pneumatic vise solenoid],
  [Air Valve],
  [24VDC, NO],
  [Energize to open vise],

  [*Y006*],
  [`CYCLE_DONE`],
  [Cycle complete signal to robot],
  [Robot I5],
  [24VDC, NO],
  [Via Molex connector],
)

*Notes:*
- No remaining outputs, will need expansion cards

#pagebreak()

= Internal PLC Memory

TODO: Update this section

== Timers

#table(
  columns: (auto, auto, auto, auto, auto),
  align: (center, left, center, left, left),
  table.header([*Timer*], [*Label*], [*Preset*], [*Description*], [*Trigger*]),
  [*T1*],
  [`CYCLE_TIMER`],
  [30.0s],
  [Simulated machining cycle duration],
  [(Start Cycle from robot)],
)

#pagebreak()

= Wiring Details

== Molex Quick-Disconnect Connector

== Inductive Sensor Wiring (Hardwired to Robot)

*Sensor Specifications:*
- Type: NPN, Normally Open (NO), 3-wire
- Voltage: 24VDC
- Sensing Distance: 6-2mm typical
- Housing: M12 threaded barrel

*Wire Colors (Standard NPN):*
- *Brown:* +24VDC (from robot power supply)
- *Blue:* 0V Common (to robot common)
- *Black:* Signal output (to robot I1 or I2)

*Mounting:*
- Top sensor (I1): Detects door fully open
- Bottom sensor (I2): Detects door fully closed
- Sensors mounted on door track/frame, target on door carriage

== General Practices
- Yellow wire: signal wires
- White/Blue stripe: 0VDC (-) common
- Blue Wire: +24VDC (+) power
- Red Wire: Hot wire (+) power from the wall
- Green Wire: True ground (-)

