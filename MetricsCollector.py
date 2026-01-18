import asyncio
from collections import deque
from datetime import datetime

import numpy as np


class MetricsCollector:
    """Collects and tracks pipeline metrics for monitoring data loss."""

    def __init__(self):
        self.packets_received = 0
        self.packets_processed = 0
        self.packets_failed = 0
        self.features_extracted = 0
        self.inference_runs = 0
        self.last_packet_time = None
        self.processing_times = deque(maxlen=100)
        self.lock = asyncio.Lock()

    async def record_received(self):
        async with self.lock:
            self.packets_received += 1
            self.last_packet_time = datetime.now()

    async def record_processed(self, processing_time: float):
        async with self.lock:
            self.packets_processed += 1
            self.processing_times.append(processing_time)

    async def record_failed(self):
        async with self.lock:
            self.packets_failed += 1

    async def record_feature_extracted(self):
        async with self.lock:
            self.features_extracted += 1

    async def record_inference(self):
        async with self.lock:
            self.inference_runs += 1

    async def get_stats(self) -> dict:
        async with self.lock:
            return {
                'packets_received': self.packets_received,
                'packets_processed': self.packets_processed,
                'packets_failed': self.packets_failed,
                'features_extracted': self.features_extracted,
                'inference_runs': self.inference_runs,
                'data_loss': self.packets_received - self.packets_processed,
                'avg_processing_time_ms': np.mean(self.processing_times) * 1000 if self.processing_times else 0,
                'max_processing_time_ms': max(self.processing_times) * 1000 if self.processing_times else 0,
                'last_packet_time': self.last_packet_time.isoformat() if self.last_packet_time else None
            }
