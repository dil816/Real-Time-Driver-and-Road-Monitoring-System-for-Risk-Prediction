import asyncio
import logging
import numpy as np
from datetime import datetime
from DataBuffer import DataBuffer
from DataProcessor import DataProcessor
from MLInferenceEngine import MLInferenceEngine
from MetricsCollector import MetricsCollector

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataPipeline:
    def __init__(self, window_seconds: int = 30):
        self.processor = DataProcessor()
        self.buffer = DataBuffer(window_seconds=window_seconds)
        self.ml_engine = MLInferenceEngine()
        self.metrics = MetricsCollector()
        self.processing_task = None

    async def process_data(self, data_array: np.ndarray):
        try:
            if len(data_array) == 0:
                logger.warning("Received empty data array, skipping")
                return
            features = self.processor.extract_features(data_array)
            await self.metrics.record_feature_extracted()
            timestamp = datetime.now()
            success = await self.buffer.add_row(features, timestamp)
            if not success:
                logger.warning("Buffer overflow occurred during add_row")
            logger.debug(f"Processed array of {len(data_array)} elements")
        except Exception as e:
            logger.error(f"Error processing data: {e}", exc_info=True)
            await self.metrics.record_failed()

    async def periodic_inference(self):
        while True:
            try:
                if await self.buffer.should_process():
                    df = await self.buffer.get_and_clear()
                    if df is not None and not df.empty:
                        logger.info(f"Running inference on {len(df)} samples")
                        predictions = await self.ml_engine.predict(df)
                        if predictions is not None:
                            await self.metrics.record_inference()
                            logger.info(f"Inference complete: {len(predictions)} predictions")
                        else:
                            logger.error("Inference returned None - predictions not stored")
                await asyncio.sleep(1)
            except asyncio.CancelledError:
                logger.info("Periodic inference task cancelled")
                break
            except Exception as e:
                logger.error(f"Error in periodic inference: {e}", exc_info=True)

    async def start(self):
        self.ml_engine.load_model()
        self.processing_task = asyncio.create_task(self.periodic_inference())
        logger.info("Data pipeline started")

    async def stop(self):
        if self.processing_task:
            self.processing_task.cancel()
            try:
                await self.processing_task
            except asyncio.CancelledError:
                pass
        logger.info("Data pipeline stopped")
