import asyncio
import json
import logging

import numpy as np
import serial_asyncio

import DataPipeline

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SerialDataReader:
    def __init__(self, hrv_port: str, env_port: str, baudrate: int, pipeline: type[DataPipeline]):
        self.hrv_port = hrv_port
        self.env_port = env_port
        self.baudrate = baudrate
        self.pipeline = pipeline
        self.hrv_reader = None
        self.hrv_writer = None
        self.env_reader = None
        self.env_writer = None
        self.running = False
        self.reconnect_delay = 5
        self.read_queue = asyncio.Queue(maxsize=1000)
        self.latest_env = None

    async def hrv_reader_connect(self):
        hrv_max_retries = 3
        retry_count = 0
        while retry_count < hrv_max_retries:
            try:
                self.hrv_reader, self.hrv_writer = await serial_asyncio.open_serial_connection(
                    url=self.hrv_port,
                    baudrate=self.baudrate
                )
                logger.info(f"Connected to HRV serial port {self.hrv_port} at {self.baudrate} baud")
                return True
            except Exception as e:
                retry_count += 1
                logger.error(f"Failed to connect to HRV serial port (attempt {retry_count}/{hrv_max_retries}): {e}")
                if retry_count < hrv_max_retries:
                    await asyncio.sleep(2)
        return False

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

    async def hrv_read_loop(self):
        self.running = True
        consecutive_errors = 0
        max_consecutive_errors = 10
        while self.running:
            try:
                line = await asyncio.wait_for(
                    self.hrv_reader.readline(),
                    timeout=2.0
                )
                data_str = line.decode('utf-8', errors='ignore').strip()
                serialdata = json.loads(data_str)
                if serialdata.get('type') == 'hrv_data':
                    try:
                        self.read_queue.put_nowait(np.array(serialdata['ibi']))
                        consecutive_errors = 0
                    except asyncio.QueueFull:
                        logger.warning("HRV Queue full - dropping packet")
                    print("ibi")
                elif serialdata.get('type') == 'environmental':
                    self.latest_env = serialdata
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("HRV Serial read loop cancelled")
                break
            except json.JSONDecodeError:
                continue
            except Exception as e:
                consecutive_errors += 1
                logger.error(f"Error reading HRV serial data (error {consecutive_errors}): {e}")
                if consecutive_errors >= max_consecutive_errors:
                    logger.error("HRV Too many consecutive errors, attempting reconnection...")
                    await self.hrv_reader_disconnect()
                    await asyncio.sleep(self.reconnect_delay)
                    if await self.hrv_reader_connect():
                        consecutive_errors = 0
                    else:
                        logger.error("HRV Reconnection failed, stopping HRV read loop")
                        break
                await asyncio.sleep(0.1)

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

    async def process_loop(self):
        while self.running:
            try:
                data_array = await asyncio.wait_for(
                    self.read_queue.get(),
                    timeout=1.0
                )
                env_data = self.latest_env
                await self.pipeline.process_data(data_array, env_data)
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("Serial process loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing serial data: {e}")

    async def hrv_reader_disconnect(self):
        if self.hrv_writer:
            try:
                self.hrv_writer.close()
                await self.hrv_writer.wait_closed()
                logger.info("HRV Serial port disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting HRV serial port: {e}")

    async def env_reader_disconnect(self):
        if self.env_writer:
            try:
                self.env_writer.close()
                await self.env_writer.wait_closed()
                logger.info("ENV Serial port disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting ENV serial port: {e}")
