import asyncio
import json
import logging
from collections import deque
from datetime import datetime

import serial_asyncio
from bleak import BleakScanner, BleakClient

import DataPipeline

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SerialDataReader:
    def __init__(self, ble_service_uuid: str, ble_characteristic_uuid: str, ble_device_name: str, env_port: str,
                 baudrate: int, pipeline: type[DataPipeline]):
        self.env_port = env_port
        self.baudrate = baudrate
        self.pipeline = pipeline
        self.env_reader = None
        self.env_writer = None
        self.address = None
        self.running = False
        self.reconnect_delay = 5
        self.hrv_deque = deque(maxlen=400)
        self.latest_env = None
        self.SERVICE_UUID = ble_service_uuid
        self.CHARACTERISTIC_UUID = ble_characteristic_uuid
        self.DEVICE_NAME = ble_device_name

    async def env_reader_connect(self):
        env_max_retries = 3
        retry_count = 0
        while retry_count < env_max_retries:
            try:
                self.env_reader, self.env_writer = await serial_asyncio.open_serial_connection(
                    url=self.env_port,
                    baudrate=self.baudrate
                )
                logger.info(f"Connected to ENV serial port {self.env_port} at {self.baudrate} baud")
                return True
            except Exception as e:
                retry_count += 1
                logger.error(f"Failed to connect to ENV serial port (attempt {retry_count}/{env_max_retries}): {e}")
                if retry_count < env_max_retries:
                    await asyncio.sleep(2)
        return False

    async def notification_handler(self, sender, data: bytearray) -> None:
        raw = data.decode("utf-8", errors="replace").strip()
        timestamp = datetime.now().strftime("%H:%M:%S")
        try:
            parts = raw.split(",")
            if len(parts) != 4:
                raise ValueError(f"Expected 4 fields, got {len(parts)}: '{raw}'")
            spo2 = int(parts[0])
            ibi = float(parts[1])
            temp_c = float(parts[2])
            noise = float(parts[3])
            bpm = ibi if ibi > 0 else 0.0
            print(
                f"[{timestamp}] "
                f"🩸 SpO2: {f'{spo2:3d}%'}  "
                f"❤️  IBI: {f'{bpm:5.1f}'}  "
                f"🌡  Temp: {f'{temp_c:4.1f}°C'}  "
                f"🔊 Noise: {f'{noise:5.1f} dB'}"
            )
            if ibi > 0:
                self.hrv_deque.append(ibi)
            if len(self.hrv_deque) > 30:
                env_data = self.latest_env
                await self.pipeline.process_data(list(self.hrv_deque), env_data)
        except Exception as exc:
            print(f"[{timestamp}] Parse error – raw='{raw}' ({exc})")

    async def hrv_read_loop(self):
        print(f"Scanning for '{self.DEVICE_NAME}' …")
        device = await asyncio.to_thread(
            lambda: asyncio.run(
                BleakScanner.find_device_by_name(self.DEVICE_NAME, timeout=15.0)
            )
        )
        # device = await BleakScanner.find_device_by_name(self.DEVICE_NAME, timeout=15.0)
        if device is None:
            print(f"ERROR: '{self.DEVICE_NAME}' not found.")
            return
        print(f"Found: {device.name}  [{device.address}]")
        self.address = device.address
        print(f"Connecting to {self.address} …")
        async with BleakClient(self.address, timeout=20.0) as client:
            if not client.is_connected:
                print("Connection failed.")
                return
            print(f"Connected!  (MTU={client.mtu_size})")
            await client.start_notify(self.CHARACTERISTIC_UUID, self.notification_handler)
            try:
                while client.is_connected:
                    await asyncio.sleep(1)
            except asyncio.CancelledError:
                pass
            finally:
                await client.stop_notify(self.CHARACTERISTIC_UUID)
                print("HRV BLE disconnected.")

    async def env_read_loop(self):
        self.running = True
        consecutive_errors = 0
        max_consecutive_errors = 10
        while self.running:
            try:
                line = await asyncio.wait_for(
                    self.env_reader.readline(),
                    timeout=1.0
                )
                data_str = line.decode('utf-8', errors='ignore').strip()
                serialdata = json.loads(data_str)
                if serialdata.get('type') == 'environmental':
                    self.latest_env = serialdata
                    print("env")
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("ENV Serial read loop cancelled")
                break
            except json.JSONDecodeError:
                continue
            except Exception as e:
                consecutive_errors += 1
                logger.error(f"Error reading ENV serial data (error {consecutive_errors}): {e}")
                if consecutive_errors >= max_consecutive_errors:
                    logger.error("ENV Too many consecutive errors, attempting reconnection...")
                    await self.env_reader_disconnect()
                    await asyncio.sleep(self.reconnect_delay)
                    if await self.env_reader_connect():
                        consecutive_errors = 0
                    else:
                        logger.error("ENV Reconnection failed, stopping ENV read loop")
                        break
                await asyncio.sleep(0.1)

    async def env_reader_disconnect(self):
        if self.env_writer:
            try:
                self.env_writer.close()
                await self.env_writer.wait_closed()
                logger.info("ENV Serial port disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting ENV serial port: {e}")
