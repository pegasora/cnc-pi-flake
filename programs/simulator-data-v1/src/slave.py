#!/usr/bin/env python3
"""
Haas CNC Machine Simulator - Modbus TCP Slave (Pi)

Workflow:
1. CLICK PLC flips coil (address 0) to start simulation
2. Pi simulates CNC machining parameters (runs until stop signal)
3. CLICK PLC flips coil (address 1) to stop simulation (CLICK controls cycle time)
4. Students read simulated parameters via Modbus TCP

Modbus Address Map:
- Coils (Read/Write from CLICK):
  - 0: Start signal (CLICK -> Pi)
  - 1: Stop signal (CLICK -> Pi)
  - 10: Signal received flag (Pi -> CLICK/Students)
  - 11: Simulation active flag (Pi -> Students)
  - 12: Cycle complete flag (Pi -> Students)

- Holding Registers (Read-only from Students):
  - 0: Machine state (0=Idle, 1=Running, 2=Paused, 3=Alarm)
  - 1: Parts count
  - 2: Spindle RPM (0-12000)
  - 3: Current tool number (1-24)
  - 4: Feedrate (inches/min * 10)
  - 5: Spindle load percentage (0-100)
  - 6: Axis X position (microns, signed)
  - 7: Axis Y position (microns, signed)
  - 8: Axis Z position (microns, signed)
  - 9: Coolant flow rate (GPM * 10)
  - 10: Coolant temperature (°F)
  - 11: Spindle temperature (°F)
  - 12: Hydraulic pressure (PSI)
  - 13: Program number currently running
  - 14: Block number in program
  - 15: Alarm code (0 = no alarm)
  - 16: Tool life remaining (%)
  - 17: Cycle time elapsed (seconds)
  - 18: Cycle time remaining (seconds) - always 0, CLICK controls duration
  - 19: Power consumption (watts)
"""

import asyncio
import time
import random
from pymodbus.server import ModbusTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusDeviceContext,
    ModbusServerContext,
)
from pymodbus.pdu.device import ModbusDeviceIdentification


# 4 Preset machining profiles with randomness
MACHINING_PROFILES = {
    "light_aluminum": {
        "rpm_range": (8000, 12000),
        "feedrate_range": (1500, 2500),  # IPM * 10
        "spindle_load_range": (20, 40),
        "coolant_flow_range": (30, 50),  # GPM * 10
        "power_range": (3000, 5000),
    },
    "heavy_steel": {
        "rpm_range": (800, 2000),
        "feedrate_range": (200, 600),
        "spindle_load_range": (60, 90),
        "coolant_flow_range": (50, 80),
        "power_range": (8000, 12000),
    },
    "finishing_pass": {
        "rpm_range": (5000, 8000),
        "feedrate_range": (400, 800),
        "spindle_load_range": (15, 30),
        "coolant_flow_range": (20, 40),
        "power_range": (2000, 4000),
    },
    "drilling_operation": {
        "rpm_range": (2000, 4000),
        "feedrate_range": (100, 300),
        "spindle_load_range": (40, 70),
        "coolant_flow_range": (60, 90),
        "power_range": (5000, 8000),
    },
}


