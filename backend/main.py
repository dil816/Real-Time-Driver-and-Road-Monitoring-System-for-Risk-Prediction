import logging
from contextlib import asynccontextmanager

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


app = FastAPI(title="Real-time Data Processing Pipeline", lifespan=lifespan)


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await pipeline.websocket_server.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pipeline.websocket_server.disconnect(websocket)


@app.get("/status")
async def root():
    return {"status": "running", "message": "Data processing pipeline is active"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
