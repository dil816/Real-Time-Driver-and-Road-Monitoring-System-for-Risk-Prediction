import asyncio
import logging
import numpy as np
from datetime import datetime

from BehaviouralDetectorAsync import BehaviouralDetectorAsync
from DataBuffer import DataBuffer
from ENVDataProcessor import ENVDataProcessor
from HRVDataProcessor import HRVDataProcessor
from MLInferenceEngine import MLInferenceEngine
from MetricsCollector import MetricsCollector
from SerialDataReader import SerialDataReader

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataPipeline:
    def __init__(self, model_path: str, env_api_key: str = None, serial_port: str = 'COM3', window_seconds: int = 30,
                 baud_rate: int = 115200):
        self.metrics = MetricsCollector()
        self.ml_engine = MLInferenceEngine()
        self.serial_reader = SerialDataReader(serial_port, baud_rate, self)
        self.hrv_processor = HRVDataProcessor()
        self.env_processor = ENVDataProcessor(weather_api_key=env_api_key)
        self.buffer = DataBuffer(window_seconds=window_seconds)
        self.bhv_processor = BehaviouralDetectorAsync(model_path=model_path,
                                                      buffer_size=500,
                                                      behavioural_interval=window_seconds)
        self.serial_read_task = None
        self.serial_process_task = None
        self.processing_task = None
        self.behavioral_process_task = None
        self.behavioral_aggregate_task = None
        self.video_read_task = None

    async def process_data(self, data_array: np.ndarray, env_data):
        try:
            if len(data_array) == 0:
                logger.warning("Received empty data array, skipping")
                return
            env_features = self.env_processor.process_environmental_data(env_data)
            hrv_features = self.hrv_processor.extract_features(data_array)
            await self.metrics.record_feature_extracted()
            timestamp = datetime.now()
            success_env = await self.buffer.add_env_row(env_features, timestamp)
            success_hrv = await self.buffer.add_hrv_row(hrv_features, timestamp)
            if not success_env or not success_hrv:
                logger.warning("Buffer overflow occurred during add_row")
            logger.debug(f"Processed array of {len(data_array)} elements")
        except Exception as e:
            logger.error(f"Error processing data: {e}", exc_info=True)
            await self.metrics.record_failed()

    async def periodic_inference(self):
        while True:
            try:
                if await self.buffer.should_process():
                    df, ed = await self.buffer.get_and_clear()
                    bd = await self.bhv_processor.get_recent_prediction()
                    if df is not None and not df.empty:
                        logger.info(f"Running inference on {len(df)} samples")
                        predictions = await self.ml_engine.predict(df)
                        if predictions is not None:
                            await self.metrics.record_inference()
                            logger.info(f"Inference complete: {len(predictions)} predictions")
                            print(predictions)
                        else:
                            logger.error("Inference returned None - predictions not stored")
                    if ed is not None and len(ed) > 0:
                        print(ed)
                        print(bd)
                await asyncio.sleep(1)
            except asyncio.CancelledError:
                logger.info("Periodic inference task cancelled")
                break
            except Exception as e:
                logger.error(f"Error in periodic inference: {e}", exc_info=True)

    async def start(self):
        try:
            self.ml_engine.load_model()
            logger.info("ML model loaded successfully")
            self.processing_task = asyncio.create_task(self.periodic_inference())
            if not await self.serial_reader.connect():
                raise RuntimeError("Failed to connect to serial reader")
            self.serial_read_task = asyncio.create_task(self.serial_reader.read_loop())
            self.serial_process_task = asyncio.create_task(self.serial_reader.process_loop())
            logger.info("Serial reader started")
            if not await self.bhv_processor.connect():
                raise RuntimeError("Failed to connect to video source")
            self.behavioral_process_task = asyncio.create_task(
                self.bhv_processor.processing_loop()
            )
            self.behavioral_aggregate_task = asyncio.create_task(
                self.bhv_processor.aggregation_loop()
            )
            self.video_read_task = asyncio.create_task(
                self.bhv_processor.queue_frame()
            )
            logger.info("Behavioral detector started")
            logger.info("Data pipeline started successfully")
        except Exception as e:
            logger.error(f"Pipeline startup failed: {e}", exc_info=True)
            await self.stop()
            raise

    async def stop(self):
        logger.info("Stopping data pipeline...")
        if self.processing_task and not self.processing_task.done():
            self.processing_task.cancel()
            await asyncio.gather(self.processing_task, return_exceptions=True)
        if self.serial_reader:
            logger.info("Stopping serial reader...")
            self.serial_reader.running = False
            tasks = [
                task for task in [self.serial_read_task, self.serial_process_task]
                if task and not task.done()
            ]
            for task in tasks:
                task.cancel()
            if tasks:
                try:
                    await asyncio.wait_for(
                        asyncio.gather(*tasks, return_exceptions=True),
                        timeout=5.0
                    )
                except asyncio.TimeoutError:
                    logger.warning("Timeout stopping serial tasks")
            try:
                await self.serial_reader.disconnect()
                logger.info("Serial reader disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting serial reader: {e}")
        if self.bhv_processor:
            logger.info("Stopping behavioral detector...")
            self.bhv_processor.running = False
            tasks = [
                task for task in [
                    self.behavioral_process_task,
                    self.behavioral_aggregate_task,
                    self.video_read_task
                ]
                if task and not task.done()
            ]
            for task in tasks:
                task.cancel()
            if tasks:
                try:
                    await asyncio.wait_for(
                        asyncio.gather(*tasks, return_exceptions=True),
                        timeout=5.0
                    )
                    logger.info(f"Stopped {len(tasks)} behavioral tasks")
                except asyncio.TimeoutError:
                    logger.warning("Timeout stopping behavioral tasks")
            try:
                logger.info("Behavioral detector disconnected")
            except Exception as e:
                logger.error(f"Error disconnecting behavioral detector: {e}")
        logger.info("Data pipeline stopped successfully")
