import asyncio
import logging
import time

import cv2

from BehaviouralDetectorAsync import BehaviouralDetectorAsync

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VideoCapture:
    """Captures video frames and feeds to behavioral detector."""

    def __init__(self, behavioral_detector: BehaviouralDetectorAsync, source: int = 0):
        self.behavioral_detector = behavioral_detector
        self.source = source
        self.cap = None
        self.running = False
        self.fps = 30

    async def connect(self) -> bool:
        """Initialize video capture."""
        try:
            self.cap = cv2.VideoCapture(self.source)
            if not self.cap.isOpened():
                logger.error(f"Failed to open video source: {self.source}")
                return False

            logger.info(f"Video capture initialized: {self.source}")
            return True
        except Exception as e:
            logger.error(f"Error initializing video capture: {e}")
            return False

    async def read_loop(self):
        """Continuously read frames."""
        self.running = True
        frame_interval = 1.0 / self.fps

        while self.running:
            try:
                start_time = time.time()

                ret, frame = self.cap.read()
                if not ret:
                    logger.warning("Failed to read frame")
                    await asyncio.sleep(0.1)
                    continue

                # Flip frame (like your original code)
                frame = cv2.flip(frame, 1)

                # Queue for behavioral processing
                await self.behavioral_detector.queue_frame(frame)

                # Maintain FPS
                elapsed = time.time() - start_time
                sleep_time = max(0, frame_interval - elapsed)
                await asyncio.sleep(sleep_time)

            except asyncio.CancelledError:
                logger.info("Video read loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error in video read loop: {e}")
                await asyncio.sleep(0.1)

    async def disconnect(self):
        """Release video capture."""
        self.running = False
        if self.cap:
            self.cap.release()
            logger.info("Video capture released")