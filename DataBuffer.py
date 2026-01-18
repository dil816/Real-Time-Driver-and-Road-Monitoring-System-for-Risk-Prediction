import asyncio
import logging
from collections import deque
from datetime import datetime
from typing import List, Optional

import pandas as pd

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataBuffer:
    def __init__(self, window_seconds: int = 30, max_size: int = 10000):
        self.window_seconds = window_seconds
        self.max_size = max_size
        self.buffer = deque(maxlen=max_size)
        self.lock = asyncio.Lock()
        self.window_start = datetime.now()
        self.overflow_count = 0

    async def add_row(self, features: dict, timestamp: datetime) -> bool:
        async with self.lock:
            current_size = len(self.buffer)
            self.buffer.append({
                'timestamp': timestamp,
                'features': features
            })
            if current_size >= self.max_size - 1:
                self.overflow_count += 1
                logger.warning(f"Buffer overflow! Dropped oldest data. Count: {self.overflow_count}")
                return False
            return True

    async def get_and_clear(self) -> Optional[pd.DataFrame]:
        async with self.lock:
            if not self.buffer:
                return None
            data = []
            for item in self.buffer:
                row = {'timestamp': item['timestamp']}
                row.update(item['features'])
                data.append(row)
            df = pd.DataFrame(data)
            logger.info(f"Created DataFrame with {len(df)} rows, clearing buffer")
            self.buffer.clear()
            self.window_start = datetime.now()
            return df

    async def should_process(self) -> bool:
        return (datetime.now() - self.window_start).total_seconds() >= self.window_seconds

    async def get_buffer_info(self) -> dict:
        async with self.lock:
            return {
                'size': len(self.buffer),
                'max_size': self.max_size,
                'overflow_count': self.overflow_count,
                'utilization': len(self.buffer) / self.max_size * 100
            }
