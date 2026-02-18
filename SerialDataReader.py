import asyncio
import json
import logging
from typing import Type

import numpy as np
import serial_asyncio

import DataPipeline

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SerialDataReader:
    def __init__(self, port: str, baudrate: int, pipeline: Type[DataPipeline]):
        self.port = port
        self.baudrate = baudrate
        self.pipeline = pipeline
        self.reader = None
        self.writer = None
        self.running = False
        self.reconnect_delay = 5
        self.read_queue = asyncio.Queue(maxsize=1000)
        # self.env_queue = asyncio.Queue(maxsize=1000)
        self.latest_env = None

    async def connect(self):
        max_retries = 3
        retry_count = 0
        while retry_count < max_retries:
            try:
                self.reader, self.writer = await serial_asyncio.open_serial_connection(
                    url=self.port,
                    baudrate=self.baudrate
                )
                logger.info(f"Connected to serial port {self.port} at {self.baudrate} baud")
                return True
            except Exception as e:
                retry_count += 1
                logger.error(f"Failed to connect to serial port (attempt {retry_count}/{max_retries}): {e}")
                if retry_count < max_retries:
                    await asyncio.sleep(2)
        return False

    async def read_loop(self):
        self.running = True
        consecutive_errors = 0
        max_consecutive_errors = 10
        while self.running:
            try:
                line = await asyncio.wait_for(
                    self.reader.readline(),
                    timeout=2.0
                )
                data_str = line.decode('utf-8', errors='ignore').strip()
                serialdata = json.loads(data_str)
                if serialdata.get('type') == 'hrv_data':
                    data_array = np.array(serialdata['ibi'])
                    print("ibi")
                    try:
                        await asyncio.wait_for(
                            self.read_queue.put(data_array),
                            timeout=0.1
                        )
                        consecutive_errors = 0
                    except asyncio.TimeoutError:
                        logger.warning("Read queue is full! Data may be lost.")
                elif serialdata.get('type') == 'environmental':
                    self.latest_env = serialdata
                    # try:
                    #     await asyncio.wait_for(
                    #         self.env_queue.put(serialdata),
                    #         timeout=0.1
                    #     )
                    #     consecutive_errors = 0
                    # except asyncio.TimeoutError:
                    #     logger.warning("Env queue is full! Data may be lost.")
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("Serial read loop cancelled")
                break
            except json.JSONDecodeError:
                continue
            except Exception as e:
                consecutive_errors += 1
                logger.error(f"Error reading serial data (error {consecutive_errors}): {e}")
                if consecutive_errors >= max_consecutive_errors:
                    logger.error("Too many consecutive errors, attempting reconnection...")
                    await self.disconnect()
                    await asyncio.sleep(self.reconnect_delay)
                    if await self.connect():
                        consecutive_errors = 0
                    else:
                        logger.error("Reconnection failed, stopping read loop")
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
                # env_data_array = await asyncio.wait_for(
                #     self.env_queue.get(),
                #     timeout=1.0
                # )
                await self.pipeline.process_data(data_array, env_data)
            except asyncio.TimeoutError:
                continue
            except asyncio.CancelledError:
                logger.info("Serial process loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing serial data: {e}")

    async def disconnect(self):
        if self.writer:
            try:
                self.writer.close()
                await self.writer.wait_closed()
                logger.info("Serial port disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting serial port: {e}")
