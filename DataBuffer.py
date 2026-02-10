import asyncio
import logging
from collections import deque
from datetime import datetime
from typing import Any

import pandas as pd
from pandas import DataFrame

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataBuffer:
    def __init__(self, window_seconds: int = 30, max_size: int = 10000):
        self.window_seconds = window_seconds
        self.max_size = max_size
        self.hrv_buffer = deque(maxlen=max_size)
        self.env_buffer = deque(maxlen=max_size)
        self.lock = asyncio.Lock()
        self.window_start = datetime.now()
        self.overflow_count = 0

    async def add_hrv_row(self, features: dict, timestamp: datetime) -> bool:
        async with self.lock:
            current_size = len(self.hrv_buffer)
            self.hrv_buffer.append({
                'timestamp': timestamp,
                'features': features
            })
            if current_size >= self.max_size - 1:
                self.overflow_count += 1
                logger.warning(f"Buffer overflow! Dropped oldest data. Count: {self.overflow_count}")
                return False
            return True

    async def add_env_row(self, features: dict, timestamp: datetime) -> bool:
        async with self.lock:
            will_overflow = len(self.env_buffer) >= self.max_size
            self.env_buffer.append(features)
            if will_overflow:
                self.overflow_count += 1
                logger.warning(f"ENV buffer overflow! Dropped oldest data. Count: {self.overflow_count}")
                return False
            return True

    async def get_and_clear(self) -> tuple[DataFrame | None, Any | None]:
        async with self.lock:
            if not self.hrv_buffer:
                return None, None
            data = []
            for item in self.hrv_buffer:
                row = {'timestamp': item['timestamp']}
                row.update(item['features'])
                data.append(row)
            df = pd.DataFrame(data)
            ed = self.env_buffer[-1] if self.env_buffer else None
            print(type(ed))
            logger.info(f"Created DataFrame with {len(df)} rows, clearing buffer")
            self.hrv_buffer.clear()
            self.env_buffer.clear()
            self.window_start = datetime.now()
            return df, ed

    async def should_process(self) -> bool:
        return (datetime.now() - self.window_start).total_seconds() >= self.window_seconds

    async def get_buffer_info(self) -> dict:
        async with self.lock:
            return {
                'size': len(self.hrv_buffer),
                'max_size': self.max_size,
                'overflow_count': self.overflow_count,
                'utilization': len(self.hrv_buffer) / self.max_size * 100
            }
