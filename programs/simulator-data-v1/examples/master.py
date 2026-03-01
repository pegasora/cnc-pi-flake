import asyncio
from pymodbus.client import AsyncModbusTcpClient


async def run_client():
    # Connect to CNC sim (use "localhost" or actual Pi IP)
    client = AsyncModbusTcpClient("localhost", port=5020)  # ← Your Pi IP
    await client.connect()
    
    print("Reading CNC data... (Ctrl+C to stop)\n")
    
    try:
        while True:
            # Read 5 holding registers starting at 0, from device 1
            result = await client.read_holding_registers(address=0, count=5, device_id=1)
            
            if not result.isError():
                data = result.registers
                print(f"\n--- CNC Status ---")
                print(
                    f"State: {'Idle' if data[0] == 0 else 'Running' if data[0] == 1 else 'Error'}"
                )
                print(f"Parts Made: {data[1]}")
                print(f"Spindle: {data[2]} RPM")
                print(f"Tool: T{data[3]:02d}")
                print(f"Alarms: {bin(data[4])[2:].zfill(4)} (bits: door/tool/etc.)")
            else:
                print("Read error!")
            
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        client.close()


if __name__ == "__main__":
    asyncio.run(run_client())
