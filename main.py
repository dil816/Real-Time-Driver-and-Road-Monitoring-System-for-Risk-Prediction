import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime

import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from ConnectionManager import ConnectionManager
from DataPipeline import DataPipeline

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

manager = ConnectionManager()
pipeline = DataPipeline(model_path="face_landmarker.task",
                        env_api_key="9d01f5ea97d45f73c4fc7557b27cf0cd",
                        serial_port='COM3',
                        window_seconds=30,
                        baud_rate=115200)


@asynccontextmanager
async def lifespan(app_: FastAPI):
    await pipeline.start()

    yield

    logger.info("Starting application shutdown...")
    await pipeline.stop()
    logger.info("Application shutdown complete")


# FastAPI application
app = FastAPI(title="Real-time Data Processing Pipeline", lifespan=lifespan)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()  # keep connection alive
    except WebSocketDisconnect:
        manager.disconnect(websocket)


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
        buffer_size = len(pipeline.buffer.hrv_buffer)
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
