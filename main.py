import asyncio
import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime
import numpy as np
from fastapi import FastAPI

from BehaviouralDetectorAsync import BehaviouralDetectorAsync
from DataPipeline import DataPipeline
from SerialDataReader import SerialDataReader
from VideoCapture import VideoCapture

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global pipeline instance
pipeline = DataPipeline(window_seconds=30)
serial_reader = None
read_task = None
process_task = None

# ADD THESE NEW VARIABLES:
behavioral_detector = None
behavioral_process_task = None
behavioral_aggregate_task = None
video_reader = None
video_read_task = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    global serial_reader, read_task, process_task
    global behavioral_detector, behavioral_process_task, behavioral_aggregate_task
    global video_reader, video_read_task

    # Startup - Existing pipeline
    await pipeline.start()

    # Serial reader (existing - uncomment when ready)
    serial_reader = SerialDataReader('COM3', 115200, pipeline)
    if await serial_reader.connect():
        read_task = asyncio.create_task(serial_reader.read_loop())
        process_task = asyncio.create_task(serial_reader.process_loop())

    # NEW: Behavioral Detector Pipeline
    try:
        # Initialize behavioral detector
        model_path = "face_landmarker.task"  # UPDATE THIS PATH
        behavioral_detector = BehaviouralDetectorAsync(
            model_path=model_path,
            buffer_size=500,
            behavioural_interval=30
        )

        # Start processing loops
        behavioral_process_task = asyncio.create_task(behavioral_detector.processing_loop())
        behavioral_aggregate_task = asyncio.create_task(behavioral_detector.aggregation_loop())
        if await behavioral_detector.connect():
            video_read_task = asyncio.create_task(behavioral_detector.queue_frame())

        logger.info("Behavioral detector pipeline started successfully")

        # Start video capture
        # video_reader = VideoCapture(behavioral_detector, source=0)
        # if await video_reader.connect():
        #     video_read_task = asyncio.create_task(video_reader.read_loop())

    except Exception as e:
        logger.error(f"Failed to start behavioral detector: {e}")
        # Don't crash - existing pipeline still works

    yield

    # Shutdown - Existing pipeline
    if serial_reader:
        serial_reader.running = False
        if read_task:
            read_task.cancel()
        if process_task:
            process_task.cancel()
        await serial_reader.disconnect()

    await pipeline.stop()

    # NEW: Cleanup behavioral detector
    if behavioral_detector:
        behavioral_detector.running = False
        if behavioral_process_task:
            behavioral_process_task.cancel()
        if behavioral_aggregate_task:
            behavioral_aggregate_task.cancel()
        behavioral_detector.cleanup()

    if video_reader:
        if video_read_task:
            video_read_task.cancel()
        await video_reader.disconnect()

    logger.info("Application shutdown complete")


# FastAPI application
app = FastAPI(title="Real-time Data Processing Pipeline", lifespan=lifespan)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "running", "message": "Data processing pipeline is active"}


@app.get("/metrics")
async def get_metrics():
    """Get comprehensive pipeline metrics to detect data loss."""
    stats = await pipeline.metrics.get_stats()
    buffer_info = await pipeline.buffer.get_buffer_info()

    return {
        "pipeline_metrics": stats,
        "buffer_info": buffer_info,
        "health_status": {
            "ok": stats['data_loss'] == 0 and stats['packets_failed'] == 0,
            "warnings": []
        }
    }


@app.post("/data/simulate")
async def simulate_data():
    """Simulate incoming data for testing without serial port."""
    # Generate random data array
    data_array = np.random.randint(0, 1000, size=400, dtype=np.int32)

    await pipeline.metrics.record_received()
    start_time = time.time()
    await pipeline.process_data(data_array)
    processing_time = time.time() - start_time
    await pipeline.metrics.record_processed(processing_time)

    return {
        "status": "success",
        "array_size": len(data_array),
        "processing_time_ms": processing_time * 1000
    }


@app.get("/predictions/recent")
async def get_recent_predictions(n: int = 10):
    """Get recent ML predictions."""
    predictions = await pipeline.ml_engine.get_recent_predictions(n)
    return {"predictions": predictions, "count": len(predictions)}


@app.get("/buffer/status")
async def get_buffer_status():
    """Get current buffer status."""
    async with pipeline.buffer.lock:
        buffer_size = len(pipeline.buffer.buffer)
        time_elapsed = (datetime.now() - pipeline.buffer.window_start).total_seconds()

    return {
        "buffer_size": buffer_size,
        "window_seconds": pipeline.buffer.window_seconds,
        "time_elapsed": time_elapsed,
        "time_remaining": max(0, pipeline.buffer.window_seconds - time_elapsed)
    }


@app.get("/health")
async def health_check():
    """Comprehensive health check with data loss detection."""
    stats = await pipeline.metrics.get_stats()
    buffer_info = await pipeline.buffer.get_buffer_info()

    warnings = []
    errors = []

    # Check for data loss
    if stats['data_loss'] > 0:
        errors.append(f"Data loss detected: {stats['data_loss']} packets not processed")

    # Check for failed packets
    if stats['packets_failed'] > 0:
        warnings.append(f"{stats['packets_failed']} packets failed processing")

    # Check buffer utilization
    if buffer_info['utilization'] > 80:
        warnings.append(f"Buffer utilization high: {buffer_info['utilization']:.1f}%")

    # Check if receiving data
    if stats['last_packet_time']:
        last_packet = datetime.fromisoformat(stats['last_packet_time'])
        if (datetime.now() - last_packet).total_seconds() > 10:
            warnings.append("No data received in last 10 seconds")

    return {
        "status": "healthy" if not errors else "unhealthy",
        "warnings": warnings,
        "errors": errors,
        "metrics": stats,
        "buffer": buffer_info
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
