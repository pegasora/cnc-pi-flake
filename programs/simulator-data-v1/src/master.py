#!/usr/bin/env python3
"""
Modbus TCP Master - Test Client for CNC Simulator

This client can be used to:
1. Send start/stop signals to the simulator (like CLICK PLC)
2. Read simulated CNC parameters
3. Verify Modbus communication is working

Usage:
  python master.py                    # Read-only mode
  python master.py --test-cycle       # Simulate CLICK PLC start/stop
  python master.py --ip 10.8.4.27     # Connect to specific IP
"""

import asyncio
import argparse
import time
from pymodbus.client import AsyncModbusTcpClient


class ModbusMaster:
    def __init__(self, host="localhost", port=502):
        self.host = host
        self.port = port
        self.client = AsyncModbusTcpClient(host, port=port)
        self.device_id = 1
        
    async def connect(self):
        """Connect to Modbus server"""
        await self.client.connect()
        print(f"Connected to {self.host}:{self.port}")
    
    async def disconnect(self):
        """Disconnect from server"""
        self.client.close()
        print("Disconnected")
    
    async def read_coils(self, address, count=1):
        """Read coils"""
        result = await self.client.read_coils(address=address, count=count, device_id=self.device_id)
        if result.isError():
            print(f"Error reading coils at {address}")
            return None
        return result.bits[:count]
    
    async def write_coil(self, address, value):
        """Write single coil"""
        result = await self.client.write_coil(address=address, value=value, device_id=self.device_id)
        if result.isError():
            print(f"Error writing coil at {address}")
            return False
        return True
    
    async def read_holding_registers(self, address, count=1):
        """Read holding registers"""
        result = await self.client.read_holding_registers(
            address=address, count=count, device_id=self.device_id
        )
        if result.isError():
            print(f"Error reading registers at {address}")
            return None
        return result.registers
    
    async def read_cnc_parameters(self):
        """Read all CNC parameters (registers 0-19)"""
        registers = await self.read_holding_registers(0, count=20)
        if not registers:
            return None
        
        # Parse registers into named parameters
        params = {
            "state": registers[0],
            "parts_count": registers[1],
            "rpm": registers[2],
            "tool": registers[3],
            "feedrate": registers[4] / 10.0,  # Convert back from * 10
            "spindle_load": registers[5],
            "x_pos": self._to_signed(registers[6]) / 1000.0,  # microns -> mm
            "y_pos": self._to_signed(registers[7]) / 1000.0,
            "z_pos": self._to_signed(registers[8]) / 1000.0,
            "coolant_flow": registers[9] / 10.0,
            "coolant_temp": registers[10],
            "spindle_temp": registers[11],
            "hydraulic_psi": registers[12],
            "program_num": registers[13],
            "block_num": registers[14],
            "alarm_code": registers[15],
            "tool_life": registers[16],
            "elapsed_time": registers[17],
            "remaining_time": registers[18],
            "power_watts": registers[19],
        }
        return params
    
    def _to_signed(self, value):
        """Convert unsigned 16-bit to signed"""
        if value > 32767:
            return value - 65536
        return value
    
    def format_state(self, state_code):
        """Convert state code to text"""
        states = {0: "Idle", 1: "Running", 2: "Paused", 3: "Alarm"}
        return states.get(state_code, f"Unknown({state_code})")
    
    async def print_cnc_status(self):
        """Read and print formatted CNC status"""
        params = await self.read_cnc_parameters()
        if not params:
            print("Failed to read CNC parameters")
            return
        
        # Read status flags
        flags = await self.read_coils(10, count=3)  # Read flags at coils 10-12
        
        print("\n" + "=" * 70)
        print("  HAAS CNC MACHINE STATUS")
        print("=" * 70)
        
        # Machine state
        state_name = self.format_state(params["state"])
        print(f"State:            {state_name}")
        print(f"Parts Completed:  {params['parts_count']}")
        
        if params["state"] == 1:  # Running
            print("-" * 70)
            print("SPINDLE:")
            print(f"  RPM:            {params['rpm']:,} RPM")
            print(f"  Load:           {params['spindle_load']}%")
            print(f"  Temperature:    {params['spindle_temp']}°F")
            
            print("\nFEED:")
            print(f"  Rate:           {params['feedrate']:.1f} IPM")
            print(f"  Current Tool:   T{params['tool']:02d}")
            print(f"  Tool Life:      {params['tool_life']}%")
            
            print("\nAXIS POSITIONS:")
            print(f"  X: {params['x_pos']:>8.2f} mm")
            print(f"  Y: {params['y_pos']:>8.2f} mm")
            print(f"  Z: {params['z_pos']:>8.2f} mm")
            
            print("\nCOOLANT:")
            print(f"  Flow:           {params['coolant_flow']:.1f} GPM")
            print(f"  Temperature:    {params['coolant_temp']}°F")
            
            print("\nSYSTEM:")
            print(f"  Hydraulic:      {params['hydraulic_psi']} PSI")
            print(f"  Power:          {params['power_watts']:,} W")
            
            print("\nPROGRAM:")
            print(f"  Program #:      O{params['program_num']}")
            print(f"  Block #:        N{params['block_num']}")
            print(f"  Elapsed:        {params['elapsed_time']}s")
            print(f"  Remaining:      {params['remaining_time']}s")
            
            if params["alarm_code"] > 0:
                print(f"\n  ⚠ ALARM:        {params['alarm_code']}")
        
        # Status flags
        if flags:
            print("-" * 70)
            print("FLAGS:")
            print(f"  Signal Received:  {'YES' if flags[0] else 'NO'}")
            print(f"  Simulation Active: {'YES' if flags[1] else 'NO'}")
            print(f"  Cycle Complete:   {'YES' if flags[2] else 'NO'}")
        
        print("=" * 70)
    
    async def test_cycle(self):
        """Simulate CLICK PLC sending start/stop signals"""
        print("\n" + "=" * 70)
        print("  TESTING MODBUS CYCLE (Simulating CLICK PLC)")
        print("=" * 70)
        
        # Send start signal
        print("\n[CLICK PLC] Sending START signal (coil 0 = 1)...")
        success = await self.write_coil(0, True)
        if not success:
            print("Failed to send start signal")
            return
        
        print("[CLICK PLC] Start signal sent. Waiting for simulator to respond...")
        await asyncio.sleep(2)
        
        # Check signal received flag
        flags = await self.read_coils(10, count=2)
        if flags and flags[0]:
            print("[Pi] ✓ Simulator acknowledged start signal")
        
        # Monitor for 10 seconds
        print("\n[MASTER] Monitoring machining cycle for 10 seconds...")
        for i in range(10):
            await asyncio.sleep(1)
            params = await self.read_cnc_parameters()
            if params and params["state"] == 1:
                print(f"  [{i+1}s] Running: RPM={params['rpm']}, Feed={params['feedrate']:.1f} IPM, "
                      f"Load={params['spindle_load']}%, Time={params['elapsed_time']}s")
            else:
                print(f"  [{i+1}s] State: {self.format_state(params['state']) if params else 'Unknown'}")
        
        # Send stop signal
        print("\n[CLICK PLC] Sending STOP signal (coil 1 = 1)...")
        await self.write_coil(1, True)
        
        await asyncio.sleep(2)
        
        # Check final state
        params = await self.read_cnc_parameters()
        if params:
            print(f"\n[Pi] Final state: {self.format_state(params['state'])}")
            print(f"[Pi] Parts completed: {params['parts_count']}")
        
        print("\n" + "=" * 70)
        print("  TEST CYCLE COMPLETE")
        print("=" * 70)


async def monitor_mode(master):
    """Continuously monitor CNC status"""
    print("\n=== CONTINUOUS MONITORING MODE ===")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            await master.print_cnc_status()
            await asyncio.sleep(2)
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped.")


async def main():
    parser = argparse.ArgumentParser(description="Modbus TCP Master for CNC Simulator")
    parser.add_argument("--ip", default="localhost", help="Pi IP address (default: localhost)")
    parser.add_argument("--port", type=int, default=502, help="Modbus port (default: 502)")
    parser.add_argument("--test-cycle", action="store_true", help="Test start/stop cycle (simulate CLICK PLC)")
    parser.add_argument("--once", action="store_true", help="Read status once and exit")
    
    args = parser.parse_args()
    
    master = ModbusMaster(host=args.ip, port=args.port)
    
    try:
        await master.connect()
        
        if args.test_cycle:
            await master.test_cycle()
        elif args.once:
            await master.print_cnc_status()
        else:
            await monitor_mode(master)
            
    finally:
        await master.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