class CNCSimulator:
    def __init__(self, context):
        self.context = context
        self.slave_id = 1
        self.running = False
        self.start_time = None
        self.current_profile = None
        self.parts_count = 0
        self.current_tool = 1
        
    def read_coil(self, address):
        """Read coil value"""
        device = self.context[self.slave_id]
        values = device.getValues(1, address, count=1)  # FC=1 for coils
        return values[0] if values else 0
    
    def write_coil(self, address, value):
        """Write coil value"""
        device = self.context[self.slave_id]
        device.setValues(1, address, [1 if value else 0])
    
    def write_registers(self, start_address, values):
        """Write holding registers"""
        device = self.context[self.slave_id]
        device.setValues(3, start_address, values)  # FC=3 for holding registers
    
    def select_random_profile(self):
        """Select one of 4 machining profiles"""
        profile_name = random.choice(list(MACHINING_PROFILES.keys()))
        self.current_profile = MACHINING_PROFILES[profile_name]
        print(f"Selected profile: {profile_name}")
        return profile_name
    
    def generate_random_value(self, value_range, noise_pct=10):
        """Generate random value within range with noise"""
        base = random.randint(value_range[0], value_range[1])
        noise = random.randint(-noise_pct, noise_pct) / 100.0
        return int(base * (1 + noise))
    
    def generate_toolpath_position(self, elapsed_time):
        """Generate realistic X/Y/Z positions based on elapsed time"""
        # Simulate circular toolpath in XY plane with Z depth
        angle = (elapsed_time / 30.0) * 2 * 3.14159  # Full circle in 30s
        
        # X position: -50mm to +50mm (convert to microns)
        x_pos = int(50000 * random.uniform(0.8, 1.0) * (1 + 0.5 * random.random() - 0.25))
        
        # Y position: -50mm to +50mm (convert to microns)
        y_pos = int(50000 * random.uniform(0.8, 1.0) * (1 + 0.5 * random.random() - 0.25))
        
        # Z position: gradual descent, then retract at end
        if elapsed_time < 25:
            z_pos = int(-5000 * (elapsed_time / 25.0) + random.randint(-500, 500))
        else:
            z_pos = int(-5000 + (elapsed_time - 25) * 1000)  # Retract
        
        return x_pos, y_pos, z_pos
    
    async def simulate_machining_cycle(self):
        """Simulate machining cycle with realistic parameters (runs until CLICK sends stop)"""
        self.running = True
        self.start_time = time.time()
        
        # Select random profile
        profile_name = self.select_random_profile()
        
        # Set simulation active flag
        self.write_coil(11, 1)
        self.write_coil(12, 0)  # Clear cycle complete
        
        print(f"Starting machining simulation (Profile: {profile_name})")
        print("Waiting for CLICK PLC stop signal (coil 1)...")
        
        # Select random tool
        self.current_tool = random.randint(1, 24)
        program_num = random.randint(1000, 9999)
        elapsed = 0  # Initialize elapsed time
        
        while self.running:
            elapsed = time.time() - self.start_time
            
            # Check for stop signal from CLICK
            stop_signal = self.read_coil(1)
            
            # Debug: Print coil status periodically
            if int(elapsed * 2) % 10 == 0:  # Every 5 seconds (at 2Hz rate)
                start_coil = self.read_coil(0)
                print(f"[DEBUG] Coils - Start(0)={start_coil}, Stop(1)={stop_signal}")
            
            if stop_signal:
                print(f"Stop signal received! Cycle complete (elapsed: {elapsed:.1f}s)")
                self.running = False
                break
            
            # Generate realistic machining parameters with noise
            rpm = self.generate_random_value(self.current_profile["rpm_range"], noise_pct=5)
            feedrate = self.generate_random_value(self.current_profile["feedrate_range"], noise_pct=8)
            spindle_load = self.generate_random_value(self.current_profile["spindle_load_range"], noise_pct=12)
            coolant_flow = self.generate_random_value(self.current_profile["coolant_flow_range"], noise_pct=7)
            power = self.generate_random_value(self.current_profile["power_range"], noise_pct=10)
            
            # Environmental parameters with gradual changes
            coolant_temp = 68 + int(elapsed * 0.5) + random.randint(-2, 2)
            spindle_temp = 72 + int(elapsed * 1.2) + random.randint(-3, 3)
            hydraulic_pressure = random.randint(950, 1050)
            
            # Tool parameters
            tool_life = max(0, 100 - int(elapsed * 2.5))
            block_num = int(elapsed * 10) + random.randint(0, 5)
            
            # Generate toolpath positions
            x_pos, y_pos, z_pos = self.generate_toolpath_position(elapsed)
            
            # Alarm simulation (5% chance of warning alarm)
            alarm_code = 0
            if random.random() < 0.05:
                alarm_code = random.choice([101, 102, 103])  # Warning codes
            
            # Machine state (1 = Running)
            machine_state = 1
            
            # Write all parameters to holding registers
            registers = [
                machine_state,           # 0: State
                self.parts_count,        # 1: Parts count
                rpm,                     # 2: Spindle RPM
                self.current_tool,       # 3: Tool number
                feedrate,                # 4: Feedrate
                spindle_load,            # 5: Spindle load %
                x_pos & 0xFFFF,          # 6: X position (lower 16 bits, signed)
                y_pos & 0xFFFF,          # 7: Y position
                z_pos & 0xFFFF,          # 8: Z position
                coolant_flow,            # 9: Coolant flow
                coolant_temp,            # 10: Coolant temp
                spindle_temp,            # 11: Spindle temp
                hydraulic_pressure,      # 12: Hydraulic pressure
                program_num,             # 13: Program number
                block_num,               # 14: Block number
                alarm_code,              # 15: Alarm code
                tool_life,               # 16: Tool life %
                int(elapsed),            # 17: Elapsed time
                0,                       # 18: Remaining time (controlled by CLICK)
                power,                   # 19: Power consumption
            ]
            
            self.write_registers(0, registers)
            
            # Print status every 5 seconds
            if int(elapsed) % 5 == 0 and elapsed > 0:
                print(f"[{int(elapsed)}s] RPM={rpm}, Feed={feedrate/10:.1f} IPM, Load={spindle_load}%, "
                      f"X={x_pos/1000:.2f}mm, Y={y_pos/1000:.2f}mm, Z={z_pos/1000:.2f}mm")
            
            await asyncio.sleep(0.5)  # Update at 2Hz
        
        # Cycle complete - set machine to idle
        self.parts_count += 1
        idle_registers = [
            0,                    # State = Idle
            self.parts_count,     # Increment parts count
            0, 0, 0, 0, 0, 0, 0,  # Zero out motion parameters
            68, 72, 1000,         # Environmental at rest
            program_num, 0, 0,    # Program done
            100,                  # Tool life reset
            int(elapsed), 0,      # Cycle times
            500,                  # Idle power
        ]
        self.write_registers(0, idle_registers)
        
        # Set cycle complete flag, clear simulation active
        self.write_coil(11, 0)
        self.write_coil(12, 1)
        
        print(f"Parts completed: {self.parts_count}")
        

