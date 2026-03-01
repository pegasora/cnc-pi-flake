import asyncio
from pymodbus.server import StartAsyncTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusDeviceContext,
    ModbusServerContext,
)
from pymodbus.pdu.device import ModbusDeviceIdentification
import random

# Fake CNC data store (holding registers)
datablock = ModbusSequentialDataBlock(0, [0] * 100)  # 100 registers, init to 0
device = ModbusDeviceContext(hr=datablock)
# In single=True mode, pass the device directly (with multiple devices, would be a dict)
context = ModbusServerContext(devices=device, single=True)

# Device info (shows in tools)
identity = ModbusDeviceIdentification()
identity.VendorName = "CIIR Robotics Lab"
identity.ProductName = "CNC Simulator"
identity.ModelName = "FakeHaas-best-cnc-simulator-in-the-universe"


async def updating_task(context):
    """Background: Simulate live CNC data."""
    slave_id = 1
    fc_as_hex = 3  # Function code 3 = holding registers

    while True:
        # In pymodbus 3.x with single mode, any slave_id maps to the same device
        device = context[slave_id]

        state = random.randint(0, 2)
        # Get current parts count and increment
        values = device.getValues(fc_as_hex, 1, count=1)
        parts = (values[0] + 1) % 10000 if values else 0
        rpm = random.randint(800, 6000)
        tool = random.randint(1, 12)
        alarms = random.randint(0, 15)  # 4-bit alarms

        # Update registers 0-4
        device.setValues(fc_as_hex, 0, [state, parts, rpm, tool, alarms])
        print(f"Updated: State={state}, Parts={parts}, RPM={rpm}")
        await asyncio.sleep(2)  # Every 2s


async def run():
    from pymodbus.server import ModbusTcpServer

    # Create server
    server = ModbusTcpServer(
        context,
        address=("0.0.0.0", 5020),  # Use port 5020 instead of 502 (requires root)
        identity=identity,
    )

    # Start background update task
    task = asyncio.create_task(updating_task(context))

    print("Starting Modbus server on port 5020...")
    await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(run())
