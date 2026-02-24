import logging
import queue
import threading
from collections import deque
from typing import Optional, Dict

import cv2
import numpy as np

from BehaviouralDetectorAsync import BehaviouralDetectorAsync

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BehavioralWindowManager:
    """
    Manages the OpenCV display window for behavioral detection.
    Runs in a separate thread to avoid blocking async operations.
    """

    def __init__(self, behavioral_detector: BehaviouralDetectorAsync, window_name: str = "Behavioral Detection"):
        self.behavioral_detector = behavioral_detector
        self.window_name = window_name
        self.running = False
        self.display_queue = queue.Queue(maxsize=2)  # Only keep latest frames
        self.display_thread = None
        self.fps_counter = deque(maxlen=30)

    def _draw_annotations(self, frame: np.ndarray, data_point: Optional[Dict]) -> np.ndarray:
        """Draw all annotations on the frame."""
        img_h, img_w, _ = frame.shape

        if data_point is None:
            # No face detected
            cv2.putText(frame, "No Face Detected", (20, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            return frame

        # Extract data
        direction_text = data_point.get('direction', 'Unknown')
        x_angle = data_point.get('x_angle', 0)
        y_angle = data_point.get('y_angle', 0)
        z_angle = data_point.get('z_angle', 0)
        mar = data_point.get('mar', 0)
        is_yawning = data_point.get('yawning', False)
        total_yawns = data_point.get('yawn_count', 0)

        # Draw direction text
        cv2.putText(frame, direction_text, (20, 50),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # Draw angles
        cv2.putText(frame, f"x: {x_angle:.2f}", (img_w - 150, 50),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        cv2.putText(frame, f"y: {y_angle:.2f}", (img_w - 150, 80),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        cv2.putText(frame, f"z: {z_angle:.2f}", (img_w - 150, 110),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

        # Draw MAR
        cv2.putText(frame, f"MAR: {mar:.2f}", (20, 90),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

        # Draw yawn count
        cv2.putText(frame, f"Yawns: {total_yawns}", (20, img_h - 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

        # Draw buffer size
        buffer_size = len(self.behavioral_detector.bhv_feature_queue)
        cv2.putText(frame, f"Buffer: {buffer_size}", (20, img_h - 90),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

        # Draw yawning warning
        if is_yawning:
            cv2.putText(frame, "YAWNING!", (20, 120),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 3)

        # Draw nose direction line (if we have the landmarks)
        # This would require passing nose_2d from process_frame
        # For now, we'll skip this or you can enhance it

        return frame

    def _display_loop(self):
        """Thread loop for displaying frames."""
        cv2.namedWindow(self.window_name)
        logger.info(f"Display window '{self.window_name}' opened")

        while self.running:
            try:
                # Get frame from queue (timeout to check if still running)
                try:
                    frame_data = self.display_queue.get(timeout=0.1)
                except queue.Empty:
                    continue

                frame, data_point, process_time = frame_data

                # Draw annotations
                annotated_frame = self._draw_annotations(frame.copy(), data_point)

                # Calculate and display FPS
                self.fps_counter.append(1.0 / process_time if process_time > 0 else 0)
                avg_fps = np.mean(self.fps_counter) if self.fps_counter else 0

                img_h, img_w, _ = annotated_frame.shape
                cv2.putText(annotated_frame, f'FPS: {int(avg_fps)}', (20, img_h - 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

                # Show frame
                cv2.imshow(self.window_name, annotated_frame)

                # Check for quit key
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    logger.info("'q' pressed, stopping display")
                    self.running = False
                    break

            except Exception as e:
                logger.error(f"Error in display loop: {e}")

        cv2.destroyWindow(self.window_name)
        logger.info(f"Display window '{self.window_name}' closed")

    def queue_frame_for_display(self, frame: np.ndarray, data_point: Optional[Dict], process_time: float):
        """Queue a frame for display (non-blocking)."""
        if not self.running:
            return

        try:
            # Clear old frames if queue is full
            while self.display_queue.qsize() >= self.display_queue.maxsize:
                try:
                    self.display_queue.get_nowait()
                except queue.Empty:
                    break

            self.display_queue.put_nowait((frame, data_point, process_time))
        except queue.Full:
            pass  # Skip this frame

    def start(self):
        """Start the display thread."""
        if self.running:
            logger.warning("Display thread already running")
            return

        self.running = True
        self.display_thread = threading.Thread(target=self._display_loop, daemon=True)
        self.display_thread.start()
        logger.info("Display thread started")

    def stop(self):
        """Stop the display thread."""
        self.running = False
        if self.display_thread:
            self.display_thread.join(timeout=2)
        logger.info("Display thread stopped")