async def monitor_start_signal(simulator):
    """Monitor CLICK PLC start signal (coil 0)"""
    print("Monitoring for start signal from CLICK PLC (coil 0)...")
    
    last_start_state = 0
    
    while True:
        start_signal = simulator.read_coil(0)
        
        # Detect rising edge (0 -> 1)
        if start_signal and not last_start_state and not simulator.running:
            print("\n=== START SIGNAL RECEIVED FROM CLICK PLC ===")
            
            # Set signal received flag
            simulator.write_coil(10, 1)
            
            # Start machining simulation
            await simulator.simulate_machining_cycle()
            
            # After cycle completes, wait for start signal to go low before accepting new cycles
            print("\nWaiting for start signal to reset before next cycle...")
            while simulator.read_coil(0):
                await asyncio.sleep(0.1)
            print("Start signal reset. Ready for next cycle.\n")
            last_start_state = 0  # Reset edge detector
            
        last_start_state = start_signal
        await asyncio.sleep(0.1)


async def run_server():
    """Main server function"""
    
    # Initialize data blocks
    # Coils: 100 coils (start/stop signals, flags)
    coils = ModbusSequentialDataBlock(0, [0] * 100)
    
    # Holding Registers: 100 registers (CNC parameters)
    holding_registers = ModbusSequentialDataBlock(0, [0] * 100)
    
    # Create device context (pymodbus 3.x uses ModbusDeviceContext)
    device = ModbusDeviceContext(
        di=coils,  # Discrete inputs (not used, share with coils)
        co=coils,  # Coils (read/write)
        hr=holding_registers,  # Holding registers
        ir=holding_registers,  # Input registers (share with holding)
    )
    
    # Server context - pass device directly with single=True
    context = ModbusServerContext(devices=device, single=True)
    
    # Device identification
    identity = ModbusDeviceIdentification()
    identity.VendorName = "CIIR Robotics Lab"
    identity.ProductName = "Haas CNC Simulator"
    identity.ModelName = "VF-2SS-Simulator"
    identity.MajorMinorRevision = "1.0.0"
    
    # Create simulator instance
    simulator = CNCSimulator(context)
    
    # Start monitoring task
    monitor_task = asyncio.create_task(monitor_start_signal(simulator))
    
    # Start Modbus server
    print("=" * 60)
    print("Haas CNC Machine Simulator - Modbus TCP Slave")
    print("=" * 60)
    print(f"Listening on: 0.0.0.0:502")
    print(f"Device: {identity.ProductName} ({identity.ModelName})")
    print("-" * 60)
    print("Waiting for CLICK PLC signals...")
    print("  Start: Coil 0 (CLICK -> Pi)")
    print("  Stop:  Coil 1 (CLICK -> Pi)")
    print("=" * 60)
    
    server = ModbusTcpServer(
        context=context,
        address=("0.0.0.0", 502),
        identity=identity,
    )
    
    await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(run_server())
